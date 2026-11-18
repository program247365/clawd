import AppKit
import ClawdKit

// Temporary harness for the window; replaced by the real app wiring in Task 6.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let catalog = AnimationCatalog(directory: URL(fileURLWithPath: ProcessInfo.processInfo.environment["CLAWD_ANIMATIONS"] ?? ""))
    let window = ClawdWindow(size: ClawdSize.medium.size)
    let performer = Performer(catalog: catalog, window: window, settings: Settings())
    performer.start()
    app.run()
}
