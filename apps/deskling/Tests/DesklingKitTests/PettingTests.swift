import DesklingKit
import XCTest

final class PettingTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    /// Feeds `xs` one sample every `gap` seconds; true if any sample completed a pet.
    private func pets(_ xs: [CGFloat], every gap: TimeInterval) -> Bool {
        var detector = PetDetector()
        return xs.enumerated().contains { index, x in
            detector.track(x: x, at: start.addingTimeInterval(Double(index) * gap))
        }
    }

    func testAQuickRubBackAndForthIsAPet() {
        XCTAssertTrue(pets([0, 20, 40, 20, 0, 20, 40, 20, 0, 20, 40], every: 0.05))
    }

    func testTheSameRubTooSlowlyIsNot() {
        XCTAssertFalse(pets([0, 20, 40, 20, 0, 20, 40, 20, 0, 20, 40], every: 0.5))
    }

    func testAShakyHandIsNot() {
        XCTAssertFalse(pets([0, 3, 0, 3, 0, 3, 0, 3, 0, 3, 0, 3, 0], every: 0.05))
    }

    func testPassingStraightOverIsNot() {
        XCTAssertFalse(pets(Array(stride(from: 0, through: 200, by: 10)), every: 0.03))
    }

    func testItStartsCountingAgainAfterAPet() {
        var detector = PetDetector()
        let rub: [CGFloat] = [0, 20, 40, 20, 0, 20, 40, 20, 0, 20, 40]
        let completions = (rub + rub.dropFirst()).enumerated().filter { index, x in
            detector.track(x: x, at: start.addingTimeInterval(Double(index) * 0.05))
        }
        XCTAssertEqual(completions.count, 2)
    }
}
