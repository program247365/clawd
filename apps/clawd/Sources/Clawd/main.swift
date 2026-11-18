import AppKit
import ClawdKit

// Temporary harness for the window; replaced by the real app wiring in Task 6.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let catalog = AnimationCatalog(directory: URL(fileURLWithPath: ProcessInfo.processInfo.environment["CLAWD_ANIMATIONS"] ?? ""))
    let window = ClawdWindow(size: ClawdSize.large.size)
    let screen = NSScreen.screens[0].frame
    window.origin = CGPoint(x: 200, y: screen.height - 400)
    window.facing = CommandLine.arguments.contains("--left") ? .left : .right
    window.show()
    if let walking = catalog.walking { window.loopWalk(walking) }
    app.run()
}
