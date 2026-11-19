import DesklingKit
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

    func testHeOnlyVisitsTheLockScreenWhenInvited() {
        let defaults = UserDefaults(suiteName: "clawd.tests.\(UUID().uuidString)")!
        XCTAssertFalse(Settings(defaults: defaults).visitsLockScreen)
        Settings(defaults: defaults).visitsLockScreen = true
        XCTAssertTrue(Settings(defaults: defaults).visitsLockScreen)
    }

    func testUnknownStoredSizeFallsBackToMedium() {
        let defaults = UserDefaults(suiteName: "clawd.tests.\(UUID().uuidString)")!
        defaults.set("gigantic", forKey: "size")
        XCTAssertEqual(Settings(defaults: defaults).size, .medium)
    }
}

final class SettingsImportTests: XCTestCase {
    private func suite() -> UserDefaults {
        UserDefaults(suiteName: "deskling.tests.\(UUID().uuidString)")!
    }

    func testCopiesTheOldAppsSettingsOnce() {
        let old = suite(), new = suite()
        old.set(true, forKey: Settings.roamsKey)
        old.set("large", forKey: "size")
        old.set(true, forKey: Settings.visitsLockScreenKey)
        let settings = Settings(defaults: new)

        settings.importPrevious(from: old)
        XCTAssertTrue(settings.roams)
        XCTAssertEqual(settings.size, .large)
        XCTAssertTrue(settings.visitsLockScreen)

        // Changed since, then a later launch: nothing is copied again.
        settings.roams = false
        old.set("small", forKey: "size")
        settings.importPrevious(from: old)
        XCTAssertFalse(settings.roams)
        XCTAssertEqual(settings.size, .large)
    }

    func testNeverOverwritesWhatTheNewAppAlreadyHas() {
        let old = suite(), new = suite()
        old.set("large", forKey: "size")
        new.set("small", forKey: "size")
        let settings = Settings(defaults: new)
        settings.importPrevious(from: old)
        XCTAssertEqual(settings.size, .small)
    }
}
