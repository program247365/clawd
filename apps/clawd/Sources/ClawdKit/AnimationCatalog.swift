import Foundation
import Lottie

public struct ClawdAnimation {
    public let name: String
    public let animation: LottieAnimation

    public var frameCount: Int { Int(animation.endFrame - animation.startFrame) }
}

/// Every animation in a flat directory of `<name>.json` Lottie files.
public struct AnimationCatalog {
    public let all: [ClawdAnimation]

    public var walking: ClawdAnimation? { all.first { $0.name == "walking" } }
    public var acts: [ClawdAnimation] { all.filter { $0.name != "walking" } }

    /// Files that are unreadable or are not valid Lottie JSON are skipped.
    public init(directory: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        all = files
            .filter { $0.pathExtension == "json" }
            .compactMap { file -> ClawdAnimation? in
                guard let data = try? Data(contentsOf: file),
                      let animation = try? LottieAnimation.from(data: data)
                else { return nil }
                return ClawdAnimation(name: file.deletingPathExtension().lastPathComponent, animation: animation)
            }
            .sorted { $0.name < $1.name }
    }
}
