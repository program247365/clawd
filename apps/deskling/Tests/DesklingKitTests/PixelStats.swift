import CoreGraphics

/// Reads a CGImage into RGBA bytes for simple assertions about what was drawn.
struct PixelStats {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    /// Clawd's body fills: the `orange` and `dark_orange` layer colors across all animations.
    static let bodyColors: [(Int, Int, Int)] = [(217, 119, 87), (216, 118, 86), (190, 104, 77), (191, 105, 77)]

    init(_ image: CGImage) {
        width = image.width
        height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        bytes = data
    }

    /// Row 0 is the top of the image.
    func alpha(x: Int, y: Int) -> UInt8 { bytes[(y * width + x) * 4 + 3] }

    var opaqueFraction: Double {
        var opaque = 0
        for index in stride(from: 3, to: bytes.count, by: 4) where bytes[index] > 127 { opaque += 1 }
        return Double(opaque) / Double(width * height)
    }

    var containsBodyColor: Bool {
        var matches = 0
        for index in stride(from: 0, to: bytes.count, by: 4) where bytes[index + 3] > 250 {
            let (r, g, b) = (Int(bytes[index]), Int(bytes[index + 1]), Int(bytes[index + 2]))
            if Self.bodyColors.contains(where: { abs($0.0 - r) <= 12 && abs($0.1 - g) <= 12 && abs($0.2 - b) <= 12 }) {
                matches += 1
                if matches >= 50 { return true }
            }
        }
        return false
    }

    /// Mean row of near-black opaque pixels (Clawd's eyes), or nil if there are none.
    var meanDarkRow: Double? {
        var total = 0, count = 0
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                if bytes[index + 3] > 250, bytes[index] < 40, bytes[index + 1] < 40, bytes[index + 2] < 40 {
                    total += y; count += 1
                }
            }
        }
        return count == 0 ? nil : Double(total) / Double(count)
    }

    /// The highest row (smallest y) containing a mostly-opaque pixel.
    var highestOpaqueRow: Int? {
        for y in 0..<height {
            for x in 0..<width where alpha(x: x, y: y) > 127 { return y }
        }
        return nil
    }

    /// The lowest row (largest y) containing a mostly-opaque pixel, or nil if the image is empty.
    var lowestOpaqueRow: Int? {
        for y in stride(from: height - 1, through: 0, by: -1) {
            for x in 0..<width where alpha(x: x, y: y) > 127 { return y }
        }
        return nil
    }
}
