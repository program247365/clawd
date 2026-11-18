import AppKit
import Lottie

/// A panel that can never take focus.
private final class PassivePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// A small transparent, click-through window exactly Clawd's size. Moving Clawd means moving this window.
@MainActor
public final class ClawdWindow {
    private let panel: PassivePanel
    private let animationView: LottieAnimationView
    private var scale: CGFloat = 1
    private var pendingPlay: CheckedContinuation<Void, Never>?
    private var frameTimer: Timer?

    public init(size: CGSize) {
        panel = PassivePanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        // No .fullScreenAuxiliary: that is what keeps him out of native fullscreen Spaces.
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true

        let container = NSView(frame: CGRect(origin: .zero, size: size))
        container.wantsLayer = true
        animationView = LottieAnimationView(configuration: FrameRenderer.configuration)
        animationView.frame = container.bounds
        animationView.autoresizingMask = [.width, .height]
        animationView.contentMode = .scaleAspectFit
        container.addSubview(animationView)
        panel.contentView = container
    }

    public var origin: CGPoint {
        get { panel.frame.origin }
        set { panel.setFrameOrigin(newValue) }
    }

    /// The walking animation faces right; `.left` mirrors him.
    public var facing: Facing = .right {
        didSet { applyTransform() }
    }

    public var isVisible: Bool { panel.isVisible }

    /// Keeps the bottom-left corner where it is.
    public func resize(to size: CGSize) {
        panel.setFrame(CGRect(origin: panel.frame.origin, size: size), display: true)
        applyTransform()
    }

    /// Shows him at full size and opacity without activating the app.
    public func show() {
        scale = 1
        animationView.alphaValue = 1
        applyTransform()
        panel.orderFrontRegardless()
    }

    public func hide() {
        panel.orderOut(nil)
    }

    public func loopWalk(_ walking: ClawdAnimation) {
        let cycle = Choreography.walkCycle
        startFrames(of: walking, from: cycle.lowerBound, through: cycle.upperBound, loop: true)
    }

    /// Shows one frame without playing.
    public func pose(_ animation: ClawdAnimation, frame: CGFloat) {
        stopAnimation()
        animationView.animation = animation.animation
        animationView.currentFrame = frame
    }

    /// Plays once from the first frame to the last. Returns early if interrupted.
    public func play(_ animation: ClawdAnimation) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            startFrames(
                of: animation, from: animation.animation.startFrame,
                through: animation.animation.endFrame - 1, loop: false)
            pendingPlay = continuation
        }
    }

    /// Steps through whole frames at the animation's own rate (12fps for this art) instead of letting
    /// Lottie redraw on every display refresh: it looks the same and costs a fraction of the CPU.
    private func startFrames(of item: ClawdAnimation, from first: CGFloat, through last: CGFloat, loop: Bool) {
        stopAnimation()
        animationView.animation = item.animation
        animationView.currentFrame = first
        var frame = first
        let timer = Timer(timeInterval: 1 / max(item.animation.framerate, 1), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                frame += 1
                if frame > last {
                    guard loop else { return self.stopAnimation() }
                    frame = first
                }
                self.animationView.currentFrame = frame
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    /// A quick scale-and-fade. Always ends in the stated state, even if interrupted.
    public func pop(visible: Bool) async {
        let duration = 0.15
        let target: CGFloat = visible ? 1 : 0.6
        let animation = CABasicAnimation(keyPath: "sublayerTransform")
        animation.fromValue = transform(scale: scale)
        animation.toValue = transform(scale: target)
        animation.duration = duration
        scale = target
        applyTransform()
        panel.contentView?.layer?.add(animation, forKey: "pop")
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            animationView.animator().alphaValue = visible ? 1 : 0
        }, completionHandler: nil)
        try? await Task.sleep(for: .seconds(duration))
        panel.contentView?.layer?.removeAnimation(forKey: "pop")
        animationView.alphaValue = visible ? 1 : 0
    }

    /// A display link tied to the screen this window is on.
    public func displayLink(target: Any, selector: Selector) -> CADisplayLink? {
        panel.contentView?.displayLink(target: target, selector: selector)
    }

    /// Stops on the current frame and ends any `play` that is waiting.
    public func stopAnimation() {
        frameTimer?.invalidate()
        frameTimer = nil
        pendingPlay?.resume()
        pendingPlay = nil
    }

    private func applyTransform() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel.contentView?.layer?.sublayerTransform = transform(scale: scale)
        CATransaction.commit()
    }

    /// Mirror (when facing left) and scale about the centre of the window, whatever the layer's anchor point is.
    private func transform(scale: CGFloat) -> CATransform3D {
        guard let layer = panel.contentView?.layer else { return CATransform3DIdentity }
        let dx = layer.bounds.width * (0.5 - layer.anchorPoint.x)
        let dy = layer.bounds.height * (0.5 - layer.anchorPoint.y)
        var result = CATransform3DMakeTranslation(dx, dy, 0)
        result = CATransform3DScale(result, (facing == .left ? -1 : 1) * scale, scale, 1)
        return CATransform3DTranslate(result, -dx, -dy, 0)
    }
}
