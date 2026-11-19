import Foundation

/// The jobs a character's acts can be asked to do when a coding agent does something.
public enum Role: String, CaseIterable, Sendable {
    /// Thinking over a new prompt.
    case think
    /// Running a shell command.
    case type
    /// Editing files.
    case write
    /// Reading the web.
    case browse
    /// Searching or reading code.
    case search
    /// Handing work to a subagent.
    case delegate
    /// Compacting the conversation.
    case compact
    /// The agent finished.
    case celebrate
}

/// Someone who can live on the desktop: a folder of animations plus how to walk with them.
public struct Character: @unchecked Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let blurb: String
    public let directory: URL
    /// The looping step frames inside `walking`.
    public let walkCycle: ClosedRange<CGFloat>
    /// The frame of `walking` he stands still in.
    public let standingFrame: CGFloat
    /// The frame of `looking` with his eyes turned up, for when the cursor is above him.
    public let lookUpFrame: CGFloat
    /// Act names that can play each role, best first. A role with no act is simply not performed.
    public let roles: [Role: [String]]
    /// Colors punched out of the menubar silhouette (the eyes), as RGB.
    public let iconHoles: [(Int, Int, Int)]

    public static func == (a: Character, b: Character) -> Bool {
        a.id == b.id && a.directory == b.directory
    }

    /// Near-black, the eye color all the art shares unless a character says otherwise.
    public static let defaultIconHoles = [(0x14, 0x14, 0x13)]

    public init(
        id: String, name: String, blurb: String, directory: URL,
        walkCycle: ClosedRange<CGFloat>, standingFrame: CGFloat, lookUpFrame: CGFloat = 0,
        roles: [Role: [String]], iconHoles: [(Int, Int, Int)] = Character.defaultIconHoles
    ) {
        self.id = id
        self.name = name
        self.blurb = blurb
        self.directory = directory
        self.walkCycle = walkCycle
        self.standingFrame = standingFrame
        self.lookUpFrame = lookUpFrame
        self.roles = roles
        self.iconHoles = iconHoles
    }

    public var catalog: AnimationCatalog { AnimationCatalog(directory: directory) }

    /// The acts that can play `role` and actually exist in this character's folder.
    public func acts(for role: Role) -> [String] {
        let names = Set(catalog.names)
        return (roles[role] ?? []).filter(names.contains)
    }

    public static let clawdID = "clawd"

    /// The original, whose animations are the site's Lottie files.
    public static func clawd(directory: URL) -> Character {
        Character(
            id: clawdID, name: "Clawd", blurb: "The original. Orange, earnest, always busy.",
            directory: directory, walkCycle: 5...24, standingFrame: 26, lookUpFrame: 12,
            roles: [
                .think: ["thinking"], .type: ["laptop"], .write: ["notebook"], .browse: ["phone"],
                .search: ["lightbulb"], .delegate: ["juggling"], .compact: ["meditating"],
                .celebrate: ["confetti-happy", "dancing-happy", "jumping-happy"],
            ])
    }

    /// A drawn character's folder: `character.json` (name, blurb), the exporter's `meta.json`, and an
    /// `animations` folder with `walking.json` and one file per act. An act named after a role plays that role.
    /// Frame 0 of `looking`, if there is one, is the eyes-up pose.
    public init?(folder: URL) {
        guard let info = Self.json(folder.appendingPathComponent("character.json")),
              let name = info["name"] as? String,
              let meta = Self.json(folder.appendingPathComponent("meta.json")),
              let cycle = meta["walkCycle"] as? [Double], cycle.count == 2, cycle[0] <= cycle[1],
              let standing = meta["standingFrame"] as? Double
        else { return nil }
        self.init(
            id: folder.lastPathComponent, name: name, blurb: info["blurb"] as? String ?? "",
            directory: folder.appendingPathComponent("animations"), walkCycle: CGFloat(cycle[0])...CGFloat(cycle[1]), standingFrame: CGFloat(standing),
            roles: Dictionary(uniqueKeysWithValues: Role.allCases.map { ($0, [$0.rawValue]) }),
            iconHoles: (info["iconHoles"] as? [String])?.compactMap(Self.rgb(hex:)) ?? Self.defaultIconHoles)
    }

    /// "#e9b03a" as (233, 176, 58).
    static func rgb(hex: String) -> (Int, Int, Int)? {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
        return ((value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff)
    }

    private static func json(_ url: URL) -> [String: Any]? {
        (try? Data(contentsOf: url)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }
}

/// Everyone who can be chosen: Clawd first, then each valid folder in `characters`, by name.
public struct Roster: Sendable {
    public let characters: [Character]

    public init(clawdDirectory: URL, charactersDirectory: URL?) {
        let folders = charactersDirectory.flatMap {
            try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)
        } ?? []
        let drawn = folders.compactMap(Character.init(folder:))
            .filter { $0.id != Character.clawdID && $0.catalog.names.contains("walking") }
            .sorted { $0.name < $1.name }
        characters = [Character.clawd(directory: clawdDirectory)] + drawn
    }

    /// The character with `id`, or Clawd.
    public func character(id: String?) -> Character {
        characters.first { $0.id == id } ?? characters[0]
    }
}
