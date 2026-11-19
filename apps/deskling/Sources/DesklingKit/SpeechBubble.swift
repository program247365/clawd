import AppKit

/// A pixel-edged bubble drawn in the art's own colors: cream inside, near-black outline.
private final class BubbleView: NSView {
    var text = "" { didSet { needsDisplay = true } }
    static let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
    /// One "pixel" of the outline and tail.
    static let pixel: CGFloat = 3
    static let padding = CGSize(width: 12, height: 8)
    static let tailHeight = pixel * 3

    static let ink = NSColor(srgbRed: 0x14 / 255, green: 0x14 / 255, blue: 0x13 / 255, alpha: 1)
    static let paper = NSColor(srgbRed: 0xfa / 255, green: 0xf9 / 255, blue: 0xf5 / 255, alpha: 1)

    static func size(for text: String) -> CGSize {
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        return CGSize(
            width: ceil(textSize.width) + 2 * (padding.width + pixel),
            height: ceil(textSize.height) + 2 * (padding.height + pixel) + tailHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        let p = Self.pixel
        let box = CGRect(x: 0, y: Self.tailHeight, width: bounds.width, height: bounds.height - Self.tailHeight)
        // Outline with the corners notched off, the way the art draws round things.
        Self.ink.setFill()
        CGRect(x: box.minX + p, y: box.minY, width: box.width - 2 * p, height: box.height).fill()
        CGRect(x: box.minX, y: box.minY + p, width: box.width, height: box.height - 2 * p).fill()
        Self.paper.setFill()
        CGRect(x: box.minX + p, y: box.minY + p, width: box.width - 2 * p, height: box.height - 2 * p).fill()
        // A stepped tail pointing down at his head.
        let centre = (bounds.midX / p).rounded() * p
        Self.ink.setFill()
        for step in 0..<3 {
            let width = CGFloat(3 - step) * 2 * p
            CGRect(x: centre - width / 2, y: box.minY - CGFloat(step + 1) * p, width: width, height: p).fill()
        }
        Self.paper.setFill()
        CGRect(x: centre - 2 * p, y: box.minY, width: 4 * p, height: p).fill()
        CGRect(x: centre - p, y: box.minY - p, width: 2 * p, height: p).fill()

        let attributes: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: Self.ink]
        let textSize = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(
            at: CGPoint(x: box.midX - textSize.width / 2, y: box.midY - textSize.height / 2),
            withAttributes: attributes)
    }
}

/// Words over his head. Like him, it never takes a click or focus.
@MainActor
public final class SpeechBubble {
    private let panel: NSPanel
    private let view = BubbleView()

    public init() {
        panel = NSPanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = view
    }

    public var isVisible: Bool { panel.isVisible }
    public var text: String { view.text }

    /// Shows `text` centred just above `frame`, kept on `screen`.
    public func show(_ text: String, above frame: CGRect, within screen: CGRect) {
        view.text = text
        let size = BubbleView.size(for: text)
        var origin = CGPoint(x: frame.midX - size.width / 2, y: frame.maxY - frame.height * 0.1)
        origin.x = min(max(origin.x, screen.minX), screen.maxX - size.width)
        origin.y = min(origin.y, screen.maxY - size.height)
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }

    public func hide() {
        panel.orderOut(nil)
    }
}
