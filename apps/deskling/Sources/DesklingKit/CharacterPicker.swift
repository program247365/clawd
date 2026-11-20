import AppKit
import SwiftUI

/// Pre-rendered frames for the select screen, drawn with nearest-neighbor scaling so pixels stay square.
@MainActor
enum SelectFrames {
    /// Rendered pixels per art pixel (100 Lottie units). At 2x that is 4pt per art pixel on screen.
    static let pixelsPerArtPixel = 8
    static let renderSize = CGSize(width: 220, height: 148)

    /// The character-select idle: the character's own `ready` animation if it has one, otherwise their
    /// standing pose bounced through a crouch and a lean by shifting whole rows of pixels.
    static func ready(for character: Character) -> [CGImage] {
        let catalog = character.catalog
        if let ready = catalog.load("ready") { return frames(of: ready) }
        guard let still = stand(for: character) else { return [] }
        return idle(from: still)
    }

    static func stand(for character: Character) -> CGImage? {
        guard let walking = character.catalog.load("walking") else { return nil }
        return FrameRenderer.render(walking.animation, frame: character.standingFrame, pixelSize: renderSize)
    }

    static func wave(for character: Character) -> [CGImage] {
        character.catalog.load("waving").map(frames(of:)) ?? []
    }

    private static func frames(of item: CharacterAnimation) -> [CGImage] {
        (0..<item.frameCount).compactMap {
            FrameRenderer.render(item.animation, frame: CGFloat($0), pixelSize: renderSize)
        }
    }

    /// Crouch (rows), lean (columns) for each frame of the generated idle.
    static let idleSteps: [(crouch: Int, lean: Int)] = [(0, 0), (1, 0), (1, 1), (1, 1), (1, 0), (0, 0), (0, -1), (0, -1)]

    /// Splits the figure a little below its middle and moves the top part: down a row to crouch,
    /// sideways a column to lean. The bottom part (feet) stays planted.
    static func idle(from image: CGImage) -> [CGImage] {
        let width = image.width, height = image.height
        let step = pixelsPerArtPixel
        let (top, bottom) = opaqueRows(of: image)
        guard bottom > top else { return [image] }
        let split = (top + (bottom - top) * 55 / 100) / step * step
        guard let upper = image.cropping(to: CGRect(x: 0, y: 0, width: width, height: split)),
              let lower = image.cropping(to: CGRect(x: 0, y: split, width: width, height: height - split))
        else { return [image] }
        return idleSteps.compactMap { crouch, lean in
            guard let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return nil }
            context.interpolationQuality = .none
            // CoreGraphics is y-up: the lower part sits at the bottom, the upper part above it.
            context.draw(lower, in: CGRect(x: 0, y: 0, width: width, height: height - split))
            context.draw(upper, in: CGRect(x: lean * step, y: height - split - crouch * step, width: width, height: split))
            return context.makeImage()
        }
    }

    /// First and last rows (top-down) with any opaque pixel.
    private static func opaqueRows(of image: CGImage) -> (Int, Int) {
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return (0, height) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var first = height, last = 0
        for row in 0..<height {
            // The bitmap's first row in memory is the top of the image.
            let start = row * width * 4
            if stride(from: start + 3, to: start + width * 4, by: 4).contains(where: { data[$0] > 127 }) {
                first = min(first, row)
                last = row
            }
        }
        return (first, last + 1)
    }
}

private enum SelectPalette {
    static let night = Color(red: 0x16 / 255, green: 0x14 / 255, blue: 0x1c / 255)
    static let floor = Color(red: 0x24 / 255, green: 0x20 / 255, blue: 0x2e / 255)
    static let floorEdge = Color(red: 0x3a / 255, green: 0x34 / 255, blue: 0x46 / 255)
    static let cream = Color(red: 0xfa / 255, green: 0xf9 / 255, blue: 0xf5 / 255)
    static let orange = Color(red: 0xd9 / 255, green: 0x77 / 255, blue: 0x57 / 255)
    static let orangeDeep = Color(red: 0xb0 / 255, green: 0x5a / 255, blue: 0x3e / 255)
    static let spriteSize = CGSize(width: 110, height: 74)
    static let slotWidth: CGFloat = 124
}

