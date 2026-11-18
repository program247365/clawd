import ClawdKit
import XCTest

final class ChoreographyTests: XCTestCase {
    func testQueuePlaysEveryActOnceBeforeRepeating() {
        var queue = ActQueue(names: ["a", "b", "c", "d", "e"])
        var rng = Seeded(1)
        let first = (0..<5).compactMap { _ in queue.next(using: &rng) }
        let second = (0..<5).compactMap { _ in queue.next(using: &rng) }
        XCTAssertEqual(Set(first).count, 5)
        XCTAssertEqual(Set(second).count, 5)
    }

    func testEmptyQueueReturnsNil() {
        var queue = ActQueue(names: [])
        var rng = Seeded(1)
        XCTAssertNil(queue.next(using: &rng))
    }

    func testShortActsPlayTwice() {
        XCTAssertEqual(Choreography.plays(forFrameCount: 39), 2)
        XCTAssertEqual(Choreography.plays(forFrameCount: 40), 1)
    }

    func testWalkStopsStayInBoundsAndCoverAThird() {
        var rng = Seeded(7)
        var x: CGFloat = 40
        var facing = Facing.right
        let maxX: CGFloat = 1200
        for _ in 0..<500 {
            let stop = Choreography.nextWalkStop(from: x, facing: facing, maxX: maxX, using: &rng)
            XCTAssertTrue((0...maxX).contains(stop))
            if stop != 0 && stop != maxX {
                XCTAssertGreaterThanOrEqual(abs(stop - x), maxX / 3 - 0.001)
            }
            facing = stop >= x ? .right : .left
            x = stop
        }
    }

    func testWalkStopWithNoRoomReturnsZero() {
        var rng = Seeded(3)
        XCTAssertEqual(Choreography.nextWalkStop(from: 0, facing: .right, maxX: 0, using: &rng), 0)
    }

    func testStepMovesAtWalkSpeed() {
        let result = Choreography.step(x: 0, toward: 500, width: 180, elapsed: 0.016)
        XCTAssertEqual(result.x, 180 * 140.0 / 360.0 * 0.016, accuracy: 0.0001)
        XCTAssertFalse(result.arrived)
    }

    func testStepMovesLeftTowardALowerTarget() {
        let result = Choreography.step(x: 500, toward: 0, width: 180, elapsed: 0.016)
        XCTAssertEqual(result.x, 500 - 180 * 140.0 / 360.0 * 0.016, accuracy: 0.0001)
    }

    func testStepClampsLongGaps() {
        let result = Choreography.step(x: 0, toward: 5000, width: 180, elapsed: 3600)
        XCTAssertEqual(result.x, 180 * 140.0 / 360.0 * 0.05, accuracy: 0.0001)
    }

    func testStepStopsExactlyAtTarget() {
        let right = Choreography.step(x: 9.9, toward: 10, width: 180, elapsed: 0.05)
        XCTAssertEqual(right.x, 10)
        XCTAssertTrue(right.arrived)
        let left = Choreography.step(x: 10.1, toward: 10, width: 180, elapsed: 0.05)
        XCTAssertEqual(left.x, 10)
        XCTAssertTrue(left.arrived)
    }

    func testTeleportChanceIsAboutOneInFour() {
        var rng = Seeded(11)
        let hits = (0..<4000).filter { _ in Choreography.shouldTeleport(using: &rng) }.count
        XCTAssertEqual(Double(hits) / 4000, 0.25, accuracy: 0.03)
    }
}
