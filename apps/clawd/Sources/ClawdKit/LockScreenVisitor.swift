import AppKit

/// Lets Clawd's window show on the lock screen.
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

    /// Above the lock screen's own windows.
    private static let lockScreenLevel: Int32 = 300

    private let window: ClawdWindow
    private let settings: Settings
    private var space: UInt64?
    private var isVisiting = false

    public init(window: ClawdWindow, settings: Settings) {
        self.window = window
        self.settings = settings
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(screenLocked), name: .init("com.apple.screenIsLocked"), object: nil)
        center.addObserver(self, selector: #selector(screenUnlocked), name: .init("com.apple.screenIsUnlocked"), object: nil)
    }

    /// He goes only while the Mac is locked, so he never rides this space over a fullscreen app.
    @objc private func screenLocked() {
        guard settings.visitsLockScreen, !isVisiting, window.isVisible, let server = WindowServer.shared else { return }
        let connection = server.mainConnection()
        let space = self.space ?? {
            let created = server.spaceCreate(connection, 1, 0)
            _ = server.spaceSetLevel(connection, created, Self.lockScreenLevel)
            _ = server.showSpaces(connection, [NSNumber(value: created)] as CFArray)
            return created
        }()
        self.space = space
        _ = server.addWindowsToSpace(connection, space, [NSNumber(value: window.windowNumber)] as CFArray, 7)
        isVisiting = true
    }

    @objc private func screenUnlocked() {
        guard isVisiting, let space, let server = WindowServer.shared else { return }
        isVisiting = false
        _ = server.removeWindowsFromSpaces(
            server.mainConnection(), [NSNumber(value: window.windowNumber)] as CFArray,
            [NSNumber(value: space)] as CFArray)
        window.rejoinDesktop()
    }
}
