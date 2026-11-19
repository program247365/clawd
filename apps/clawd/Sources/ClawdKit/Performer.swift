import AppKit

/// Calls a handler on every display refresh until the handler says it is done or `stop()` is called.
@MainActor
private final class Ticker: NSObject {
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var handler: ((TimeInterval) -> Bool)?
    private var continuation: CheckedContinuation<Void, Never>?

    /// Resumes when `handler` returns true or the ticker is stopped. `handler` receives seconds since the last tick.
    func run(on window: ClawdWindow, handler: @escaping (TimeInterval) -> Bool) async {
        stop()
        guard let link = window.displayLink(target: self, selector: #selector(tick(_:))) else { return }
        // He walks about 70pt a second; 30 moves a second is smooth for 12fps pixel art
        // and halves the cost of moving the window on every display refresh.
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 30, preferred: 30)
        self.link = link
        self.handler = handler
        lastTimestamp = nil
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.continuation = continuation
            link.add(to: .main, forMode: .common)
        }
    }

    func stop() {
        link?.invalidate()
        link = nil
        handler = nil
        continuation?.resume()
        continuation = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        let elapsed = lastTimestamp.map { link.timestamp - $0 } ?? link.duration
        lastTimestamp = link.timestamp
        if handler?(elapsed) == true { stop() }
    }
}

/// Clawd's routine: walk to a stop, perform an act, repeat; sometimes teleport instead of walking.
@MainActor
public final class Performer {
    private let catalog: AnimationCatalog
    private let window: ClawdWindow
    private let settings: Settings
    private let ticker = Ticker()
    private var queue: ActQueue
    private var rng = SystemRandomNumberGenerator()
    private var loop: Task<Void, Never>?
    private var stage: Stage?
    /// Horizontal position along the floor, in `0...stage.maxX`.
    private var offset: CGFloat = 40
    private var facing: Facing = .right
    /// Exists only during the launch entrance.
    private var spotlight: SpotlightWindow?
    /// Whether the user wants him shown. A loop may not exist yet, for example with no screen attached.
    private var wantsVisible = false
    /// After the entrance his first move is a walk from where he landed, never a teleport.
    private var mustWalkNext = false
    private let visibleFrame: () -> CGRect?

    /// `visibleFrame` is the usable area of the display he lives on, or nil when there is none.
    /// By default that is the first screen, the one with the menubar.
    public init(
        catalog: AnimationCatalog, window: ClawdWindow, settings: Settings,
        visibleFrame: @escaping () -> CGRect? = { NSScreen.screens.first?.visibleFrame }
    ) {
        self.catalog = catalog
        self.window = window
        self.settings = settings
        self.visibleFrame = visibleFrame
        queue = ActQueue(names: catalog.actNames)
    }

    /// True from `start()` until `stop()`, whether or not there is a screen to show him on yet.
    public var isRunning: Bool { wantsVisible }

    /// Places him on the floor and begins the routine. Does nothing if already running.
    /// With `entrance`, he first drops in from the top of the screen, waving. That is for launch only.
    public func start(entrance: Bool = false) {
        wantsVisible = true
        guard loop == nil, let stage = placeOnFloor() else { return }
        if entrance {
            // Above the screen before the window appears, so he is never seen standing on the floor first.
            offset = stage.maxX / 2
            window.origin = stage.entranceOrigin(x: offset)
        }
        window.show()
        loop = Task { [weak self] in await self?.run(on: stage, entrance: entrance) }
    }

    public func stop() {
        wantsVisible = false
        cancelLoop()
        window.hide()
    }

    /// Call when the screen layout or the size setting changes.
    public func refresh() {
        cancelLoop()
        if wantsVisible { start() } else { placeOnFloor() }
    }

    private func cancelLoop() {
        loop?.cancel()
        loop = nil
        spotlight?.close()
        spotlight = nil
        ticker.stop()
        window.stopAnimation()
    }

    @discardableResult
    private func placeOnFloor() -> Stage? {
        guard let visibleFrame = visibleFrame() else { return nil }
        let stage = Stage(visibleFrame: visibleFrame, size: settings.size.size)
        self.stage = stage
        offset = min(max(offset, 0), stage.maxX)
        window.resize(to: stage.size)
        window.origin = stage.floorOrigin(x: offset)
        window.facing = facing
        return stage
    }

