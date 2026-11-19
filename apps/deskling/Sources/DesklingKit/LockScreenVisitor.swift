import AppKit

/// Lets Clawd's window, and his speech bubble, show on the lock screen.
///
/// macOS has no public way to do this. The window server keeps windows in "spaces", and a space given a
/// high enough level is drawn above the lock screen. Creating one and moving a window into it takes
/// functions from the private SkyLight framework, looked up by name at run time so that a macOS update
/// which removes them turns this feature off instead of breaking the app.
@MainActor
public final class LockScreenVisitor {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias SpaceCreate = @convention(c) (Int32, Int32, Int32) -> UInt64
    private typealias SpaceSetLevel = @convention(c) (Int32, UInt64, Int32) -> Int32
    private typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias AddWindowsToSpace = @convention(c) (Int32, UInt64, CFArray, Int32) -> Int32
    private typealias RemoveWindowsFromSpaces = @convention(c) (Int32, CFArray, CFArray) -> Int32

    private struct WindowServer {
        let mainConnection: MainConnection
        let spaceCreate: SpaceCreate
        let spaceSetLevel: SpaceSetLevel
        let showSpaces: ShowSpaces
        let addWindowsToSpace: AddWindowsToSpace
        let removeWindowsFromSpaces: RemoveWindowsFromSpaces

        static let shared: WindowServer? = {
            guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
            else { return nil }
            func symbol<T>(_ name: String, as type: T.Type) -> T? {
                dlsym(handle, name).map { unsafeBitCast($0, to: type) }
            }
            guard let mainConnection = symbol("SLSMainConnectionID", as: MainConnection.self),
                  let spaceCreate = symbol("SLSSpaceCreate", as: SpaceCreate.self),
                  let spaceSetLevel = symbol("SLSSpaceSetAbsoluteLevel", as: SpaceSetLevel.self),
                  let showSpaces = symbol("SLSShowSpaces", as: ShowSpaces.self),
                  let addWindowsToSpace = symbol("SLSSpaceAddWindowsAndRemoveFromSpaces", as: AddWindowsToSpace.self),
                  let removeWindowsFromSpaces = symbol("SLSRemoveWindowsFromSpaces", as: RemoveWindowsFromSpaces.self)
            else { return nil }
            return WindowServer(
                mainConnection: mainConnection, spaceCreate: spaceCreate, spaceSetLevel: spaceSetLevel,
                showSpaces: showSpaces, addWindowsToSpace: addWindowsToSpace,
                removeWindowsFromSpaces: removeWindowsFromSpaces)
        }()
    }

    /// False when this macOS no longer has the private functions the feature needs.
    public static var isSupported: Bool { WindowServer.shared != nil }

    /// The window server's level for notifications shown over the lock screen. Measured on macOS 27:
    /// a space at 300, the lock screen's own level, is hidden behind it; 400 and above are drawn on top.
    private static let lockScreenLevel: Int32 = 400

    private let window: CharacterWindow
    private let bubble: SpeechBubble?
    private let settings: Settings
    private var space: UInt64?
    /// True while his window is in the lock screen's layer.
    public private(set) var isVisiting = false
    private let isLocked: () -> Bool
    /// What the Mac last announced. Once it has spoken, that is trusted over asking, which can lag behind.
    private var announcedLocked: Bool?

    /// `isLocked` reports whether the Mac is locked right now; by default it asks the system.
    /// The two names are the system's own announcements that the screen has locked and unlocked.
    public init(
        window: CharacterWindow, bubble: SpeechBubble? = nil, settings: Settings,
        isLocked: @escaping () -> Bool = LockScreenVisitor.screenIsLocked,
        lockedName: String = "com.apple.screenIsLocked", unlockedName: String = "com.apple.screenIsUnlocked"
    ) {
        self.window = window
        self.bubble = bubble
        self.settings = settings
        self.isLocked = isLocked
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(screenLocked), name: .init(lockedName), object: nil)
        center.addObserver(self, selector: #selector(screenUnlocked), name: .init(unlockedName), object: nil)
        // The Mac announces a lock once. If he starts, or is shown, while it is already locked,
        // that announcement has gone by, so he also checks each time he appears.
        window.didShow = { [weak self] in self?.update() }
        // The bubble is a window of its own; left behind, it would be drawn under the lock screen.
        bubble?.didShow = { [weak self] in self?.update() }
        update()
    }

    public nonisolated static func screenIsLocked() -> Bool {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        return session?["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    /// Puts him where he belongs for the Mac's state right now. He goes only while the Mac is locked,
    /// so he never rides this space over a fullscreen app.
    @objc private func screenLocked() {
        announcedLocked = true
        update()
    }

    @objc private func screenUnlocked() {
        announcedLocked = false
        update()
    }

    private func update() {
        guard let server = WindowServer.shared else { return }
        let locked = announcedLocked ?? isLocked()
        let connection = server.mainConnection()
        // A bubble that has never been shown has no window number yet.
        let numbers = [window.windowNumber] + [bubble?.windowNumber ?? 0].filter { $0 > 0 }
        let windows = numbers.map { NSNumber(value: $0) } as CFArray
        if locked, settings.visitsLockScreen, window.isVisible {
            let space = self.space ?? server.spaceCreate(connection, 1, 0)
            self.space = space
            // Repeated on every pass: all three are harmless to do twice.
            _ = server.spaceSetLevel(connection, space, Self.lockScreenLevel)
            _ = server.showSpaces(connection, [NSNumber(value: space)] as CFArray)
            _ = server.addWindowsToSpace(connection, space, windows, 7)
            isVisiting = true
        } else if isVisiting, let space {
            isVisiting = false
            _ = server.removeWindowsFromSpaces(connection, windows, [NSNumber(value: space)] as CFArray)
            if !locked {
                window.rejoinDesktop()
                bubble?.rejoinDesktop()
            }
        }
    }
}
