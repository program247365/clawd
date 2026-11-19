import AppKit
import DesklingEvents

/// The app a waiting agent runs in: the terminal or editor you would switch to to answer it,
/// and in Warp and Terminal, the very tab.
enum AgentApp {
    static let terminalID = "com.apple.Terminal"

    /// Brings up where the agent is waiting. False if there is nowhere to go.
    @MainActor
    static func goTo(_ origin: AgentEvent.Origin?) -> Bool {
        guard let origin else { return false }
        if let session = warpSession(origin.focusURL) {
            NSWorkspace.shared.open(session)
            return true
        }
        guard let app = find(origin) else { return false }
        if Bundle(url: app)?.bundleIdentifier == terminalID, let script = terminalScript(tty: origin.tty) {
            // Through osascript, so the first time's permission prompt never holds up the character.
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            process.terminationHandler = { process in
                // Not allowed to control Terminal, or the tab has closed: the app will have to do.
                if process.terminationStatus != 0 { Task { @MainActor in bringForward(app) } }
            }
            do { try process.run() } catch { bringForward(app) }
            return true
        }
        bringForward(app)
        return true
    }

    /// Warp's link to one session, and nothing else: any process on the Mac can post these events,
    /// so a click must never open an arbitrary URL.
    static func warpSession(_ string: String?) -> URL? {
        guard let string, string.hasPrefix("warp://session/") else { return nil }
        let id = string.dropFirst("warp://session/".count)
        guard !id.isEmpty, id.count <= 64, id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }), id.allSatisfy(\.isASCII)
        else { return nil }
        return URL(string: string)
    }

    /// AppleScript that selects Terminal's tab on `tty` and brings its window to the front.
    /// Only a plain /dev/ttysNNN is ever put into the script.
    static func terminalScript(tty: String?) -> String? {
        guard let tty, tty.hasPrefix("/dev/ttys"), tty.count > 9, tty.dropFirst(9).allSatisfy(\.isASCII),
              tty.dropFirst(9).allSatisfy(\.isNumber)
        else { return nil }
        return """
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    if tty of t is "\(tty)" then
                        set selected of t to true
                        set index of w to 1
                        activate
                        return
                    end if
                end repeat
            end repeat
            error "no tab on \(tty)"
        end tell
        """
    }

    /// The nearest process above the hook that is an app with a Dock icon, or failing that, the app
    /// the agent's shell was started from.
    @MainActor
    static func find(_ origin: AgentEvent.Origin) -> URL? {
        for pid in origin.processes {
            if let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular {
                return app.bundleURL
            }
        }
        return origin.bundleID.flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0).first?.bundleURL }
    }

    /// Brings it forward the way `open -a` does, which macOS allows from an app that is not frontmost.
    static func bringForward(_ url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error { NSLog("Deskling: could not bring up \(url.lastPathComponent): \(error.localizedDescription)") }
        }
    }
}