    private func run(on stage: Stage, entrance: Bool) async {
        guard let walking = catalog.load("walking") else { return }
        window.origin = entrance ? stage.entranceOrigin(x: offset) : stage.floorOrigin(x: offset)
        if entrance {
            await dropIn(on: stage, thenStandAs: walking)
            if Task.isCancelled { return }
            mustWalkNext = true
        } else {
            window.pose(walking, frame: Self.standingFrame)
        }

        while !Task.isCancelled {
            guard let name = queue.next(using: &rng) else { return }
            // Parsed off the main thread, one act at a time, and dropped after it plays.
            let catalog = catalog
            guard let act = await Task.detached(operation: { catalog.load(name) }).value else {
                // An unreadable act is skipped; the pause keeps a folder of bad files from spinning.
                try? await Task.sleep(for: .seconds(1))
                continue
            }
            if Task.isCancelled { return }

            let walksFirst = mustWalkNext
            mustWalkNext = false
            // Read each time round, so changing the setting takes effect on his very next move.
            if !walksFirst, Choreography.shouldTeleport(roams: settings.roams, using: &rng) {
                await window.pop(visible: false)
                if Task.isCancelled { return }
                window.origin = stage.teleportOrigin(using: &rng)
                window.pose(act, frame: 0)
                await window.pop(visible: true)
                if Task.isCancelled { return }
                await perform(act)
                if Task.isCancelled { return }
                await window.pop(visible: false)
                if Task.isCancelled { return }
                offset = CGFloat.random(in: 0...stage.maxX, using: &rng)
                window.origin = stage.floorOrigin(x: offset)
                window.pose(walking, frame: Self.standingFrame)
                await window.pop(visible: true)
            } else {
                let target = Choreography.nextWalkStop(from: offset, facing: facing, maxX: stage.maxX, using: &rng)
                facing = target >= offset ? .right : .left
                window.facing = facing
                window.loopWalk(walking)
                await ticker.run(on: window) { [weak self] elapsed in
                    guard let self else { return true }
                    let step = Choreography.step(x: offset, toward: target, width: stage.size.width, elapsed: elapsed)
                    offset = step.x
                    window.origin = stage.floorOrigin(x: offset)
                    return step.arrived
                }
                if Task.isCancelled { return }
                await perform(act)
            }
            if Task.isCancelled { return }
        }
    }

    /// The launch entrance: he falls from above the screen, lands, waves once, and then stands
    /// where he landed until the spotlight has faded.
    private func dropIn(on stage: Stage, thenStandAs walking: ClawdAnimation) async {
        guard let waving = catalog.load("waving") else { return }
        let top = stage.entranceOrigin(x: offset)
        var falling: TimeInterval = 0
        window.origin = top
        window.pose(walking, frame: Self.standingFrame)
        let spotlight = SpotlightWindow(frame: stage.spotlightFrame(x: offset))
        self.spotlight = spotlight
        spotlight.fadeIn()
        await ticker.run(on: window) { [weak self] elapsed in
            guard let self else { return true }
            // Sum honored ticks rather than reading a clock, so a stalled frame cannot skip the fall.
            falling += min(max(elapsed, 0), Choreography.maxStep)
            let drop = Choreography.drop(from: top.y, to: stage.floorY, elapsed: falling)
            window.origin = CGPoint(x: top.x, y: drop.y)
            return drop.landed
        }
        if Task.isCancelled { return }
        await window.play(waving)
        if Task.isCancelled { return }
        window.pose(walking, frame: Self.standingFrame)
        await spotlight.fadeOut()
        self.spotlight = nil
    }

    private func perform(_ act: ClawdAnimation) async {
        for _ in 0..<Choreography.plays(forFrameCount: act.frameCount) {
            await window.play(act)
            if Task.isCancelled { return }
        }
        // The previous act has been dropped by now; give its memory back rather than holding it all day.
        Memory.returnUnused()
    }

    /// The standing pose at the end of the walking animation.
    private static let standingFrame: CGFloat = 26
}
