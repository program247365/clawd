import Foundation

/// What a coding agent just did, reduced to the little the desktop character needs.
/// Prompts, tool inputs, and messages never leave the hook.
public struct AgentEvent: Equatable, Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        case sessionStarted, promptSubmitted, toolStarted, toolFinished, needsInput, finished, compacting, sessionEnded
    }

    public let agent: String
    public let kind: Kind
    public let session: String
    /// The last component of the working directory, e.g. "clawd".
    public let project: String
    public let tool: String?
    /// Where the agent is running, so clicking the character can take you there. Only sent with `needsInput`.
    public var origin: Origin?

    /// The processes the hook ran under, nearest first, and the app the agent's shell was started from.
    /// Enough for the app to find the terminal or editor; nothing about what the agent is doing.
    public struct Origin: Equatable, Sendable {
        public let processes: [Int32]
        /// macOS's `__CFBundleIdentifier` for the shell, e.g. "com.apple.Terminal". Survives tmux, which breaks the process chain.
        public let bundleID: String?

        public init(processes: [Int32], bundleID: String?) {
            self.processes = processes
            self.bundleID = bundleID
        }
    }

    public init(agent: String, kind: Kind, session: String, project: String, tool: String? = nil, origin: Origin? = nil) {
        self.agent = agent
        self.kind = kind
        self.session = session
        self.project = project
        self.tool = tool
        self.origin = origin
    }

    /// The name the hook posts on and the app listens for. `DESKLING_EVENT_NAME` replaces it, so tests can
    /// run the real hook without a running Deskling hearing their made-up agents.
    public static var notificationName: Notification.Name {
        Notification.Name(ProcessInfo.processInfo.environment["DESKLING_EVENT_NAME"] ?? "sh.kbr.deskling.agent-event")
    }

    public var userInfo: [String: String] {
        var info = ["agent": agent, "kind": kind.rawValue, "session": session, "project": project]
        info["tool"] = tool
        if let origin {
            info["processes"] = origin.processes.map(String.init).joined(separator: ",")
            info["bundleID"] = origin.bundleID
        }
        return info
    }

    public init?(userInfo: [AnyHashable: Any]?) {
        guard let info = userInfo,
              let agent = info["agent"] as? String,
              let kind = (info["kind"] as? String).flatMap(Kind.init(rawValue:)),
              let session = info["session"] as? String,
              let project = info["project"] as? String
        else { return nil }
        let processes = (info["processes"] as? String)?.split(separator: ",").compactMap { Int32($0) }
        let bundleID = info["bundleID"] as? String
        let origin = processes == nil && bundleID == nil ? nil : Origin(processes: processes ?? [], bundleID: bundleID)
        self.init(agent: agent, kind: kind, session: session, project: project, tool: info["tool"] as? String, origin: origin)
    }

    /// A hook's stdin JSON. Claude Code and Codex share the format: `hook_event_name`, `session_id`,
    /// `cwd`, and `tool_name` for tool events. Nil for events the character does not react to.
    public init?(hook json: [String: Any], agent: String) {
        let kind: Kind
        switch json["hook_event_name"] as? String {
        case "SessionStart": kind = .sessionStarted
        case "UserPromptSubmit": kind = .promptSubmitted
        case "PreToolUse": kind = .toolStarted
        // Codex's Interrupt means you stopped the turn yourself, so you are clearly at the keyboard.
        case "PostToolUse", "Interrupt": kind = .toolFinished
        case "Stop": kind = .finished
        case "PreCompact": kind = .compacting
        case "SessionEnd": kind = .sessionEnded
        // About to ask you to approve something. Codex has no idle notification; this is its only one.
        case "PermissionRequest": kind = .needsInput
        case "Notification":
            // Only the notifications that mean Claude is waiting on you; logins, quotas and the like are news.
            guard Self.waitingNotifications.contains(json["notification_type"] as? String ?? "") else { return nil }
            kind = .needsInput
        default: return nil
        }
        self.init(
            agent: agent, kind: kind,
            session: json["session_id"] as? String ?? agent,
            project: Self.project(fromDirectory: json["cwd"] as? String),
            tool: kind == .toolStarted || kind == .toolFinished ? json["tool_name"] as? String : nil)
    }

    static let waitingNotifications: Set<String> = [
        "permission_prompt", "idle_prompt", "elicitation_dialog", "elicitation_url_dialog", "agent_needs_input",
    ]

    static func project(fromDirectory path: String?) -> String {
        guard let path, !path.isEmpty else { return "your agent" }
        let name = URL(fileURLWithPath: path).lastPathComponent
        return name.isEmpty || name == "/" ? "your agent" : name
    }
}
