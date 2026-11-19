import AppKit
import Sparkle

/// Keeps Deskling up to date with Sparkle, with the character as the whole interface: no windows.
/// When an update is out they tell you in their speech bubble, and clicking them installs it.
///
/// The feed, its signing key, and daily checks are set in Info.plist (`SUFeedURL`, `SUPublicEDKey`,
/// `SUEnableAutomaticChecks`). Each release's feed is made by `scripts/publish.sh`.
@MainActor
public final class Updater: NSObject {
    private let performer: Performer
    private var updater: SPUUpdater?
    /// True while you are waiting on a check you asked for from the menu.
    private var userInitiated = false
    /// True once you have said yes, so a failure is worth telling you about.
    private var installing = false
    private var expectedBytes: UInt64 = 0
    private var receivedBytes: UInt64 = 0
    private var shownPercent = -1

    /// Each line of an update's notes is said in turn, so they stay short; longer ones are cut off.
    static let longestLine = 40
    static let mostLines = 3
    /// How long they offer an update you did not ask for before trying again another day.
    static let offerFor: TimeInterval = 90

    public init(performer: Performer) {
        self.performer = performer
        super.init()
        let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: self, delegate: nil)
        do {
            try updater.start()
            self.updater = updater
        } catch {
            NSLog("Deskling: updates are off: \(error as NSError)")
        }
    }

    /// Whether this copy of the app can update itself: false in a build with no feed.
    public static var isAvailable: Bool { Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil }

    public var canCheck: Bool { updater?.canCheckForUpdates ?? false }

    /// The daily check. Set through Sparkle so it reschedules straight away.
    public var checksAutomatically: Bool {
        get { updater?.automaticallyChecksForUpdates ?? false }
        set { updater?.automaticallyChecksForUpdates = newValue }
    }

    /// The menu's "Check for Updates…".
    public func checkNow() {
        userInitiated = true
        updater?.checkForUpdates()
    }

    /// What they say about an update: who is out, the notes a line at a time, then the invitation.
    static func lines(version: String, notes: String?) -> [String] {
        let notes = (notes ?? "")
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(mostLines)
            .map { $0.count > longestLine ? $0.prefix(longestLine - 1) + "…" : $0 }
        return ["Psst! Deskling \(version) is out"] + notes + ["Click me to update"]
    }

    private func say(_ text: String, for seconds: TimeInterval) {
        performer.announce(Performer.Announcement(lines: [text], holdFor: seconds))
    }

    private func reset() {
        userInitiated = false
        installing = false
    }
}

extension Updater: SPUUserDriver {
    public func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        // Info.plist turns daily checks on, so this is not normally asked; if it is, the answer is the same.
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    public func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        performer.announce(Performer.Announcement(lines: ["Let me check…"]))
    }

    public func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        // Sparkle's reply must be called exactly once, whether you click or the offer runs out.
        var answered = false
        let answer: (SPUUserUpdateChoice) -> Void = { choice in
            guard !answered else { return }
            answered = true
            reply(choice)
        }
        let asked = userInitiated
        userInitiated = false
        performer.announce(Performer.Announcement(
            lines: Self.lines(version: appcastItem.displayVersionString, notes: appcastItem.itemDescription),
            onClick: { [weak self] in
                self?.installing = true
                self?.performer.updateAnnouncement("Here we go!")
                answer(.install)
            },
            // Asked for from the menu, the offer stands until you click; unasked, it lapses and comes back tomorrow.
            holdFor: asked ? nil : Self.offerFor,
            onTimeout: { answer(.dismiss) }))
    }

    public func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

    public func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}

    public func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        if userInitiated { say("You're up to date!", for: 3) }
        reset()
        acknowledgement()
    }

    public func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        NSLog("Deskling: update failed: \(error as NSError)")
        if userInitiated || installing {
            say("Couldn't update. I'll try again later.", for: 4)
        } else {
            performer.endAnnouncement()
        }
        reset()
        acknowledgement()
    }

    public func showDownloadInitiated(cancellation: @escaping () -> Void) {
        receivedBytes = 0
        shownPercent = -1
        performer.updateAnnouncement("Downloading…")
    }

    public func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        expectedBytes = expectedContentLength
    }

    public func showDownloadDidReceiveData(ofLength length: UInt64) {
        receivedBytes += length
        guard expectedBytes > 0 else { return }
        // In steps of ten, so the bubble is not redrawn for every packet.
        let percent = Int(min(receivedBytes * 100 / expectedBytes, 100)) / 10 * 10
        guard percent != shownPercent else { return }
        shownPercent = percent
        performer.updateAnnouncement("Downloading… \(percent)%")
    }

    public func showDownloadDidStartExtractingUpdate() {
        performer.updateAnnouncement("Unpacking…")
    }

    public func showExtractionReceivedProgress(_ progress: Double) {}

    public func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        // You already said yes when you clicked.
        performer.updateAnnouncement("Installing…")
        reply(.install)
    }

    public func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        performer.updateAnnouncement("See you in a sec!")
    }

    public func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        reset()
        acknowledgement()
    }

    public func showUpdateInFocus() {}

    public func dismissUpdateInstallation() {
        // Called when Sparkle is finished, whatever happened. A message with its own timer is left to finish.
        if performer.announcement?.holdFor == nil { performer.endAnnouncement() }
        reset()
    }
}
