import CoreGraphics

/// Where he looks when the cursor comes close. AppKit coordinates (y up).
public struct Gaze: Equatable {
    public enum Eyes: Equatable {
        case ahead, up
    }

    public let facing: Facing
    public let eyes: Eyes

    /// How far around his window the cursor counts as close, in window widths sideways and heights above.
    public static let reachSideways: CGFloat = 0.6
    public static let reachAbove: CGFloat = 1.5

    /// Nil when the cursor is not close enough for him to notice.
    public static func toward(_ cursor: CGPoint, from frame: CGRect) -> Gaze? {
        let side: CGFloat = frame.width * reachSideways
        let above: CGFloat = frame.height * reachAbove
        let zone = CGRect(
            x: frame.minX - side, y: frame.minY, width: frame.width + 2 * side, height: frame.height + above)
        guard zone.contains(cursor) else { return nil }
        let facing: Facing = cursor.x >= frame.midX ? .right : .left
        // The art's eyes sit near the top of the window, so "up" means clearly above them.
        let eyes: Eyes = cursor.y > frame.maxY ? .up : .ahead
        return Gaze(facing: facing, eyes: eyes)
    }
}
