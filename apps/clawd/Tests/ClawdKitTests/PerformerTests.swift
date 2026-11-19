import ClawdKit
import XCTest

@MainActor
final class PerformerTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    func testCancelledPopOutDoesNotLeaveHimInvisible() async {
        let window = ClawdWindow(size: ClawdSize.medium.size)
        defer { window.hide() }
        let popping = Task { await window.pop(visible: false) }
        try? await Task.sleep(for: .milliseconds(30))

        // What a size change or a display change does: cancel the routine, then show him again.
        popping.cancel()
        window.show()
        await popping.value

        XCTAssertEqual(window.opacity, 1)
    }

    func testHeAppearsOnceAScreenArrivesIfHeWasStartedWithoutOne() {
        var visibleFrame: CGRect?
        let window = ClawdWindow(size: ClawdSize.medium.size)
        let performer = Performer(
            catalog: AnimationCatalog(directory: stagedAnimations()), window: window,
            settings: Settings(defaults: UserDefaults(suiteName: "clawd.tests.\(UUID().uuidString)")!),
            visibleFrame: { visibleFrame })
        defer { performer.stop() }

        // Launched at login with the display still asleep.
        performer.start()
        XCTAssertTrue(performer.isRunning, "he was asked to be shown, so the menu should offer Hide")
        XCTAssertFalse(window.isVisible)

        visibleFrame = screen
        performer.refresh()
        XCTAssertTrue(window.isVisible)
    }

    func testHideStaysHiddenThroughAScreenChange() {
        let window = ClawdWindow(size: ClawdSize.medium.size)
        let performer = Performer(
            catalog: AnimationCatalog(directory: stagedAnimations()), window: window,
            settings: Settings(defaults: UserDefaults(suiteName: "clawd.tests.\(UUID().uuidString)")!),
            visibleFrame: { self.screen })
        performer.start()
        performer.stop()

        performer.refresh()

        XCTAssertFalse(performer.isRunning)
        XCTAssertFalse(window.isVisible)
    }
}
