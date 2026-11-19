import AppKit
import Lottie

public enum FrameRenderer {
    /// The engine the app ships with. Tests render through the same one.
    public static let configuration = LottieConfiguration(renderingEngine: .mainThread)

    /// Renders one frame on a transparent background.
    @MainActor
    public static func render(_ animation: LottieAnimation, frame: CGFloat, pixelSize: CGSize) -> CGImage? {
        let view = LottieAnimationView(animation: animation, configuration: configuration)
        view.frame = CGRect(origin: .zero, size: pixelSize)
        view.wantsLayer = true
        view.contentMode = .scaleAspectFit
        view.currentFrame = frame
        view.layoutSubtreeIfNeeded()
        view.forceDisplayUpdate()

        guard let layer = view.layer,
              let context = CGContext(
                  data: nil, width: Int(pixelSize.width), height: Int(pixelSize.height),
                  bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        // The view is flipped (origin top-left); a bitmap context is not.
        context.translateBy(x: 0, y: pixelSize.height)
        context.scaleBy(x: 1, y: -1)
        layer.render(in: context)
        return context.makeImage()
    }

    /// How far up `image` the drawing reaches, as a fraction of its height from the bottom: where the
    /// top of a character's head is. Nil for a blank image.
    public static func drawnTop(of image: CGImage) -> CGFloat? {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        // Row 0 of the bytes is the top of the image.
        for row in 0..<height {
            for column in 0..<width where bytes[(row * width + column) * 4 + 3] > 127 {
                return CGFloat(height - row) / CGFloat(height)
            }
        }
        return nil
    }
}
