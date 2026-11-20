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

    /// The site's About window lists the same links, apart from the site itself.
    static let all = [
        AboutLink(label: "Website", symbol: "globe", url: "https://deskling.kbr.sh"),
        AboutLink(label: "Source on GitHub", symbol: "chevron.left.forwardslash.chevron.right", url: "https://github.com/program247365/deskling"),
        AboutLink(label: "Connect Claude Code or Codex", symbol: "terminal", url: "https://github.com/program247365/deskling#claude-code-and-codex"),
        AboutLink(label: "Let your agents speak", symbol: "text.bubble", url: "https://github.com/program247365/deskling#letting-agents-speak"),
        AboutLink(label: "Release notes", symbol: "doc.text", url: "https://github.com/program247365/deskling/releases/latest"),
        AboutLink(label: "by Kevin B. Ridgway", symbol: "person", url: "https://kbr.sh?source=deskling-app"),
    ]
}

/// The cast in a row under a stage light that visits each in turn; whoever it lands on waves.
private struct AboutCast: View {
    let characters: [Character]
    @State private var stands: [String: CGImage] = [:]
    @State private var waves: [String: [CGImage]] = [:]
    @State private var lit = 0
    @State private var waveStart: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 2pt per art pixel, as on the site. Neighbours overlap a little, only where their canvases are empty.
    private static let sprite = CGSize(width: 55, height: 37)
    private static let spacing: CGFloat = -2
    private static let fps = 12.0
    private static let wavesEach = 2

    var body: some View {
        ZStack(alignment: .bottom) {
            StageLight()
                .frame(width: Self.sprite.width, height: 64)
                .offset(x: (CGFloat(lit) - CGFloat(characters.count - 1) / 2) * (Self.sprite.width + Self.spacing))
            TimelineView(.animation(minimumInterval: 1 / Self.fps, paused: waveStart == nil)) { timeline in
                HStack(spacing: Self.spacing) {
                    ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                        sprite(for: character, waving: index == lit, now: timeline.date)
                            .frame(width: Self.sprite.width, height: Self.sprite.height)
                            .accessibilityLabel(character.name)
                    }
                }
            }
        }
        .frame(height: 64)
        .accessibilityElement(children: .combine)
        .task { await perform() }
    }

    @ViewBuilder
    private func sprite(for character: Character, waving: Bool, now: Date) -> some View {
        let frames = waves[character.id] ?? []
        let image: CGImage? = {
            guard waving, let waveStart, !frames.isEmpty else { return stands[character.id] }
            let index = Int(now.timeIntervalSince(waveStart) * Self.fps)
            return frames[index % frames.count]
        }()
        if let image {
            Image(decorative: image, scale: 2).interpolation(.none).resizable()
        } else {
            Color.clear
        }
    }

    /// Renders everyone, then walks the light along the row for as long as the window is open.
    private func perform() async {
        for character in characters {
            stands[character.id] = SelectFrames.stand(for: character)
            waves[character.id] = SelectFrames.wave(for: character)
            await Task.yield()
        }
        while !Task.isCancelled {
            for index in characters.indices {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) { lit = index }
                try? await Task.sleep(for: .seconds(0.55))
                let frames = waves[characters[index].id]?.count ?? 0
                waveStart = Date()
                try? await Task.sleep(for: .seconds(Double(frames * Self.wavesEach) / Self.fps))
                waveStart = nil
                try? await Task.sleep(for: .seconds(0.35))
                if Task.isCancelled { return }
            }
        }
    }
}

/// A warm cone from above with a pool of light at the feet; visible on a light or a dark card.
private struct StageLight: View {
    private let warm = Color(red: 1, green: 0.78, blue: 0.42)

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { proxy in
                let w = proxy.size.width, h = proxy.size.height
                Path { path in
                    path.move(to: CGPoint(x: w * 0.4, y: 0))
                    path.addLine(to: CGPoint(x: w * 0.6, y: 0))
                    path.addLine(to: CGPoint(x: w * 0.92, y: h - 3))
                    path.addLine(to: CGPoint(x: w * 0.08, y: h - 3))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [warm.opacity(0), warm.opacity(0.38)], startPoint: .top, endPoint: .bottom))
            }
            Ellipse().fill(warm.opacity(0.5)).frame(width: 44, height: 7)
        }
        .accessibilityHidden(true)
    }
}

private struct AboutView: View {
    let characters: [Character]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 88, height: 88)
                    .padding(.bottom, 12)
                Text("Deskling").font(.system(size: 17, weight: .semibold))
                Text("Version \(AppInfo.version)")
                    .font(.system(size: 13)).monospacedDigit()
                    .foregroundStyle(.secondary).padding(.top, 4)
                Text("Little pixel friends for your desktop.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 8)
                AboutCast(characters: characters)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.init(top: 22, leading: 16, bottom: 20, trailing: 16))
            .background(group)

            VStack(spacing: 0) {
                ForEach(Array(AboutLink.all.enumerated()), id: \.element.id) { index, link in
                    if index > 0 { Divider() }
                    LinkRow(link: link)
                }
            }
            .background(group)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.top, 22)

            VStack(spacing: 2) {
                Text("Clawd is Anthropic's character.")
                Text("This is an unofficial fan project.")
                Text("© 2026 Kevin B. Ridgway").padding(.top, 6)
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
final class AboutWindowController: NSObject, NSWindowDelegate {
    private let characters: [Character]
    private var window: NSWindow?

    init(characters: [Character]) {
        self.characters = characters
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: AboutView(characters: characters))
            let window = NSWindow(contentViewController: hosting)
            window.title = "About Deskling"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        // Don't open with a focus ring on the first link; Tab still reaches the links.
        window?.makeFirstResponder(nil)
    }

    /// Dropped on close so the light stops going round; the next show starts it again from Clawd.
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
