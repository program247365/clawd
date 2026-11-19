import Foundation

/// Notices the cursor being rubbed back and forth over a character: several quick changes of
/// direction close together. Fed cursor positions while the cursor is over them.
public struct PetDetector {
    /// Changes of direction it takes to count as petting.
    public static let turnsNeeded = 4
    /// How close together those changes of direction must be.
    public static let window: TimeInterval = 1.5
    /// The smallest sideways swing that counts, in points, so a shaky hand is not a pet.
    public static let smallestSwing: CGFloat = 8

    /// The furthest point reached in the current swing.
    private var extreme: CGFloat?
    /// +1 moving right, -1 moving left, 0 before the first swing.
    private var direction: CGFloat = 0
    private var turns: [Date] = []

    public init() {}

    /// True when this sample completes a pet; it then starts counting afresh.
    public mutating func track(x: CGFloat, at now: Date) -> Bool {
        guard let from = extreme else {
            extreme = x
            return false
        }
        let moved = x - from
        if direction == 0 || moved * direction > 0 {
            // Still going the same way (or not yet going anywhere): only a big enough first move sets the direction.
            if direction != 0 || abs(moved) >= Self.smallestSwing {
                direction = moved > 0 ? 1 : -1
                extreme = x
            }
            return false
        }
        guard abs(moved) >= Self.smallestSwing else { return false }
        direction = -direction
        extreme = x
        turns.append(now)
        turns.removeAll { now.timeIntervalSince($0) > Self.window }
        guard turns.count >= Self.turnsNeeded else { return false }
        reset()
        return true
    }

    public mutating func reset() {
        extreme = nil
        direction = 0
        turns.removeAll()
    }
}
