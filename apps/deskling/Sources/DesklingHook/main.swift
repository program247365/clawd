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

/// The parent of `pid`, or nil at the top of the tree.
func parent(of pid: pid_t) -> pid_t? {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
    guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
    let ppid = info.kp_eproc.e_ppid
    return ppid > 1 ? ppid : nil
}

/// The terminal device of the nearest process above this one that has one, e.g. "/dev/ttys003".
/// The hook itself may run without one; the agent above it does.
func terminalDevice(of chain: [Int32]) -> String? {
    for pid in chain {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { continue }
        let device = info.kp_eproc.e_tdev
        guard device != -1, let name = devname(device, S_IFCHR) else { continue }
        return "/dev/" + String(cString: name)
    }
    return nil
}

/// The processes above this one, nearest first: the agent, its shell, and somewhere up there the terminal or editor.
func ancestors() -> [Int32] {
    var chain: [Int32] = []
    var pid: pid_t? = getppid()
    while let current = pid, current > 1, chain.count < 24 {
        chain.append(current)
        pid = parent(of: current)
    }
    return chain
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
    let environment = ProcessInfo.processInfo.environment
    let chain = ancestors()
    event?.origin = AgentEvent.Origin(
        processes: chain, bundleID: environment["__CFBundleIdentifier"],
        tty: terminalDevice(of: chain),
        // Apps opened from a Warp shell (VS Code via `code .`) inherit the variable; only Warp's own shells set TERM_PROGRAM to it.
        focusURL: environment["TERM_PROGRAM"] == "WarpTerminal" ? environment["WARP_FOCUS_URL"] : nil)
}

if let event {
    DistributedNotificationCenter.default().postNotificationName(
        AgentEvent.notificationName, object: nil, userInfo: event.userInfo, deliverImmediately: true)
}
exit(0)
