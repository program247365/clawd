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
}