/// The stage light over the selected character: a pale cone from above, the same light he enters under.
private struct Spotlight: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            Path { path in
                path.move(to: CGPoint(x: w * 0.38, y: 0))
                path.addLine(to: CGPoint(x: w * 0.62, y: 0))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.closeSubpath()
            }
            .fill(LinearGradient(
                colors: [SelectPalette.cream.opacity(0.04), SelectPalette.cream.opacity(0.16)], startPoint: .top, endPoint: .bottom))
        }
    }
}

/// A small down-pointing pixel arrow under the "P1" tag.
private struct PixelArrow: View {
    var body: some View {
        Canvas { context, _ in
            var path = Path()
            for (row, width) in [5, 3, 1].enumerated() {
                path.addRect(CGRect(x: CGFloat(5 - width) / 2 * 3, y: CGFloat(row) * 3, width: CGFloat(width) * 3, height: 3))
            }
            context.fill(path, with: .color(SelectPalette.orange))
        }
        .frame(width: 15, height: 9)
    }
}

struct SelectScreen: View {
    let characters: [Character]
    let welcome: Bool
    @State var selected: Int
    let choose: (Character) -> Void
    /// Frames already rendered, by character; the rest are rendered when the screen appears.
    @State var idle: [String: [CGImage]] = [:]
    @State private var waving: [CGImage] = []
    @State private var confirmedAt: Date?
    @State private var hovered: Int?
    @FocusState private var focused: Bool

    private let fps = 10.0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1 / fps)) { timeline in
            let tick = Int(timeline.date.timeIntervalSinceReferenceDate * fps)
            VStack(spacing: 0) {
                PixelText(text: welcome ? "CHOOSE YOUR CHARACTER" : "CHOOSE A CHARACTER", scale: 3, color: SelectPalette.cream)
                    .padding(.top, 34)

                lineup(tick: tick, now: timeline.date)
                    .padding(.top, 18)

                nameplate
                    .padding(.top, 22)

                Spacer(minLength: 16)
                footer(tick: tick)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: max(640, CGFloat(characters.count) * SelectPalette.slotWidth + 80), height: 430)
        .background(SelectPalette.night)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(.leftArrow) { move(-1) }
        .onKeyPress(.rightArrow) { move(1) }
        .onKeyPress(.return) { confirm(); return .handled }
        .onKeyPress(.space) { confirm(); return .handled }
        .task {
            // Rendered one character at a time so the window paints straight away.
            for character in characters where idle[character.id] == nil {
                idle[character.id] = SelectFrames.ready(for: character)
                await Task.yield()
            }
        }
    }

    private func lineup(tick: Int, now: Date) -> some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Spacer()
                Rectangle().fill(SelectPalette.floorEdge).frame(height: 2)
                Rectangle().fill(SelectPalette.floor).frame(height: 26)
            }
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                    slot(index: index, character: character, tick: tick, now: now)
                }
            }
            .padding(.bottom, 16)
        }
        .frame(height: 200)
    }

    private func slot(index: Int, character: Character, tick: Int, now: Date) -> some View {
        let isSelected = index == selected
        let confirmed = confirmedAt != nil
        let frames = (isSelected && confirmed && !waving.isEmpty) ? waving : (idle[character.id] ?? [])
        // Each idle starts on its own beat so the lineup does not bounce in lockstep.
        let frameIndex: Int = {
            guard !frames.isEmpty else { return 0 }
            if isSelected, confirmed, let confirmedAt, !waving.isEmpty {
                return min(Int(now.timeIntervalSince(confirmedAt) * 12), frames.count - 1)
            }
            return (tick + index * 3) % frames.count
        }()
        return ZStack(alignment: .bottom) {
            if isSelected {
                Spotlight()
                    .frame(width: SelectPalette.slotWidth, height: 190)
                    .transition(.opacity)
            }
            VStack(spacing: 4) {
                VStack(spacing: 3) {
                    PixelText(text: "P1", scale: 2, color: SelectPalette.orange)
                    PixelArrow()
                }
                // A two-point bob in time with the idle.
                .offset(y: (tick / 3) % 2 == 0 ? 0 : 2)
                .opacity(isSelected ? 1 : 0)

                Group {
                    if frames.indices.contains(frameIndex) {
                        Image(decorative: frames[frameIndex], scale: 2)
                            .interpolation(.none)
                            .resizable()
                    } else {
                        Color.clear
                    }
                }
                .frame(width: SelectPalette.spriteSize.width, height: SelectPalette.spriteSize.height)
            }
            .opacity(isSelected ? 1 : (confirmed ? 0.15 : (hovered == index ? 0.9 : 0.72)))
            .saturation(isSelected || hovered == index ? 1 : 0.7)
        }
        .frame(width: SelectPalette.slotWidth, height: 190, alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { selected = index; confirm() }
        .onTapGesture { select(index) }
        .onHover { hovered = $0 ? index : (hovered == index ? nil : hovered) }
        .animation(.easeOut(duration: 0.18), value: selected)
        .animation(.easeOut(duration: 0.4), value: confirmedAt)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(character.name)
        .accessibilityHint(character.blurb)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { select(index) }
    }

    private var nameplate: some View {
        let character = characters[selected]
        return VStack(spacing: 10) {
            PixelText(text: character.name.uppercased(), scale: 5, color: SelectPalette.cream)
            Text(character.blurb)
                .font(.system(size: 13))
                .foregroundStyle(SelectPalette.cream.opacity(0.72))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .id(character.id)
        .transition(.opacity)
    }

    private func footer(tick: Int) -> some View {
        HStack(spacing: 22) {
            PixelText(text: "< >  CHOOSE", scale: 2, color: SelectPalette.cream.opacity(0.6))
            Button(action: confirm) {
                PixelText(text: welcome ? "DROP THEM IN!" : "PICK!", scale: 2, color: SelectPalette.cream)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        VStack(spacing: 0) {
                            SelectPalette.orange
                            SelectPalette.orangeDeep.frame(height: 3)
                        })
            }
            .buttonStyle(PixelButtonStyle())
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel(welcome ? "Drop them in" : "Pick")
            PixelText(text: "ENTER", scale: 2, color: SelectPalette.cream.opacity((tick / 5) % 2 == 0 ? 0.6 : 0.3))
        }
    }

    private func select(_ index: Int) {
        guard confirmedAt == nil else { return }
        selected = index
    }

    private func move(_ delta: Int) -> KeyPress.Result {
        select((selected + delta + characters.count) % characters.count)
        return .handled
    }

    /// The one authored moment: the pick waves, everyone else steps back, then the window closes.
    private func confirm() {
        guard confirmedAt == nil else { return }
        let character = characters[selected]
        waving = SelectFrames.wave(for: character)
        confirmedAt = Date()
        let duration = max(0.8, Double(waving.count) / 12 + 0.25)
        Task {
            try? await Task.sleep(for: .seconds(duration))
            choose(character)
        }
    }
}

