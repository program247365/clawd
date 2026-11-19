import AppKit

/// Calls a handler on every display refresh until the handler says it is done or `stop()` is called.
@MainActor
private final class Ticker: NSObject {
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var handler: ((TimeInterval) -> Bool)?
    private var continuation: CheckedContinuation<Void, Never>?

    /// Resumes when `handler` returns true or the ticker is stopped. `handler` receives seconds since the last tick.
    func run(on window: CharacterWindow, handler: @escaping (TimeInterval) -> Bool) async {
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
/// Agent events and the cursor can interrupt it; afterwards he picks up where he left off.
@MainActor
public final class Performer {
    private enum Mode {
        case idle, entrance, routine, watching, reacting, alerting
    }

    private var character: Character
    private var catalog: AnimationCatalog
    private let window: CharacterWindow
    private let settings: Settings
    private let ticker = Ticker()
    private let bubble = SpeechBubble()
    private var queue: ActQueue
    private var rng = SystemRandomNumberGenerator()
    private var loop: Task<Void, Never>?
    private var stage: Stage?
    private var mode = Mode.idle
    /// Horizontal position along the floor, in `0...stage.maxX`.
    private var offset: CGFloat = 40
    private var facing: Facing = .right
    /// False while a teleport has him somewhere above the floor.
    private var onFloor = true
    /// Exists only during the launch entrance.
    private var spotlight: SpotlightWindow?
    /// Whether the user wants him shown. A loop may not exist yet, for example with no screen attached.
    private var wantsVisible = false
    /// After the entrance his first move is a walk from where he landed, never a teleport.
    private var mustWalkNext = false
    /// What he is telling you while an agent waits on you; he keeps waving until it is cleared.
    public private(set) var alertText: String?
    private let visibleFrame: () -> CGRect?
    private let cursorLocation: () -> CGPoint

    private var walking: CharacterAnimation?
    private var looking: CharacterAnimation?
    private var cursorTimer: Timer?
    private var watchStarted = Date.distantPast
    private var cursorLastNear = Date.distantPast
    /// Set when he has watched the cursor long enough; cleared once it moves away from him.
    private var ignoresCursorUntilItLeaves = false

    /// `visibleFrame` is the usable area of the display he lives on, or nil when there is none.
    /// By default that is the first screen, the one with the menubar.
    public init(
        character: Character, window: CharacterWindow, settings: Settings,
        visibleFrame: @escaping () -> CGRect? = { NSScreen.screens.first?.visibleFrame },
        cursorLocation: @escaping () -> CGPoint = { NSEvent.mouseLocation }
    ) {
        self.character = character
        catalog = character.catalog
        self.window = window
        self.settings = settings
        self.visibleFrame = visibleFrame
        self.cursorLocation = cursorLocation
        queue = ActQueue(names: catalog.actNames)
    }

    /// True from `start()` until `stop()`, whether or not there is a screen to show him on yet.
    public var isRunning: Bool { wantsVisible }

    public var characterName: String { character.name }

    /// Places him on the floor and begins the routine. Does nothing if already running.
    /// With `entrance`, he first drops in from the top of the screen, waving. That is for launch only.
    public func start(entrance: Bool = false) {
        wantsVisible = true
        startCursorWatch()
        guard loop == nil, let stage = placeOnFloor() else { return }
        if entrance {
            // Above the screen before the window appears, so he is never seen standing on the floor first.
            offset = stage.maxX / 2
            window.origin = stage.entranceOrigin(x: offset)
            mode = .entrance
        }
        window.show()
        loop = Task { [weak self] in await self?.begin(on: stage, entrance: entrance) }
    }

    public func stop() {
        wantsVisible = false
        cancelLoop()
        cursorTimer?.invalidate()
        cursorTimer = nil
        mode = .idle
        window.hide()
    }

    /// Call when the screen layout or the size setting changes.
    public func refresh() {
        cancelLoop()
        if wantsVisible { start() } else { placeOnFloor() }
    }

    /// Swaps who is on the desktop. The new character starts their routine where the old one stood.
    public func setCharacter(_ newCharacter: Character) {
        guard newCharacter != character else { return }
        character = newCharacter
        catalog = newCharacter.catalog
        queue = ActQueue(names: catalog.actNames)
        walking = nil
        looking = nil
        refresh()
    }

    // MARK: Agents

    /// Plays an act for `role` where he stands, with `saying` over his head. Ignored during the entrance,
    /// while he is alerting you, or when this character has no act for the role.
    public func react(_ role: Role, saying: String? = nil) {
        guard mode == .routine || mode == .watching || mode == .reacting,
              let name = character.acts(for: role).randomElement(using: &rng)
        else { return }
        interrupt(as: .reacting) { performer, _ in
            let catalog = performer.catalog
            guard let act = await Task.detached(operation: { catalog.load(name) }).value,
                  !Task.isCancelled
            else { return }
            if let saying { performer.say(saying) }
            await performer.perform(act)
            performer.bubble.hide()
        }
    }

    /// Comes to the middle of the floor and waves with `text` over his head until `clearAlert()`.
    public func alert(_ text: String) {
        alertText = text
        switch mode {
        case .alerting: say(text)
        case .idle, .entrance: break // picked up when the routine would start
        default: interrupt(as: .alerting) { _, _ in }
        }
    }

    public func clearAlert() {
        alertText = nil
        if mode == .alerting { interrupt(as: .routine) { _, _ in } }
    }

    // MARK: Routine

    private func cancelLoop() {
        loop?.cancel()
        loop = nil
        spotlight?.close()
        spotlight = nil
        ticker.stop()
        window.stopAnimation()
        bubble.hide()
    }

    /// Stops what he is doing, runs `body`, then carries on with the routine or the alert.
    private func interrupt(as newMode: Mode, _ body: @escaping (Performer, Stage) async -> Void) {
        guard wantsVisible, let stage else { return }
        cancelLoop()
        mode = newMode
        loop = Task { [weak self] in
            guard let self else { return }
            await returnToFloor(on: stage)
            if Task.isCancelled { return }
            await body(self, stage)
            if Task.isCancelled { return }
            await carryOn(on: stage)
        }
    }

    @discardableResult
    private func placeOnFloor() -> Stage? {
        guard let visibleFrame = visibleFrame() else { return nil }
        let stage = Stage(visibleFrame: visibleFrame, size: settings.size.size)
        self.stage = stage
        offset = min(max(offset, 0), stage.maxX)
        onFloor = true
        window.resize(to: stage.size)
        window.origin = stage.floorOrigin(x: offset)
        window.facing = facing
        return stage
    }

    private func loadWalking() -> CharacterAnimation? {
        if walking == nil { walking = catalog.load("walking") }
        return walking
    }

    private func standStill() {
        if let walking = loadWalking() { window.pose(walking, frame: character.standingFrame) }
    }

    private func begin(on stage: Stage, entrance: Bool) async {
        guard let walking = loadWalking() else { return }
        window.origin = entrance ? stage.entranceOrigin(x: offset) : stage.floorOrigin(x: offset)
        if entrance {
            await dropIn(on: stage, thenStandAs: walking)
            if Task.isCancelled { return }
            mustWalkNext = true
        } else {
            standStill()
        }
        await carryOn(on: stage)
    }

    /// The alert if an agent is waiting on you, otherwise the routine.
    private func carryOn(on stage: Stage) async {
        if alertText != nil, settings.alertsForAgents {
            await waveForAttention(on: stage)
        } else {
            await routine(on: stage)
        }
    }

    /// A teleport can leave him in mid-air; anything that interrupts him brings him back down first.
    private func returnToFloor(on stage: Stage) async {
        guard !onFloor || window.opacity < 1 else { return }
        await window.pop(visible: false)
        if Task.isCancelled { return }
        window.origin = stage.floorOrigin(x: offset)
        onFloor = true
        standStill()
        await window.pop(visible: true)
    }

    private func routine(on stage: Stage) async {
        mode = .routine
        guard let walking = loadWalking() else { return }
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
                onFloor = false
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
                onFloor = true
                window.pose(walking, frame: character.standingFrame)
                await window.pop(visible: true)
            } else {
                let target = Choreography.nextWalkStop(from: offset, facing: facing, maxX: stage.maxX, using: &rng)
                await walk(to: target, on: stage, with: walking)
                if Task.isCancelled { return }
                await perform(act)
            }
            if Task.isCancelled { return }
        }
    }

