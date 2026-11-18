import ClawdKit
import XCTest

final class AnimationCatalogTests: XCTestCase {
    func testCatalogLoadsEveryStagedFile() throws {
        let staged = stagedAnimations()
        let files = try FileManager.default.contentsOfDirectory(atPath: staged.path)
            .filter { $0.hasSuffix(".json") }
        let catalog = AnimationCatalog(directory: staged)
        XCTAssertEqual(catalog.all.count, files.count)
        XCTAssertGreaterThanOrEqual(catalog.all.count, 37)
        XCTAssertNotNil(catalog.walking)
        XCTAssertEqual(catalog.acts.count, catalog.all.count - 1)
        XCTAssertFalse(catalog.acts.contains { $0.name == "walking" })
    }

    func testWalkingHasTheStepCycle() {
        XCTAssertEqual(AnimationCatalog(directory: stagedAnimations()).walking?.frameCount, 28)
    }

    func testCorruptAndMissingFilesAreSkipped() throws {
        let temp = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }
        try FileManager.default.copyItem(
            at: stagedAnimations().appendingPathComponent("waving.json"),
            to: temp.appendingPathComponent("waving.json"))
        try Data("{".utf8).write(to: temp.appendingPathComponent("broken.json"))
        try Data("notes".utf8).write(to: temp.appendingPathComponent("notes.txt"))

        let catalog = AnimationCatalog(directory: temp)

        XCTAssertEqual(catalog.all.map(\.name), ["waving"])
        XCTAssertNil(catalog.walking)
    }

    func testEmptyDirectoryGivesEmptyCatalog() {
        let temp = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }
        XCTAssertTrue(AnimationCatalog(directory: temp).all.isEmpty)
    }

    func testMissingDirectoryGivesEmptyCatalog() {
        let missing = URL(fileURLWithPath: "/nonexistent/clawd-\(UUID().uuidString)")
        XCTAssertTrue(AnimationCatalog(directory: missing).all.isEmpty)
    }
}
