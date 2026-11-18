import ClawdKit
import XCTest

final class StageTests: XCTestCase {
    func testSizes() {
        XCTAssertEqual(ClawdSize.small.width, 120)
        XCTAssertEqual(ClawdSize.medium.width, 180)
        XCTAssertEqual(ClawdSize.large.width, 280)
        XCTAssertEqual(ClawdSize.medium.size.height, 180 * 1850.0 / 2750.0, accuracy: 0.001)
    }

    func testFloorPutsFeetOnTheBottomOfTheVisibleFrame() {
        let stage = Stage(visibleFrame: CGRect(x: 0, y: 70, width: 1512, height: 870), size: ClawdSize.medium.size)
        XCTAssertEqual(stage.floorY, 70 - stage.size.height * Stage.footInsetFraction, accuracy: 0.001)
        XCTAssertEqual(stage.floorOrigin(x: 100), CGPoint(x: 100, y: stage.floorY))
    }

    func testFloorOriginRespectsADockOnTheLeft() {
        let stage = Stage(visibleFrame: CGRect(x: 80, y: 0, width: 1432, height: 940), size: ClawdSize.medium.size)
        XCTAssertEqual(stage.floorOrigin(x: 0).x, 80)
    }

    func testEntranceStartsJustAboveTheUsableAreaOverTheSameSpotOnTheFloor() {
        let frame = CGRect(x: 80, y: 70, width: 1432, height: 870)
        let stage = Stage(visibleFrame: frame, size: ClawdSize.medium.size)
        let top = stage.entranceOrigin(x: 300)
        XCTAssertEqual(top.x, stage.floorOrigin(x: 300).x)
        XCTAssertEqual(top.y, frame.maxY)
    }

    func testTeleportKeepsHimFullyInsideTheVisibleFrame() {
        let frame = CGRect(x: 0, y: 70, width: 1512, height: 870)
        let stage = Stage(visibleFrame: frame, size: ClawdSize.large.size)
        var rng = Seeded(5)
        for _ in 0..<500 {
            XCTAssertTrue(frame.contains(CGRect(origin: stage.teleportOrigin(using: &rng), size: stage.size)))
        }
    }

    func testAreaSmallerThanClawdDoesNotBreak() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let stage = Stage(visibleFrame: frame, size: ClawdSize.large.size)
        var rng = Seeded(9)
        XCTAssertEqual(stage.maxX, 0)
        XCTAssertEqual(stage.teleportOrigin(using: &rng), frame.origin)
    }

    func testClampPullsAStrayOriginBackInside() {
        let frame = CGRect(x: 0, y: 70, width: 1512, height: 870)
        let stage = Stage(visibleFrame: frame, size: ClawdSize.medium.size)
        let clamped = stage.clamp(CGPoint(x: 4000, y: -500))
        XCTAssertEqual(clamped.x, frame.maxX - stage.size.width)
        XCTAssertEqual(clamped.y, stage.floorY)
    }

    @MainActor
    func testFootInsetMatchesTheArt() throws {
        let walking = try XCTUnwrap(AnimationCatalog(directory: stagedAnimations()).load("walking"))
        let height = 370
        var lowest = 0
        for frame in 5...24 {
            let image = try XCTUnwrap(FrameRenderer.render(
                walking.animation, frame: CGFloat(frame), pixelSize: CGSize(width: 550, height: height)))
            lowest = max(lowest, try XCTUnwrap(PixelStats(image).lowestOpaqueRow))
        }
        let measured = Double(height - 1 - lowest) / Double(height)
        print("measured foot inset fraction: \(measured)")
        XCTAssertEqual(Double(Stage.footInsetFraction), measured, accuracy: 0.01)
    }
}
