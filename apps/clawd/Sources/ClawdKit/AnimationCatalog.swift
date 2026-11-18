import Foundation
import Lottie

public struct ClawdAnimation: Sendable {
    public let name: String
    public let animation: LottieAnimation

    public var frameCount: Int { Int(animation.endFrame - animation.startFrame) }
}

/// The animations in a flat directory of `<name>.json` Lottie files.
///
/// Animations are parsed on demand: holding all of them in memory costs about 95MB.
public struct AnimationCatalog: Sendable {
    private let directory: URL
    /// Sorted names of every `.json` file present, whether or not it parses.
    public let names: [String]

    public var actNames: [String] { names.filter { $0 != "walking" } }

    public init(directory: URL) {
        self.directory = directory
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        names = files
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    /// Nil if there is no such animation or its file is not valid Lottie JSON.
    public func load(_ name: String) -> ClawdAnimation? {
        guard names.contains(name),
              let data = try? Data(contentsOf: directory.appendingPathComponent("\(name).json")),
              let animation = try? LottieAnimation.from(data: data)
        else { return nil }
        return ClawdAnimation(name: name, animation: animation)
    }
}
