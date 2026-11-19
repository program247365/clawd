import DesklingKit
import XCTest

@MainActor
final class HeadTopTests: XCTestCase {
    /// The bubble sits on his head, so where his head is must come from the art, not the window.
    func testEveryCharactersHeadIsBelowTheTopOfTheirWindow() throws {
        let staged = stagedAnimations().deletingLastPathComponent().appendingPathComponent("characters")
        let roster = Roster(clawdDirectory: stagedAnimations(), charactersDirectory: staged)
        for character in roster.characters {
            let walking = try XCTUnwrap(character.catalog.load("walking"), character.id)
            let image = try XCTUnwrap(FrameRenderer.render(
                walking.animation, frame: character.standingFrame, pixelSize: CGSize(width: 275, height: 185)))
            let top = try XCTUnwrap(FrameRenderer.drawnTop(of: image), character.id)
            XCTAssertGreaterThan(top, 0.2, character.id)
            XCTAssertLessThan(top, 0.95, "\(character.id) has headroom above them in the canvas")
            print("\(character.id) head top: \(top)")
        }
    }
}
