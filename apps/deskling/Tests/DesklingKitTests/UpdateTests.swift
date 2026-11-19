@testable import DesklingKit
import XCTest

@MainActor
final class UpdateLinesTests: XCTestCase {
    func testTheyAnnounceTheVersionSayTheNotesAndInviteAClick() {
        XCTAssertEqual(
            Updater.lines(version: "0.6.0", notes: "  You can pet them now!\n\nThey nap too\n"),
            ["Psst! Deskling 0.6.0 is out", "You can pet them now!", "They nap too", "Click me to update"])
    }

    func testNotesAreKeptShortEnoughForTheBubble() {
        let notes = (1...5).map { "line \($0)" }.joined(separator: "\n") + "\n" + String(repeating: "x", count: 60)
        let lines = Updater.lines(version: "1.0.0", notes: notes)
        XCTAssertEqual(lines.count, 2 + Updater.mostLines)
        XCTAssertTrue(lines.allSatisfy { $0.count <= Updater.longestLine })

        let long = Updater.lines(version: "1.0.0", notes: String(repeating: "x", count: 60))
        XCTAssertEqual(long[1].count, Updater.longestLine)
        XCTAssertTrue(long[1].hasSuffix("…"))
    }

    func testNoNotesStillOffersTheUpdate() {
        XCTAssertEqual(Updater.lines(version: "0.6.0", notes: nil), ["Psst! Deskling 0.6.0 is out", "Click me to update"])
    }
}

@MainActor
final class AnnouncementTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    private func makePerformer() -> (Performer, CharacterWindow) {
        let window = CharacterWindow(size: CharacterSize.medium.size)
        let performer = Performer(
            character: Character.clawd(directory: stagedAnimations()), window: window,
            settings: Settings(defaults: UserDefaults(suiteName: "clawd.tests.\(UUID().uuidString)")!),
            visibleFrame: { self.screen }, alertFrame: { self.screen },
            cursorLocation: { CGPoint(x: -999, y: -999) }, idleTime: { 0 })
        return (performer, window)
    }

    private func eventually(within seconds: Double = 4, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }

    func testTheLastLineTakesTheClickAndAnUnansweredOfferLapses() async {
        let (performer, window) = makePerformer()
        defer { performer.stop() }
        performer.start()
        var clicked = false
        var lapsed = false
        performer.announce(Performer.Announcement(
            lines: ["Click me to update"], onClick: { clicked = true }, holdFor: 0.6, onTimeout: { lapsed = true }))

        let clickable = await eventually { window.onClick != nil }
        XCTAssertTrue(clickable)
        window.onClick?()
        XCTAssertTrue(clicked)

        let over = await eventually { lapsed }
        XCTAssertTrue(over)
        XCTAssertNil(performer.announcement)
        XCTAssertNil(window.onClick, "once it lapses, clicks pass through again")
    }

    func testAnAgentWaitingOnYouComesFirst() async {
        let (performer, window) = makePerformer()
        defer { performer.stop() }
        performer.start()
        performer.alert("api needs you")
        performer.announce(Performer.Announcement(lines: ["Click me to update"], onClick: {}))
        try? await Task.sleep(for: .milliseconds(600))
        XCTAssertEqual(performer.alertText, "api needs you")
        XCTAssertNotNil(performer.announcement, "the update waits its turn")

        var updateClicked = false
        performer.endAnnouncement()
        performer.announce(Performer.Announcement(lines: ["Click me to update"], onClick: { updateClicked = true }))
        performer.clearAlert()
        let offered = await eventually { window.onClick != nil }
        XCTAssertTrue(offered, "after the alert, the update gets its say")
        window.onClick?()
        XCTAssertTrue(updateClicked)
    }

    func testProgressReplacesTheOfferWithoutTakingClicks() async {
        let (performer, window) = makePerformer()
        defer { performer.stop() }
        performer.start()
        performer.announce(Performer.Announcement(lines: ["Click me to update"], onClick: {}))
        _ = await eventually { window.onClick != nil }

        performer.updateAnnouncement("Downloading… 40%")
        let busy = await eventually { window.onClick == nil }
        XCTAssertTrue(busy)
        XCTAssertEqual(performer.announcement?.lines, ["Downloading… 40%"])
    }
}
