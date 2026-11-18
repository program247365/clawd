import AppKit
import ClawdKit
import Lottie
import XCTest

@MainActor
final class RenderTests: XCTestCase {
    func testEveryAnimationRendersCleanly() {
        var problems: [String] = []
        var current = ""
        let previousLogger = LottieLogger.shared
        defer { LottieLogger.shared = previousLogger }
        LottieLogger.shared = LottieLogger(
            assert: { condition, message, _, _ in
                if !condition() { problems.append("\(current): assert: \(message())") }
            },
            assertionFailure: { message, _, _ in problems.append("\(current): assertionFailure: \(message())") },
            warn: { message, _, _ in problems.append("\(current): warn: \(message())") },
            info: { _ in })

        let catalog = AnimationCatalog(directory: stagedAnimations())
        let size = CGSize(width: 550, height: 370)
        for item in catalog.all {
            let last = CGFloat(item.frameCount - 1)
            for frame in [0, (last / 2).rounded(), last] {
                current = "\(item.name)@\(Int(frame))"
                guard let image = FrameRenderer.render(item.animation, frame: frame, pixelSize: size) else {
                    problems.append("\(current): no image")
                    continue
                }
                let stats = PixelStats(image)
                if stats.opaqueFraction < 0.005 { problems.append("\(current): blank") }
                if !stats.containsBodyColor { problems.append("\(current): no body color") }
            }
        }

        XCTAssertEqual(problems, [])
    }

    func testClawdIsRightSideUp() throws {
        let walking = try XCTUnwrap(AnimationCatalog(directory: stagedAnimations()).walking)
        let image = try XCTUnwrap(FrameRenderer.render(walking.animation, frame: 26, pixelSize: CGSize(width: 550, height: 370)))
        let stats = PixelStats(image)
        let top = Double(try XCTUnwrap(stats.highestOpaqueRow))
        let bottom = Double(try XCTUnwrap(stats.lowestOpaqueRow))
        let eyes = try XCTUnwrap(stats.meanDarkRow)
        XCTAssertLessThan(eyes, (top + bottom) / 2, "eyes should be in the upper half of his body")
    }

    func testWritesContactSheet() throws {
        let catalog = AnimationCatalog(directory: stagedAnimations())
        let tile = CGSize(width: 275, height: 185)
        let labelHeight: CGFloat = 22
        let columns = 7
        let rows = Int((Double(catalog.all.count) / Double(columns)).rounded(.up))
        let sheetSize = CGSize(width: tile.width * CGFloat(columns), height: (tile.height + labelHeight) * CGFloat(rows))

        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(sheetSize.width), pixelsHigh: Int(sheetSize.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor(red: 0xfa / 255, green: 0xf9 / 255, blue: 0xf5 / 255, alpha: 1).setFill()
        NSRect(origin: .zero, size: sheetSize).fill()
        for (index, item) in catalog.all.enumerated() {
            let column = index % columns
            let row = index / columns
            let x = CGFloat(column) * tile.width
            let top = sheetSize.height - CGFloat(row) * (tile.height + labelHeight)
            let middle = (CGFloat(item.frameCount - 1) / 2).rounded()
            if let image = FrameRenderer.render(item.animation, frame: middle, pixelSize: tile) {
                NSImage(cgImage: image, size: tile).draw(in: NSRect(x: x, y: top - tile.height, width: tile.width, height: tile.height))
            }
            let label = NSAttributedString(string: item.name, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor(white: 0.08, alpha: 1),
            ])
            label.draw(at: NSPoint(x: x + (tile.width - label.size().width) / 2, y: top - tile.height - labelHeight + 4))
        }
        NSGraphicsContext.restoreGraphicsState()

        let output = stagedAnimations().deletingLastPathComponent().appendingPathComponent("contact-sheet.png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: output)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
    }
}
