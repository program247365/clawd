import CoreGraphics

/// Where each character on screen stands, so they keep out of each other's way: none walks through,
/// lands on, or comes to wave in front of another.
@MainActor
public final class Floor {
    /// Space kept between two characters' drawings.
    public nonisolated static let gap: CGFloat = 8

    private struct Spot {
        let screen: CGRect
        /// The horizontal reach of the drawing, in screen coordinates.
        let span: ClosedRange<CGFloat>
    }

    private var spots: [ObjectIdentifier: Spot] = [:]

    public init() {}

    public func set(_ owner: AnyObject, screen: CGRect, span: ClosedRange<CGFloat>) {
        spots[ObjectIdentifier(owner)] = Spot(screen: screen, span: span)
    }

    public func remove(_ owner: AnyObject) {
        spots[ObjectIdentifier(owner)] = nil
    }

    /// Where everyone but `owner` stands on `screen`.
    public func spans(except owner: AnyObject?, on screen: CGRect) -> [ClosedRange<CGFloat>] {
        spots.filter { $0.key != owner.map(ObjectIdentifier.init) && $0.value.screen == screen }.map(\.value.span)
    }

    // The rest works on positions along one floor: `blocked` holds the stretches a position may not fall
    // strictly inside, because standing there would put him in front of someone.

    public nonisolated static func isBlocked(_ x: CGFloat, by blocked: [ClosedRange<CGFloat>]) -> Bool {
        blocked.contains { $0.lowerBound < x && x < $0.upperBound }
    }

    /// The free position in `bounds` nearest `desired`; ties go to the one nearer `prefer`. Nil if there is none.
    public nonisolated static func nearestFree(
        to desired: CGFloat, prefer: CGFloat? = nil, in bounds: ClosedRange<CGFloat>, blocked: [ClosedRange<CGFloat>]
    ) -> CGFloat? {
        let candidates = [min(max(desired, bounds.lowerBound), bounds.upperBound)]
            + blocked.flatMap { [$0.lowerBound, $0.upperBound] }
        let prefer = prefer ?? desired
        return candidates
            .filter { bounds.contains($0) && !isBlocked($0, by: blocked) }
            .min { (abs($0 - desired), abs($0 - prefer)) < (abs($1 - desired), abs($1 - prefer)) }
    }

    /// The free stretch of `bounds` around `x`: as far as he can walk either way without reaching anyone.
    public nonisolated static func room(around x: CGFloat, in bounds: ClosedRange<CGFloat>, blocked: [ClosedRange<CGFloat>]) -> ClosedRange<CGFloat> {
        let lower = max(bounds.lowerBound, blocked.map(\.upperBound).filter { $0 <= x }.max() ?? bounds.lowerBound)
        let upper = min(bounds.upperBound, blocked.map(\.lowerBound).filter { $0 >= x }.min() ?? bounds.upperBound)
        return lower...max(lower, upper)
    }
}
