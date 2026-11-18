import Foundation

public final class Settings {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Whether he may teleport around the screen. Off by default: he stays at the bottom.
    public var roams: Bool {
        get { defaults.bool(forKey: Self.roamsKey) }
        set { defaults.set(newValue, forKey: Self.roamsKey) }
    }

    /// The Settings window binds to this key directly.
    public static let roamsKey = "roams"

    public var size: ClawdSize {
        get { defaults.string(forKey: "size").flatMap(ClawdSize.init(rawValue:)) ?? .medium }
        set { defaults.set(newValue.rawValue, forKey: "size") }
    }
}