    private func walk(to target: CGFloat, on stage: Stage, with walking: CharacterAnimation) async {
        face(target >= offset ? .right : .left)
        window.loopWalk(walking, cycle: character.walkCycle)
        await ticker.run(on: window) { [weak self] elapsed in
            guard let self else { return true }
            let step = Choreography.step(x: offset, toward: target, width: stage.size.width, elapsed: elapsed)
            offset = step.x
            window.origin = stage.floorOrigin(x: offset)
            return step.arrived
        }
        if !Task.isCancelled { standStill() }
    }

    private func face(_ direction: Facing) {
        facing = direction
        window.facing = direction
    }

    /// Hurries to the middle of the floor and waves until the alert is cleared or replaced.
    private func waveForAttention(on stage: Stage) async {
        mode = .alerting
        guard let walking = loadWalking() else { return }
        let middle = stage.maxX / 2
        if abs(offset - middle) > stage.size.width {
            await window.pop(visible: false)
            if Task.isCancelled { return }
            offset = middle
            window.origin = stage.floorOrigin(x: offset)
            standStill()
            await window.pop(visible: true)
            if Task.isCancelled { return }
        }
        face(.right)
        if let alertText { say(alertText) }
        let waving = catalog.load("waving")
        while !Task.isCancelled {
            if let waving { await window.play(waving) }
            if Task.isCancelled { return }
            window.pose(walking, frame: character.standingFrame)
            try? await Task.sleep(for: .seconds(1.5))
        }
    }

