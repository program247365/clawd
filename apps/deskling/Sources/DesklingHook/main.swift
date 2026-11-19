import DesklingEvents
import Foundation

// Tells the desktop app what a coding agent is doing. Runs on every hook, so it must be quick,
// print nothing, and always exit 0: a broken or absent app must never get in the agent's way.
//
//   deskling-hook [--agent claude]        Claude Code hook JSON on stdin
//   deskling-hook --agent codex           Codex hook JSON on stdin (same format)
//   deskling-hook --agent NAME --event KIND [--session ID] [--project NAME] [--tool NAME]
//                                      any other agent; KIND is one of AgentEvent.Kind

func value(after flag: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

func jsonObject(_ data: Data) -> [String: Any]? {
    (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
}

let arguments = Array(CommandLine.arguments.dropFirst())
var event: AgentEvent?

if let kind = value(after: "--event", in: arguments).flatMap(AgentEvent.Kind.init(rawValue:)) {
    let agent = value(after: "--agent", in: arguments) ?? "agent"
    event = AgentEvent(
        agent: agent, kind: kind,
        session: value(after: "--session", in: arguments) ?? agent,
        project: value(after: "--project", in: arguments)
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).lastPathComponent,
        tool: value(after: "--tool", in: arguments))
} else if let json = jsonObject(FileHandle.standardInput.readDataToEndOfFile()) {
    event = AgentEvent(hook: json, agent: value(after: "--agent", in: arguments) ?? "claude")
}

// Only a waiting agent can be clicked through to, so only then is it worth looking up where it runs.
if event?.kind == .needsInput {
    event?.origin = .current()
}

if let event {
    DistributedNotificationCenter.default().postNotificationName(
        AgentEvent.notificationName, object: nil, userInfo: event.userInfo, deliverImmediately: true)
}
exit(0)
