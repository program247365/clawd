import DesklingKit
import XCTest

final class AnimationCatalogTests: XCTestCase {
    func testCatalogListsEveryStagedFile() throws {
        let staged = stagedAnimations()
        let files = try FileManager.default.contentsOfDirectory(atPath: staged.path)
            .filter { $0.hasSuffix(".json") }
        let catalog = AnimationCatalog(directory: staged)
        XCTAssertEqual(catalog.names.count, files.count)
        XCTAssertGreaterThanOrEqual(catalog.names.count, 37)
        XCTAssertEqual(catalog.names, catalog.names.sorted())
        XCTAssertTrue(catalog.names.contains("walking"))
        XCTAssertEqual(catalog.actNames.count, catalog.names.count - 1)
        XCTAssertFalse(catalog.actNames.contains("walking"))
    }

    func testLoadsAnAnimationByName() throws {
        let walking = try XCTUnwrap(AnimationCatalog(directory: stagedAnimations()).load("walking"))
        XCTAssertEqual(walking.name, "walking")
        XCTAssertEqual(walking.frameCount, 28)
    }

    func testCorruptAndUnknownAnimationsLoadAsNil() throws {
        let temp = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }
        try FileManager.default.copyItem(
            at: stagedAnimations().appendingPathComponent("waving.json"),
            to: temp.appendingPathComponent("waving.json"))
        try Data("{".utf8).write(to: temp.appendingPathComponent("broken.json"))
        try Data("notes".utf8).write(to: temp.appendingPathComponent("notes.txt"))

        let catalog = AnimationCatalog(directory: temp)

        XCTAssertEqual(catalog.names, ["broken", "waving"])
        XCTAssertNotNil(catalog.load("waving"))
        XCTAssertNil(catalog.load("broken"))
        XCTAssertNil(catalog.load("walking"))
        XCTAssertNil(catalog.load("../waving"))
    }

    func testEmptyDirectoryGivesEmptyCatalog() {
        let temp = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }
        XCTAssertTrue(AnimationCatalog(directory: temp).names.isEmpty)
    }

    func testMissingDirectoryGivesEmptyCatalog() {
        let missing = URL(fileURLWithPath: "/nonexistent/clawd-\(UUID().uuidString)")
        XCTAssertTrue(AnimationCatalog(directory: missing).names.isEmpty)
    }
}
