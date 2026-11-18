import ClawdKit
import XCTest

final class SettingsTests: XCTestCase {
    func testSizeDefaultsToMediumAndPersists() {
        let defaults = UserDefaults(suiteName: "clawd.tests.\(UUID().uuidString)")!
        XCTAssertEqual(Settings(defaults: defaults).size, .medium)
        Settings(defaults: defaults).size = .large
        XCTAssertEqual(Settings(defaults: defaults).size, .large)
    }

    func testHeStaysAtTheBottomUnlessToldHeMayRoam() {
        let defaults = UserDefaults(suiteName: "clawd.tests.\(UUID().uuidString)")!
        XCTAssertFalse(Settings(defaults: defaults).roams)
        Settings(defaults: defaults).roams = true
        XCTAssertTrue(Settings(defaults: defaults).roams)
    }

    func testUnknownStoredSizeFallsBackToMedium() {
        let defaults = UserDefaults(suiteName: "clawd.tests.\(UUID().uuidString)")!
        defaults.set("gigantic", forKey: "size")
        XCTAssertEqual(Settings(defaults: defaults).size, .medium)
    }
}
