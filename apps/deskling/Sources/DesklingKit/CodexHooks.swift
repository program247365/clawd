import Foundation

/// Adds this app's hooks to Codex's `hooks.json`, or takes them out, leaving every other hook as it was.
enum CodexHooks {
    static let events = [
        "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest",
        "PreCompact", "Stop", "Interrupt", "SessionEnd",
    ]

    /// Codex's user hooks file: `$CODEX_HOME/hooks.json`, by default `~/.codex/hooks.json`.
    static var hooksFile: URL {
        let home = ProcessInfo.processInfo.environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        return home.appendingPathComponent("hooks.json")
    }

    /// `deskling-hook` inside the running app.
    static var hookPath: String {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/deskling-hook").path
    }

    /// How our handlers are recognised when updating or removing them, wherever the app lives.
    static let marker = "/Contents/Helpers/deskling-hook"

    static func command(hook: String) -> String {
        "'" + hook.replacingOccurrences(of: "'", with: "'\\''") + "' --agent codex"
    }

    enum Failure: Error, Equatable {
        /// The file exists but is not a JSON object with an optional "hooks" object; we leave it alone.
        case unreadable
    }

    /// `existing` with our handler added to each event, replacing any older one of ours (say, from an
    /// app in another folder). Nothing else changes.
    static func merged(_ existing: [String: Any], hook: String) throws -> [String: Any] {
        var root = existing
        var hooks = try hooksObject(of: root)
        for event in events {
            var groups = try stripped(hooks[event])
            var handler: [String: Any] = ["type": "command", "command": command(hook: hook), "timeout": 2]
            // In the background, so Codex never waits on him. SessionEnd always runs in the foreground.
            if event != "SessionEnd" { handler["async"] = true }
            groups.append(["hooks": [handler]])
            hooks[event] = groups
        }
        root["hooks"] = hooks
        return root
    }

    /// `existing` with every handler of ours removed, and any event or group left empty by that dropped.
    static func removed(_ existing: [String: Any]) throws -> [String: Any] {
        var root = existing
        var hooks = try hooksObject(of: root)
        for (event, value) in hooks {
            let groups = try stripped(value)
            hooks[event] = groups.isEmpty ? nil : groups
        }
        root["hooks"] = hooks
        return root
    }

    static func isConnected(_ existing: [String: Any]) -> Bool {
        guard let hooks = existing["hooks"] as? [String: Any] else { return false }
        return events.allSatisfy { event in
            ((hooks[event] as? [[String: Any]]) ?? []).contains { group in
                ((group["hooks"] as? [[String: Any]]) ?? []).contains(where: isOurs)
            }
        }
    }

    private static func hooksObject(of root: [String: Any]) throws -> [String: Any] {
        guard let value = root["hooks"] else { return [:] }
        guard let hooks = value as? [String: Any] else { throw Failure.unreadable }
        return hooks
    }

    /// An event's groups without our handlers; groups that held only ours are dropped.
    private static func stripped(_ value: Any?) throws -> [[String: Any]] {
        guard let value else { return [] }
        guard let groups = value as? [[String: Any]] else { throw Failure.unreadable }
        return groups.compactMap { group in
            guard let handlers = group["hooks"] as? [[String: Any]] else { return group }
            let kept = handlers.filter { !isOurs($0) }
            if kept.count == handlers.count { return group }
            if kept.isEmpty { return nil }
            var copy = group
            copy["hooks"] = kept
            return copy
        }
    }

    private static func isOurs(_ handler: [String: Any]) -> Bool {
        (handler["command"] as? String)?.contains(marker) ?? false
    }

    // MARK: The file

    /// Reads, transforms, and writes `file`, keeping a copy of what was there first. A missing file
    /// counts as empty; a file that is not valid JSON is left untouched.
    static func update(_ file: URL = hooksFile, _ transform: ([String: Any]) throws -> [String: Any]) throws {
        let manager = FileManager.default
        var existing: [String: Any] = [:]
        if manager.fileExists(atPath: file.path) {
            let data = try Data(contentsOf: file)
            if !data.isEmpty {
                guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                    throw Failure.unreadable
                }
                existing = object
            }
            let backup = file.appendingPathExtension("before-deskling")
            try? manager.removeItem(at: backup)
            try manager.copyItem(at: file, to: backup)
        } else {
            try manager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        let result = try transform(existing)
        let data = try JSONSerialization.data(
            withJSONObject: result, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: file, options: .atomic)
    }

    static func connected(_ file: URL = hooksFile) -> Bool {
        guard let data = try? Data(contentsOf: file),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return false }
        return isConnected(object)
    }
}
