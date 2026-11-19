import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var performer: Performer?
    private var menu: MenuController?
    private var lockScreenVisitor: LockScreenVisitor?
    private var agents: AgentListener?
    private var picker: CharacterPickerWindowController?
    private var updater: Updater?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = Settings()
        settings.importPrevious(from: UserDefaults(suiteName: Settings.previousDomain))
        let roster = Roster(clawdDirectory: Self.resource("animations", override: "DESKLING_ANIMATIONS"),
                            charactersDirectory: Self.resource("characters", override: "DESKLING_CHARACTERS"))
        let window = CharacterWindow(size: settings.size.size)
        let bubble = SpeechBubble()
        let performer = Performer(
            character: roster.character(id: settings.characterID), window: window, bubble: bubble, settings: settings)
        self.performer = performer
        let agents = AgentListener(performer: performer, settings: settings)
        self.agents = agents
        let picker = CharacterPickerWindowController(roster: roster, settings: settings) { [weak self] character in
            performer.setCharacter(character)
            self?.menu?.showIcon(for: character)
        }
        self.picker = picker
        // A local build with no update feed (such as `swift run`) leaves updating to you.
        let updater = Updater.isAvailable ? Updater(performer: performer) : nil
        self.updater = updater
        menu = MenuController(
            performer: performer, settings: settings, roster: roster, agents: agents, picker: picker, updater: updater)
        lockScreenVisitor = LockScreenVisitor(window: window, bubble: bubble, settings: settings)

        // The first time, you choose who lives on your desktop; they make their entrance once you have.
        if settings.hasChosenCharacter {
            performer.start(entrance: true)
        } else {
            picker.showWelcome {
                settings.hasChosenCharacter = true
                performer.start(entrance: true)
            }
        }

        // After an update they say so, once they have made their entrance.
        if let last = settings.lastRunVersion, last != AppInfo.version {
            performer.announce(Performer.Announcement(lines: ["Now on Deskling \(AppInfo.version)!"], holdFor: 4))
        }
        settings.lastRunVersion = AppInfo.version

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

    /// A folder inside the app bundle, or the path in `override` when run with `swift run`.
    private static func resource(_ name: String, override: String) -> URL {
        if let path = ProcessInfo.processInfo.environment[override] {
            return URL(fileURLWithPath: path)
        }
        return (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent(name)
    }
}
