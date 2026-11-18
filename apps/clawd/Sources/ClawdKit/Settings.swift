import Foundation

public final class Settings {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var size: ClawdSize {
        get { defaults.string(forKey: "size").flatMap(ClawdSize.init(rawValue:)) ?? .medium }
        set { defaults.set(newValue.rawValue, forKey: "size") }
    }
}
