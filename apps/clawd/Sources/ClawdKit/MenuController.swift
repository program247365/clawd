import AppKit
import ServiceManagement

/// The menubar item: the whole UI apart from About.
@MainActor
final class MenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let performer: Performer
    private let settings: Settings
    private let about = AboutWindowController()
    private let visibilityItem = NSMenuItem(title: "", action: #selector(toggleVisibility), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private var sizeItems: [ClawdSize: NSMenuItem] = [:]

    init(performer: Performer, settings: Settings) {
        self.performer = performer
        self.settings = settings
        super.init()

        if let icon = Bundle.main.image(forResource: "MenuIcon") {
            icon.isTemplate = true
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "Clawd"
        }
        statusItem.button?.setAccessibilityLabel("Clawd")

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(visibilityItem)

        let sizeMenu = NSMenu()
        for size in ClawdSize.allCases {
            let item = NSMenuItem(title: size.rawValue.capitalized, action: #selector(chooseSize(_:)), keyEquivalent: "")
            item.representedObject = size.rawValue
            sizeItems[size] = item
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "About Clawd (v\(AppInfo.version))", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit Clawd", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items + sizeMenu.items where item.action != nil { item.target = self }
        statusItem.menu = menu
    }

    /// Titles and check marks are read from the real state each time the menu opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        visibilityItem.title = performer.isRunning ? "Hide Clawd" : "Show Clawd"
        for (size, item) in sizeItems { item.state = size == settings.size ? .on : .off }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleVisibility() {
        if performer.isRunning { performer.stop() } else { performer.start() }
    }

    @objc private func chooseSize(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String, let size = ClawdSize(rawValue: raw) else { return }
        settings.size = size
        performer.refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            // The check mark is read from the service's real state, so a failure simply leaves it unchanged.
            NSLog("Clawd: could not change Launch at Login: \(error.localizedDescription)")
        }
    }

    @objc private func showAbout() { about.show() }

    @objc private func quit() { NSApp.terminate(nil) }
}
