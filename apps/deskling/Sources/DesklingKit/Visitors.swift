import DesklingEvents
import Foundation

/// Characters called on by name for an alert, as `deskling alert --character nook`. Each drops in at the middle
/// of the screen, beside anyone already waving there, waves until the alert is cleared or you click them, then leaves.
/// The one who lives there carries on as usual, so agents can still talk through them.
@MainActor
public final class Visitors {
    private struct Guest {
        let performer: Performer
        var origin: AgentEvent.Origin?
    }

    private let roster: Roster
    private let settings: Settings
    private let floor: Floor
    private let host: Performer
    private let makeWindow: () -> CharacterWindow
    private let alertFrame: () -> CGRect?
    /// Who is visiting, by the project that called them.
    private var guests: [String: Guest] = [:]

    public init(
        roster: Roster, settings: Settings, floor: Floor, host: Performer,
        makeWindow: (() -> CharacterWindow)? = nil,
        alertFrame: @escaping () -> CGRect? = { MainActor.assumeIsolated { Performer.cursorScreenFrame() } }
    ) {
        self.roster = roster
        self.settings = settings
        self.floor = floor
        self.host = host
        self.makeWindow = makeWindow ?? { CharacterWindow(size: settings.size.size) }
        self.alertFrame = alertFrame
    }

    /// The projects with someone visiting for them.
    public var visiting: [String] { guests.keys.sorted() }

    /// The visitor for `project`, if any.
    public func performer(for project: String) -> Performer? { guests[project]?.performer }

    /// True if `command` is a visitor's to handle: an alert naming someone other than the host.
    /// Clearing sends any visitor for that project home and is never only theirs.
    public func handle(_ command: DesklingCommand) -> Bool {
        switch command.action {
        case .alert:
            guard let name = command.character, let character = roster.character(named: name),
                  character.id != host.characterID, let text = command.text
            else { return false }
            guard settings.agentsCanSpeak, settings.alertsForAgents, host.isShown else { return true }
            if guests[command.project] != nil {
                guests[command.project]?.origin = command.origin ?? guests[command.project]?.origin
                guests[command.project]?.performer.alert(text)
                return true
            }
            arrive(character, for: command.project, saying: text, origin: command.origin)
            return true
        case .clear:
            dismiss(command.project)
            return false
        case .say:
            return false
        }
    }

    public func dismiss(_ project: String) {
        guard let guest = guests.removeValue(forKey: project) else { return }
        Task { await guest.performer.leave() }
    }

    public func dismissAll() {
        for project in guests.keys { dismiss(project) }
    }

    /// After a screen change: each visitor finds their place again.
    public func refresh() {
        for guest in guests.values { guest.performer.refresh() }
    }

    private func arrive(_ character: Character, for project: String, saying text: String, origin: AgentEvent.Origin?) {
        let screen = alertFrame()
        let performer = Performer(
            character: character, window: makeWindow(), settings: settings,
            visibleFrame: { screen }, alertFrame: alertFrame, floor: floor)
        // Clicking takes you to whoever called them, where it can; otherwise it means "seen it".
        performer.onAlertClick = { [weak self] in
            guard let self else { return }
            if !AgentApp.goTo(guests[project]?.origin) { dismiss(project) }
        }
        guests[project] = Guest(performer: performer, origin: origin)
        performer.visit(saying: text)
    }
}
