import AppKit
import SwiftUI

private struct SettingsView: View {
    @AppStorage(Settings.roamsKey) private var roams = false
    @AppStorage(Settings.visitsLockScreenKey) private var visitsLockScreen = false
    @AppStorage(Settings.reactsToAgentsKey) private var reactsToAgents = true
    @AppStorage(Settings.alertsForAgentsKey) private var alertsForAgents = true
    @State private var codexConnected = CodexHooks.connected()
    @State private var codexMessage: String?

    private func toggleCodex() {
        do {
            if codexConnected {
                try CodexHooks.update { try CodexHooks.removed($0) }
            } else {
                try CodexHooks.update { try CodexHooks.merged($0, hook: CodexHooks.hookPath) }
            }
            codexMessage = nil
        } catch CodexHooks.Failure.unreadable {
            codexMessage = "~/.codex/hooks.json isn't valid JSON, so I left it alone. Fix it in Codex, then try again."
        } catch {
            codexMessage = "Couldn't update ~/.codex/hooks.json: \(error.localizedDescription)"
        }
        codexConnected = CodexHooks.connected()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Where your Deskling wanders").font(.system(size: 13, weight: .semibold))

            Picker("Where your Deskling wanders", selection: $roams) {
                Text("Keep them at the bottom of the screen").tag(false)
                Text("Let them roam!").tag(true)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            Text(roams
                ? "Now and then they'll pop up somewhere unexpected, do their thing, and pop back down. They mean well."
                : "They keep to the floor, patrolling back and forth, well out of your way.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().padding(.vertical, 4)

            Toggle("Bring them along to the lock screen", isOn: $visitsLockScreen)
                .disabled(!LockScreenVisitor.isSupported)

            Text(LockScreenVisitor.isSupported
                ? "When your Mac locks, they sneak onto the lock screen and keep watch until you're back. This uses a trick macOS doesn't officially offer, so a future update could send them home."
                : "This version of macOS doesn't leave them a way in.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().padding(.vertical, 4)

            Text("Coding agents").font(.system(size: 13, weight: .semibold))
            Toggle("Act out what Claude Code and Codex are doing", isOn: $reactsToAgents)
            Toggle("Come and tell me when an agent needs me", isOn: $alertsForAgents)

            Text("In Claude Code, run:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("/plugin install clawd --marketplace program247365/clawd")
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
            HStack(alignment: .firstTextBaseline) {
                Text(codexConnected
                    ? "Connected to Codex. If Codex hasn't asked yet, trust the new hooks with /hooks."
                    : "Codex: adds Deskling's hooks to ~/.codex/hooks.json. Your other hooks stay as they are, and the old file is kept as hooks.json.before-deskling.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(codexConnected ? "Disconnect Codex" : "Connect Codex") { toggleCodex() }
            }
            if let codexMessage {
                Text(codexMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
            window.title = "Deskling Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
