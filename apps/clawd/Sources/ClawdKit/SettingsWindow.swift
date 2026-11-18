import AppKit
import SwiftUI

private struct SettingsView: View {
    @AppStorage(Settings.roamsKey) private var roams = false
    @AppStorage(Settings.visitsLockScreenKey) private var visitsLockScreen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Where Clawd wanders").font(.system(size: 13, weight: .semibold))

            Picker("Where Clawd wanders", selection: $roams) {
                Text("Have Clawd stay at the bottom of the screen").tag(false)
                Text("Let Clawd roam!").tag(true)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            Text(roams
                ? "Now and then he'll pop up somewhere unexpected, do his thing, and pop back down. He means well."
                : "He keeps to the floor, patrolling back and forth, well out of your way.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().padding(.vertical, 4)

            Toggle("Make Clawd visit your lock screen", isOn: $visitsLockScreen)
                .disabled(!LockScreenVisitor.isSupported)

            Text(LockScreenVisitor.isSupported
                ? "When your Mac locks, he sneaks onto the lock screen and keeps watch until you're back. This uses a trick macOS doesn't officially offer, so a future update could send him home."
                : "This version of macOS doesn't leave him a way in.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(width: 380, alignment: .leading)
    }
}

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "Clawd Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
