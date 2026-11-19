import AppKit
import DesklingKit

// Renders the app icon and the menubar icon from Clawd's standing pose.
// Usage: IconTool <staged animations directory> <output directory>

/// The standing pose at the end of the walking animation.
let poseFrame: CGFloat = 26

struct Bitmap {
    let width: Int
    let height: Int
    var bytes: [UInt8]

    init(_ image: CGImage) {
        width = image.width
        height = image.height
        bytes = [UInt8](repeating: 0, count: width * height * 4)
        context(&bytes).draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }

    func context(_ data: inout [UInt8]) -> CGContext {
        CGContext(
            data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }

    /// Bounding box of everything opaque, in image pixels with the origin at the top-left.
    var opaqueBounds: CGRect {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where bytes[(y * width + x) * 4 + 3] > 127 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// Black where Clawd's body is, clear elsewhere and where his eyes are, so the shape reads as him.
    func silhouette() -> CGImage {
        var out = bytes
        for index in stride(from: 0, to: out.count, by: 4) {
            let isEye = out[index] < 60 && out[index + 1] < 60 && out[index + 2] < 60
            let alpha: UInt8 = out[index + 3] > 127 && !isEye ? 255 : 0
            out[index] = 0; out[index + 1] = 0; out[index + 2] = 0; out[index + 3] = alpha
        }
        return context(&out).makeImage()!
    }

    var image: CGImage {
        var copy = bytes
        return context(&copy).makeImage()!
    }
}

func writePNG(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

func draw(width: Int, height: Int, _ body: (CGContext) -> Void) -> CGImage {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    body(context)
    return context.makeImage()!
}

/// Clawd on a cream rounded square, following the macOS icon grid (824pt plate on a 1024pt canvas).
func appIcon(clawd: CGImage, pixels: Int) -> CGImage {
    draw(width: pixels, height: pixels) { context in
        let unit = CGFloat(pixels) / 1024
        let plate = CGRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
        let path = CGPath(roundedRect: plate, cornerWidth: 185 * unit, cornerHeight: 185 * unit, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -10 * unit), blur: 22 * unit,
                          color: CGColor(gray: 0, alpha: 0.3))
        context.setFillColor(CGColor(red: 0xfa / 255, green: 0xf9 / 255, blue: 0xf5 / 255, alpha: 1))
        context.addPath(path)
        context.fillPath()
        context.restoreGState()

        let width = 580 * unit
        let height = width * CGFloat(clawd.height) / CGFloat(clawd.width)
        context.draw(clawd, in: CGRect(x: plate.midX - width / 2, y: plate.midY - height / 2, width: width, height: height))
    }
}

/// Writes a small still of every act (its middle frame) for the website's Acts window.
/// Usage: IconTool --thumbs <staged animations directory> <output directory>
@MainActor
func writeThumbnails(animations: URL, output: URL) throws {
    let catalog = AnimationCatalog(directory: animations)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    for name in catalog.actNames {
        guard let act = catalog.load(name) else { continue }
        let middle = (CGFloat(act.frameCount - 1) / 2).rounded()
        guard let image = FrameRenderer.render(act.animation, frame: middle, pixelSize: CGSize(width: 264, height: 178))
        else { continue }
        try writePNG(image, to: output.appendingPathComponent("\(name).png"))
    }
}

/// Writes every frame of one animation as a numbered PNG, for building the README's animated GIF.
/// Usage: IconTool --frames <staged animations directory> <animation name> <output directory>
@MainActor
func writeFrames(animations: URL, name: String, output: URL) throws {
    guard let item = AnimationCatalog(directory: animations).load(name) else {
        throw CocoaError(.fileNoSuchFile)
    }
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    for frame in 0..<item.frameCount {
        guard let image = FrameRenderer.render(item.animation, frame: CGFloat(frame), pixelSize: CGSize(width: 825, height: 555))
        else { continue }
        try writePNG(image, to: output.appendingPathComponent(String(format: "frame-%03d.png", frame)))
    }
}

MainActor.assumeIsolated {
    let arguments = CommandLine.arguments
    if arguments.count == 5, arguments[1] == "--frames" {
        do {
            try writeFrames(
                animations: URL(fileURLWithPath: arguments[2]), name: arguments[3],
                output: URL(fileURLWithPath: arguments[4]))
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("IconTool: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
    if arguments.count == 4, arguments[1] == "--thumbs" {
        do {
            try writeThumbnails(animations: URL(fileURLWithPath: arguments[2]), output: URL(fileURLWithPath: arguments[3]))
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("IconTool: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
    guard arguments.count == 3 else {
        FileHandle.standardError.write(Data("usage: IconTool <animations directory> <output directory>\n".utf8))
        exit(2)
    }
    let output = URL(fileURLWithPath: arguments[2])
    guard let walking = AnimationCatalog(directory: URL(fileURLWithPath: arguments[1])).load("walking"),
          let frame = FrameRenderer.render(walking.animation, frame: poseFrame, pixelSize: CGSize(width: 2750, height: 1850))
    else {
        FileHandle.standardError.write(Data("IconTool: could not render the walking animation\n".utf8))
        exit(1)
    }
    let bitmap = Bitmap(frame)
    let bounds = bitmap.opaqueBounds
    let clawd = bitmap.image.cropping(to: bounds)!
    let silhouette = bitmap.silhouette().cropping(to: bounds)!

    do {
        let iconset = output.appendingPathComponent("AppIcon.iconset")
        try? FileManager.default.removeItem(at: iconset)
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        for points in [16, 32, 128, 256, 512] {
            try writePNG(appIcon(clawd: clawd, pixels: points), to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
            try writePNG(appIcon(clawd: clawd, pixels: points * 2), to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
        }

        // Menubar icons are about 18pt tall.
        for (scale, name) in [(1, "MenuIcon.png"), (2, "MenuIcon@2x.png")] {
            let height = 16 * scale
            let width = Int((CGFloat(height) * CGFloat(silhouette.width) / CGFloat(silhouette.height)).rounded())
            let icon = draw(width: width, height: height) {
                $0.draw(silhouette, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            try writePNG(icon, to: output.appendingPathComponent(name))
        }
        try writePNG(appIcon(clawd: clawd, pixels: 512), to: output.appendingPathComponent("icon-preview.png"))
    } catch {
        FileHandle.standardError.write(Data("IconTool: \(error.localizedDescription)\n".utf8))
        exit(1)
    }
}
