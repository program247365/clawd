import Foundation

extension AgentEvent.Origin {
    /// Where the process asking is running: the processes above it, and what its environment says about the terminal.
    public static func current() -> Self {
        let environment = ProcessInfo.processInfo.environment
        let chain = ancestors()
        return Self(
            processes: chain, bundleID: environment["__CFBundleIdentifier"],
            tty: terminalDevice(of: chain),
            // Apps opened from a Warp shell (VS Code via `code .`) inherit the variable; only Warp's own shells set TERM_PROGRAM to it.
            focusURL: environment["TERM_PROGRAM"] == "WarpTerminal" ? environment["WARP_FOCUS_URL"] : nil)
    }

    var userInfo: [String: String] {
        var info = ["processes": processes.map(String.init).joined(separator: ",")]
        info["bundleID"] = bundleID
        info["tty"] = tty
        info["focusURL"] = focusURL
        return info
    }

    /// Nil when the notification says nothing about where the agent runs.
    init?(userInfo info: [AnyHashable: Any]) {
        let processes = (info["processes"] as? String)?.split(separator: ",").compactMap { Int32($0) }
        let bundleID = info["bundleID"] as? String
        let tty = info["tty"] as? String
        let focusURL = info["focusURL"] as? String
        guard processes != nil || bundleID != nil || tty != nil || focusURL != nil else { return nil }
        self.init(processes: processes ?? [], bundleID: bundleID, tty: tty, focusURL: focusURL)
    }
}

/// The parent of `pid`, or nil at the top of the tree.
private func parent(of pid: pid_t) -> pid_t? {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
    guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
    let ppid = info.kp_eproc.e_ppid
    return ppid > 1 ? ppid : nil
}

/// The terminal device of the nearest process above this one that has one, e.g. "/dev/ttys003".
/// The hook itself may run without one; the agent above it does.
private func terminalDevice(of chain: [Int32]) -> String? {
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
private func ancestors() -> [Int32] {
    var chain: [Int32] = []
    var pid: pid_t? = getppid()
    while let current = pid, current > 1, chain.count < 24 {
        chain.append(current)
        pid = parent(of: current)
    }
    return chain
}