    private func say(_ text: String) {
        guard let screen = visibleFrame() else { return }
        bubble.show(text, above: window.frame, within: screen)
    }

    // MARK: Cursor

    private func startCursorWatch() {
        guard cursorTimer == nil else { return }
        // Eight looks a second is plenty to notice a cursor and costs next to nothing.
        let timer = Timer(timeInterval: 1.0 / 8, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.cursorTick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        cursorTimer = timer
    }

    /// How long he watches before going back to his routine, and how long the cursor must be gone first.
    static let longestWatch: TimeInterval = 20
    static let watchLinger: TimeInterval = 1

    private func cursorTick() {
        guard let stage else { return }
        let now = Date()
        let gaze = Gaze.toward(cursorLocation(), from: window.frame)
        switch mode {
        case .routine:
            guard let gaze else {
                ignoresCursorUntilItLeaves = false
                return
            }
            guard onFloor, window.opacity == 1, !ignoresCursorUntilItLeaves else { return }
            cancelLoop()
            mode = .watching
            watchStarted = now
            cursorLastNear = now
            look(gaze)
        case .watching:
            if let gaze { cursorLastNear = now; look(gaze) }
            let bored = now.timeIntervalSince(watchStarted) > Self.longestWatch
            guard bored || now.timeIntervalSince(cursorLastNear) > Self.watchLinger else { return }
            ignoresCursorUntilItLeaves = bored
            mustWalkNext = true
            mode = .routine
            loop = Task { [weak self] in await self?.carryOn(on: stage) }
        default:
            break
        }
    }

    private func look(_ gaze: Gaze) {
        if gaze.facing != facing { face(gaze.facing) }
        if gaze.eyes == .up {
            if looking == nil { looking = catalog.load("looking") }
            if let looking {
                window.pose(looking, frame: character.lookUpFrame)
                return
            }
        }
        standStill()
    }

    /// The launch entrance: he falls from above the screen, lands, waves once, and then stands
    /// where he landed until the spotlight has faded.
    private func dropIn(on stage: Stage, thenStandAs walking: CharacterAnimation) async {
        guard let waving = catalog.load("waving") else { return }
        let top = stage.entranceOrigin(x: offset)
        var falling: TimeInterval = 0
        window.origin = top
        window.pose(walking, frame: character.standingFrame)
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
        window.pose(walking, frame: character.standingFrame)
        await spotlight.fadeOut()
        self.spotlight = nil
    }

    private func perform(_ act: CharacterAnimation) async {
        for _ in 0..<Choreography.plays(forFrameCount: act.frameCount) {
            await window.play(act)
            if Task.isCancelled { return }
        }
    }

}
