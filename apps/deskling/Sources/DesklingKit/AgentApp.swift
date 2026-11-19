import AppKit
import DesklingEvents

/// The app a waiting agent runs in: the terminal or editor you would switch to to answer it.
enum AgentApp {
    /// The nearest process above the hook that is an app with a Dock icon, or failing that, the app
    /// the agent's shell was started from.
    @MainActor
    static func find(_ origin: AgentEvent.Origin?) -> URL? {
        guard let origin else { return nil }
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
