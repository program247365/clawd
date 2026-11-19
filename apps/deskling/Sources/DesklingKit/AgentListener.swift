import DesklingEvents
import Foundation

/// Hears what coding agents are doing (posted by `deskling-hook`) and has the character react.
@MainActor
public final class AgentListener {
    private let performer: Performer
    private let settings: Settings
    private var desk = AgentDesk()
    private var observer: NSObjectProtocol?

    public init(performer: Performer, settings: Settings) {
        self.performer = performer
        self.settings = settings
        observer = DistributedNotificationCenter.default().addObserver(
            forName: AgentEvent.notificationName, object: nil, queue: .main
        ) { [weak self] notification in
            guard let event = AgentEvent(userInfo: notification.userInfo) else { return }
            MainActor.assumeIsolated { self?.handle(event) }
        }
    }

    /// The alert being shown, if any, for the menu.
    public var alertMessage: String? { desk.waiting.isEmpty ? nil : desk.alertMessage }

    public func handle(_ event: AgentEvent, at now: Date = Date()) {
        let reactions = desk.handle(
            event, at: now, ambient: settings.reactsToAgents, alerts: settings.alertsForAgents)
        for reaction in reactions {
            switch reaction {
            case let .perform(role, saying): performer.react(role, saying: saying)
            case let .alert(text): performer.alert(text)
            case .clearAlert: performer.clearAlert()
            }
        }
    }

    public func dismissAlert() {
        desk.dismissAll()
        performer.clearAlert()
    }
}
