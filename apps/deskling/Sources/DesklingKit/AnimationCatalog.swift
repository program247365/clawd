import Foundation
import Lottie

public struct CharacterAnimation: Sendable {
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

    /// Everything but the walk and the character-select idle, which only the picker plays.
    public var actNames: [String] { names.filter { $0 != "walking" && $0 != "ready" } }

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
    public func load(_ name: String) -> CharacterAnimation? {
        guard names.contains(name),
              let data = try? Data(contentsOf: directory.appendingPathComponent("\(name).json")),
              let animation = try? LottieAnimation.from(data: data)
        else { return nil }
        return CharacterAnimation(name: name, animation: animation)
    }
}
