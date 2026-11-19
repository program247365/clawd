import SwiftUI

/// A 5 x 7 bitmap face, drawn to match the characters' pixels, for the character-select lettering.
enum PixelFont {
    static let glyphWidth = 5
    static let glyphHeight = 7

    /// Width of `text` in font pixels: each glyph plus one pixel of space.
    static func width(of text: String) -> Int {
        max(0, text.count * (glyphWidth + 1) - 1)
    }

    /// Draws `text` with its top-left at `origin`, each font pixel `scale` points square.
    static func draw(_ text: String, at origin: CGPoint, scale: CGFloat, color: Color, in context: GraphicsContext) {
        var path = Path()
        for (index, character) in text.uppercased().enumerated() {
            guard let rows = glyphs[character] else { continue }
            let left = origin.x + CGFloat(index * (glyphWidth + 1)) * scale
            for (y, row) in rows.enumerated() {
                for (x, bit) in row.enumerated() where bit == "#" {
                    path.addRect(CGRect(x: left + CGFloat(x) * scale, y: origin.y + CGFloat(y) * scale, width: scale, height: scale))
                }
            }
        }
        context.fill(path, with: .color(color))
    }

    private static let glyphs: [Swift.Character: [String]] = [
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
        "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
        "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
        "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
        "<": ["...#.", "..#..", ".#...", "#....", ".#...", "..#..", "...#."],
        ">": [".#...", "..#..", "...#.", "....#", "...#.", "..#..", ".#..."],
        " ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
    ]
}

/// Pixel lettering as a view, sized to its text.
struct PixelText: View {
    let text: String
    var scale: CGFloat = 3
    var color: Color

    var body: some View {
        Canvas { context, _ in
            PixelFont.draw(text, at: .zero, scale: scale, color: color, in: context)
        }
        .frame(width: CGFloat(PixelFont.width(of: text)) * scale, height: CGFloat(PixelFont.glyphHeight) * scale)
        .accessibilityLabel(text.capitalized)
    }
}