/// Presses sink by a pixel; hovering brightens.
private struct PixelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PixelButton(configuration: configuration)
    }

    private struct PixelButton: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .brightness(hovering ? 0.06 : 0)
                .offset(y: configuration.isPressed ? 2 : 0)
                .onHover { hovering = $0 }
        }
    }
}

@MainActor
final class CharacterPickerWindowController: NSObject, NSWindowDelegate {
    private let roster: Roster
    private let settings: Settings
    private let didChoose: (Character) -> Void
    private var window: NSWindow?
    /// Runs once when the welcome picker is dismissed, chosen or closed.
    private var afterWelcome: (() -> Void)?

    init(roster: Roster, settings: Settings, didChoose: @escaping (Character) -> Void) {
        self.roster = roster
        self.settings = settings
        self.didChoose = didChoose
    }

    func showWelcome(then: @escaping () -> Void) {
        afterWelcome = then
        present(welcome: true)
    }

    func show() {
        present(welcome: false)
    }

    /// Chooses without the window, as from the menu.
    func choose(_ character: Character) {
        settings.characterID = character.id
        didChoose(character)
    }

    private func present(welcome: Bool) {
        window?.close()
        let characters = roster.characters
        let current = roster.character(id: settings.characterID).id
        let view = SelectScreen(
            characters: characters, welcome: welcome,
            selected: characters.firstIndex { $0.id == current } ?? 0
        ) { [weak self] character in
            self?.choose(character)
            self?.window?.close()
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = welcome ? "Welcome" : "Characters"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(srgbRed: 0x16 / 255, green: 0x14 / 255, blue: 0x1c / 255, alpha: 1)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        let then = afterWelcome
        afterWelcome = nil
        // Closing the welcome window without choosing keeps whoever was selected before: Clawd.
        DispatchQueue.main.async { then?() }
    }
}
