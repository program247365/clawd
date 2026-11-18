import AppKit
import SwiftUI

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}

private struct AboutLink: Identifiable {
    let label: String
    let symbol: String
    let url: String
    var id: String { label }

    static let all = [
        AboutLink(label: "Website", symbol: "globe", url: "https://clawd.kbr.sh"),
        AboutLink(label: "Source", symbol: "chevron.left.forwardslash.chevron.right", url: "https://github.com/program247365/clawd"),
        AboutLink(label: "Kevin B. Ridgway", symbol: "person", url: "https://kbr.sh?source=clawd-app"),
    ]
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 88, height: 88)
                    .padding(.bottom, 12)
                Text("Clawd").font(.system(size: 17, weight: .semibold))
                Text("Version \(AppInfo.version)")
                    .font(.system(size: 13)).monospacedDigit()
                    .foregroundStyle(.secondary).padding(.top, 4)
                Text("Clawd, on your desktop.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.init(top: 22, leading: 16, bottom: 20, trailing: 16))
            .background(group)

            Text("Links")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.init(top: 22, leading: 4, bottom: 8, trailing: 0))

            VStack(spacing: 0) {
                ForEach(Array(AboutLink.all.enumerated()), id: \.element.id) { index, link in
                    if index > 0 { Divider() }
                    LinkRow(link: link)
                }
            }
            .background(group)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 2) {
                Text("Clawd is Anthropic's character.")
                Text("This is an unofficial fan project.")
                Text("© 2026 Kevin B. Ridgway · Interweb Labs").padding(.top, 6)
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(.top, 20)
        }
        .padding(20)
        .frame(width: 340)
    }

    private var group: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

private struct LinkRow: View {
    let link: AboutLink
    @State private var hovering = false

    var body: some View {
        Button {
            if let url = URL(string: link.url) { NSWorkspace.shared.open(url) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: link.symbol).frame(width: 16).foregroundStyle(.secondary)
                Text(link.label).font(.system(size: 13))
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(hovering ? Color.primary.opacity(0.06) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// The one normal window the app has.
@MainActor
final class AboutWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: AboutView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "About Clawd"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        // Don't open with a focus ring on the first link; Tab still reaches the links.
        window?.makeFirstResponder(nil)
    }
}
