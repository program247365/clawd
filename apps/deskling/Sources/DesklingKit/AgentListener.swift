import DesklingEvents
import Foundation

/// Hears what coding agents are doing (posted by `deskling-hook`) and has the character react.
@MainActor
public final class AgentListener {
    private let performer: Performer
    private let settings: Settings
    private var desk = AgentDesk()
    private var observer: NSObjectProtocol?
    private var commandObserver: NSObjectProtocol?

    public init(performer: Performer, settings: Settings) {
        self.performer = performer
        self.settings = settings
        performer.onAlertClick = { [weak self] in self?.goToWaiting() }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: AgentEvent.notificationName, object: nil, queue: .main
        ) { [weak self] notification in
            guard let event = AgentEvent(userInfo: notification.userInfo) else { return }
            MainActor.assumeIsolated { self?.handle(event) }
        }
        commandObserver = DistributedNotificationCenter.default().addObserver(
            forName: DesklingCommand.notificationName, object: nil, queue: .main
        ) { [weak self] notification in
            guard let command = DesklingCommand(userInfo: notification.userInfo) else { return }
            MainActor.assumeIsolated { self?.handle(command) }
        }
    }

    /// Something an agent asked him to say, act out, or come and tell you.
    public func handle(_ command: DesklingCommand, at now: Date = Date()) {
        apply(desk.handle(command, at: now, speaks: settings.agentsCanSpeak, alerts: settings.alertsForAgents))
    }

    /// The sessions waiting on you, longest-waiting first, for the menu.
    public var waiting: [WaitingSession] { desk.waiting }

    public func handle(_ event: AgentEvent, at now: Date = Date()) {
        apply(desk.handle(event, at: now, ambient: settings.reactsToAgents, alerts: settings.alertsForAgents))
    }

    private func apply(_ reactions: [AgentReaction]) {
        for reaction in reactions {
            switch reaction {
            // A character with no act for the role still says the words.
            case let .perform(role, saying?) where !performer.hasActs(for: role): performer.speak(saying)
            case let .perform(role, saying): performer.react(role, saying: saying)
            case let .speak(text): performer.speak(text)
            case let .alert(text): performer.alert(text)
            case .clearAlert: performer.clearAlert()
            }
        }
    }

    /// Takes you to the agent that has waited longest, in its very tab where the terminal allows. If there is nowhere to take you, the click
    /// means "seen it" and he stops waving for that one.
    public func goToWaiting() {
        guard let session = desk.waiting.first else { return }
        if !AgentApp.goTo(session.origin) { dismiss(session.id) }
    }

    public func dismissAll() {
        desk.dismissAll()
        performer.clearAlert()
    }

    /// Stops waving for one session; the others keep their place.
    public func dismiss(_ id: String) {
        switch desk.dismiss(id) {
        case let .alert(text): performer.alert(text)
        case .clearAlert: performer.clearAlert()
        default: break
        }
    }
}
