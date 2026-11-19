import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var performer: Performer?
    private var menu: MenuController?
    private var lockScreenVisitor: LockScreenVisitor?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = Settings()
        let catalog = AnimationCatalog(directory: Self.animationsDirectory)
        let window = ClawdWindow(size: settings.size.size)
        let performer = Performer(catalog: catalog, window: window, settings: settings)
        self.performer = performer
        menu = MenuController(performer: performer, settings: settings)
        performer.start(entrance: true)
        lockScreenVisitor = LockScreenVisitor(window: window, settings: settings)

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(screenChanged),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    /// Closing the About window must not quit a menubar app.
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func screenChanged() {
        performer?.refresh()
    }

    /// Inside the app bundle, or `CLAWD_ANIMATIONS` when run with `swift run`.
    private static var animationsDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["CLAWD_ANIMATIONS"] {
            return URL(fileURLWithPath: override)
        }
        return (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent("animations")
    }
}
