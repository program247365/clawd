import ClawdKit
import XCTest

@MainActor
final class LockScreenVisitorTests: XCTestCase {
    private func lockScreenSettings(visits: Bool = true) -> Settings {
        let settings = Settings(defaults: UserDefaults(suiteName: "clawd.tests.\(UUID().uuidString)")!)
        settings.visitsLockScreen = visits
        return settings
    }

    /// Launched, relaunched, or updated while the Mac is locked: no "locked" announcement will come.
    func testHeGoesToTheLockScreenWhenHeStartsWhileTheMacIsAlreadyLocked() throws {
        try XCTSkipUnless(LockScreenVisitor.isSupported)
        let window = ClawdWindow(size: ClawdSize.small.size)
        window.show()
        defer { window.hide() }

        let visitor = LockScreenVisitor(window: window, settings: lockScreenSettings(), isLocked: { true })

        XCTAssertTrue(visitor.isVisiting)
    }

    func testHeGoesToTheLockScreenWhenHeIsShownWhileTheMacIsLocked() throws {
        try XCTSkipUnless(LockScreenVisitor.isSupported)
        let window = ClawdWindow(size: ClawdSize.small.size)
        defer { window.hide() }
        let visitor = LockScreenVisitor(window: window, settings: lockScreenSettings(), isLocked: { true })
        XCTAssertFalse(visitor.isVisiting, "a hidden Clawd has nothing to show on the lock screen")

        window.show()

        XCTAssertTrue(visitor.isVisiting)
    }

    func testHeStaysOffTheLockScreenWhenTheSettingIsOff() throws {
        try XCTSkipUnless(LockScreenVisitor.isSupported)
        let window = ClawdWindow(size: ClawdSize.small.size)
        window.show()
        defer { window.hide() }

        let visitor = LockScreenVisitor(window: window, settings: lockScreenSettings(visits: false), isLocked: { true })

        XCTAssertFalse(visitor.isVisiting)
    }

    func testHeStaysOnTheDesktopWhileTheMacIsUnlocked() throws {
        try XCTSkipUnless(LockScreenVisitor.isSupported)
        let window = ClawdWindow(size: ClawdSize.small.size)
        window.show()
        defer { window.hide() }

        let visitor = LockScreenVisitor(window: window, settings: lockScreenSettings(), isLocked: { false })

        XCTAssertFalse(visitor.isVisiting)
    }

    /// Asking the system can lag behind its announcements, so after an unlock is announced
    /// a display change that shows him again must not send him back to the lock screen's layer.
    func testAnUnlockAnnouncementIsTrustedOverAStaleAnswer() async throws {
        try XCTSkipUnless(LockScreenVisitor.isSupported)
        let window = ClawdWindow(size: ClawdSize.small.size)
        window.show()
        defer { window.hide() }
        // A made-up name, so the test does not tell every other app that the screen unlocked.
        let unlocked = "sh.kbr.clawd.tests.unlocked.\(UUID().uuidString)"
        let visitor = LockScreenVisitor(
            window: window, settings: lockScreenSettings(), isLocked: { true }, unlockedName: unlocked)
        XCTAssertTrue(visitor.isVisiting)

        DistributedNotificationCenter.default().postNotificationName(
            .init(unlocked), object: nil, userInfo: nil, deliverImmediately: true)
        for _ in 0..<40 where visitor.isVisiting { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertFalse(visitor.isVisiting)

        window.show()
        XCTAssertFalse(visitor.isVisiting)
    }
}
