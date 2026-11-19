import DesklingEvents
import Foundation

/// What the character should do about an agent event.
public enum AgentReaction: Equatable {
    /// Play an act for this role, optionally with a few words over his head.
    case perform(Role, saying: String?)
    /// Come and wave until it is cleared. Replaces any alert already showing.
    case alert(String)
    case clearAlert
}

/// Keeps track of which agent sessions are waiting on you and turns events into reactions,
/// sparingly: a character that acts out every tool call is noise.
public struct AgentDesk {
    /// Shortest gap between two ambient acts.
    public static let ambientGap: TimeInterval = 45
    /// Shortest gap between two celebrations.
    public static let celebrateGap: TimeInterval = 10

    /// Projects of the sessions waiting on you, by agent and session.
    public private(set) var waiting: [String: String] = [:]
    private var lastAmbient: Date?
    private var lastCelebration: Date?

    public init() {}

    public mutating func handle(_ event: AgentEvent, at now: Date, ambient: Bool = true, alerts: Bool = true) -> [AgentReaction] {
        let key = "\(event.agent)/\(event.session)"
        var reactions: [AgentReaction] = []

        if event.kind == .needsInput {
            guard alerts else { return [] }
            waiting[key] = event.project
            return [.alert(alertMessage)]
        }

        // Anything else from a waiting session means you answered it.
        if waiting.removeValue(forKey: key) != nil {
            reactions.append(waiting.isEmpty ? .clearAlert : .alert(alertMessage))
        }
        // While someone is waiting, he stays put and keeps waving.
        guard waiting.isEmpty else { return reactions }

        if event.kind == .finished {
            if lastCelebration.map({ now.timeIntervalSince($0) >= Self.celebrateGap }) ?? true {
                lastCelebration = now
                reactions.append(.perform(.celebrate, saying: "\(event.project) is done"))
            }
            return reactions
        }

        guard ambient, let role = Self.role(for: event),
              lastAmbient.map({ now.timeIntervalSince($0) >= Self.ambientGap }) ?? true
        else { return reactions }
        lastAmbient = now
        reactions.append(.perform(role, saying: nil))
        return reactions
    }

    /// Forgets every waiting session, as when you dismiss the alert from the menu.
    public mutating func dismissAll() {
        waiting.removeAll()
    }

    public var alertMessage: String {
        switch waiting.count {
        case 0: ""
        case 1: "\(waiting.values.first!) needs you"
        default: "\(waiting.count) agents need you"
        }
    }

    static func role(for event: AgentEvent) -> Role? {
        switch event.kind {
        case .promptSubmitted: return .think
        case .compacting: return .compact
        case .toolStarted:
            switch event.tool {
            case "Bash", "BashOutput", "shell", "exec_command": return .type
            case "Edit", "MultiEdit", "Write", "NotebookEdit", "TodoWrite", "apply_patch": return .write
            case "WebFetch", "WebSearch": return .browse
            case "Read", "Grep", "Glob", "LS": return .search
            case "Task", "Agent": return .delegate
            default: return nil
            }
        default: return nil
        }
    }
}
