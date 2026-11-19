import DesklingEvents
@testable import DesklingKit
import SwiftUI
import XCTest

final class AgentEventTests: XCTestCase {
    func testClaudeCodeHooksBecomeEvents() throws {
        let tool = try XCTUnwrap(AgentEvent(hook: [
            "hook_event_name": "PreToolUse", "session_id": "s1", "cwd": "/Users/me/code/clawd",
            "tool_name": "Bash", "tool_input": ["command": "rm -rf secrets"],
        ], agent: "claude"))
        XCTAssertEqual(tool, AgentEvent(agent: "claude", kind: .toolStarted, session: "s1", project: "clawd", tool: "Bash"))

        let waiting = try XCTUnwrap(AgentEvent(hook: [
            "hook_event_name": "Notification", "session_id": "s1", "cwd": "/tmp/x", "notification_type": "permission_prompt",
        ], agent: "claude"))
        XCTAssertEqual(waiting.kind, .needsInput)
        XCTAssertNil(waiting.tool)
    }

    func testOnlyWaitingNotificationsAskForYou() {
        for type in ["auth_success", "agent_completed", "quota_auto_resume_fired", ""] {
            XCTAssertNil(AgentEvent(hook: ["hook_event_name": "Notification", "notification_type": type], agent: "claude"), type)
        }
        XCTAssertNil(AgentEvent(hook: ["hook_event_name": "Notification"], agent: "claude"))
        XCTAssertEqual(AgentEvent(hook: ["hook_event_name": "Notification", "notification_type": "idle_prompt"], agent: "claude")?.kind, .needsInput)
    }

    func testCodexHooksShareTheFormat() {
        let request = AgentEvent(hook: [
            "hook_event_name": "PermissionRequest", "session_id": "t9", "cwd": "/w/api", "tool_name": "Bash",
        ], agent: "codex")
        XCTAssertEqual(request, AgentEvent(agent: "codex", kind: .needsInput, session: "t9", project: "api"))
        XCTAssertEqual(AgentEvent(hook: ["hook_event_name": "Interrupt", "session_id": "t9"], agent: "codex")?.kind, .toolFinished)
    }

    func testUnknownHooksAndMissingFields() {
        XCTAssertNil(AgentEvent(hook: ["hook_event_name": "FileChanged"], agent: "claude"))
        let bare = AgentEvent(hook: ["hook_event_name": "Stop"], agent: "claude")
        XCTAssertEqual(bare?.session, "claude")
        XCTAssertEqual(bare?.project, "your agent")
    }

    func testRoundTripsThroughUserInfo() {
        let event = AgentEvent(agent: "codex", kind: .toolStarted, session: "a", project: "b", tool: "apply_patch")
        XCTAssertEqual(AgentEvent(userInfo: event.userInfo), event)
        XCTAssertNil(AgentEvent(userInfo: ["agent": "x", "kind": "nonsense", "session": "a", "project": "b"]))
    }
}

final class AgentDeskTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    private func event(_ kind: AgentEvent.Kind, session: String = "s1", project: String = "clawd", tool: String? = nil) -> AgentEvent {
        AgentEvent(agent: "claude", kind: kind, session: session, project: project, tool: tool)
    }

    func testWaitingSessionsAlertUntilAnswered() {
        var desk = AgentDesk()
        XCTAssertEqual(desk.handle(event(.needsInput), at: start), [.alert("clawd needs you")])
        XCTAssertEqual(desk.handle(event(.needsInput, session: "s2", project: "api"), at: start), [.alert("2 agents need you")])
        XCTAssertEqual(desk.handle(event(.toolFinished), at: start), [.alert("api needs you")])
        // No ambient act while someone is still waiting.
        XCTAssertEqual(desk.handle(event(.toolStarted, tool: "Bash"), at: start), [])
        // Answering the last one clears the alert, and he goes straight to acting out the new prompt.
        XCTAssertEqual(desk.handle(event(.promptSubmitted, session: "s2"), at: start), [.clearAlert, .perform(.think, saying: nil)])
    }

    func testAmbientActsAreSparing() {
        var desk = AgentDesk()
        XCTAssertEqual(desk.handle(event(.toolStarted, tool: "Edit"), at: start), [.perform(.write, saying: nil)])
        XCTAssertEqual(desk.handle(event(.toolStarted, tool: "Bash"), at: start.addingTimeInterval(5)), [])
        XCTAssertEqual(
            desk.handle(event(.toolStarted, tool: "Bash"), at: start.addingTimeInterval(AgentDesk.ambientGap)),
            [.perform(.type, saying: nil)])
        XCTAssertEqual(desk.handle(event(.toolStarted, tool: "mcp__fs__read"), at: start.addingTimeInterval(500)), [])
    }

    func testFinishingCelebratesWithTheProjectName() {
        var desk = AgentDesk()
        XCTAssertEqual(desk.handle(event(.finished), at: start), [.perform(.celebrate, saying: "clawd is done")])
        XCTAssertEqual(desk.handle(event(.finished), at: start.addingTimeInterval(2)), [])
    }

    func testSettingsTurnReactionsOff() {
        var desk = AgentDesk()
        XCTAssertEqual(desk.handle(event(.needsInput), at: start, alerts: false), [])
        XCTAssertEqual(desk.handle(event(.promptSubmitted), at: start, ambient: false), [])
    }

    func testDismissForgetsEveryone() {
        var desk = AgentDesk()
        _ = desk.handle(event(.needsInput), at: start)
        desk.dismissAll()
        XCTAssertTrue(desk.waiting.isEmpty)
        XCTAssertEqual(desk.handle(event(.toolFinished), at: start), [])
    }
}

final class GazeTests: XCTestCase {
    private let him = CGRect(x: 500, y: 0, width: 180, height: 121)

    func testNoticesOnlyNearbyCursors() {
        XCTAssertNil(Gaze.toward(CGPoint(x: 100, y: 50), from: him))
        XCTAssertNil(Gaze.toward(CGPoint(x: 590, y: 600), from: him))
        XCTAssertEqual(Gaze.toward(CGPoint(x: 450, y: 60), from: him), Gaze(facing: .left, eyes: .ahead))
        XCTAssertEqual(Gaze.toward(CGPoint(x: 650, y: 200), from: him), Gaze(facing: .right, eyes: .up))
    }
}

final class RosterTests: XCTestCase {
    private func drawnCharacter(id: String, name: String, in root: URL, meta: String = #"{"walkCycle":[0,3],"standingFrame":4}"#) throws {
        let folder = root.appendingPathComponent(id)
        let animations = folder.appendingPathComponent("animations")
        try FileManager.default.createDirectory(at: animations, withIntermediateDirectories: true)
        try Data(#"{"name":"\#(name)","blurb":"Hi."}"#.utf8).write(to: folder.appendingPathComponent("character.json"))
        try Data(meta.utf8).write(to: folder.appendingPathComponent("meta.json"))
        try FileManager.default.copyItem(
            at: stagedAnimations().appendingPathComponent("walking.json"), to: animations.appendingPathComponent("walking.json"))
        try FileManager.default.copyItem(
            at: stagedAnimations().appendingPathComponent("thinking.json"), to: animations.appendingPathComponent("think.json"))
    }

    func testClawdComesFirstThenDrawnCharactersByName() throws {
        let root = makeTempDirectory()
        try drawnCharacter(id: "zed", name: "Zed", in: root)
        try drawnCharacter(id: "ada", name: "Ada", in: root)
        try drawnCharacter(id: "broken", name: "Broken", in: root, meta: "{}")

        let roster = Roster(clawdDirectory: stagedAnimations(), charactersDirectory: root)

        XCTAssertEqual(roster.characters.map(\.name), ["Clawd", "Ada", "Zed"])
        XCTAssertEqual(roster.character(id: "ada").walkCycle, 0...3)
        XCTAssertEqual(roster.character(id: "ada").acts(for: .think), ["think"])
        XCTAssertEqual(roster.character(id: "ada").acts(for: .type), [])
        XCTAssertEqual(roster.character(id: "missing").id, Character.clawdID)
        XCTAssertEqual(roster.character(id: nil).id, Character.clawdID)
    }

    func testEveryClawdRoleHasItsAct() {
        let clawd = Character.clawd(directory: stagedAnimations())
        for role in Role.allCases {
            XCTAssertFalse(clawd.acts(for: role).isEmpty, "\(role)")
        }
    }

    /// The shape of Kevin's real hooks.json: hooks from other tools that must survive.
    private let theirs: [String: Any] = [
        "hooks": [
            "SessionStart": [["hooks": [["type": "command", "command": "bash herdr-agent-state.sh session", "timeout": 10]]]],
            "SubagentStart": [["matcher": "tldraw-offline", "hooks": [["type": "command", "command": "node inject.mjs"]]]],
        ],
    ]
    private let hook = "/Apps/It's Deskling.app/Contents/Helpers/deskling-hook"

    private func commands(_ root: [String: Any], _ event: String) -> [String] {
        let groups = ((root["hooks"] as? [String: Any])?[event] as? [[String: Any]]) ?? []
        return groups.flatMap { ($0["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String } }
    }

    func testConnectingKeepsEveryOtherHook() throws {
        let merged = try CodexHooks.merged(theirs, hook: hook)
        XCTAssertEqual(commands(merged, "SessionStart"), ["bash herdr-agent-state.sh session", CodexHooks.command(hook: hook)])
        XCTAssertEqual(commands(merged, "SubagentStart"), ["node inject.mjs"])
        let tldraw = ((merged["hooks"] as? [String: Any])?["SubagentStart"] as? [[String: Any]])?.first
        XCTAssertEqual(tldraw?["matcher"] as? String, "tldraw-offline")
        XCTAssertTrue(CodexHooks.isConnected(merged))
        XCTAssertTrue(CodexHooks.command(hook: hook).hasPrefix(#"'/Apps/It'\''s Deskling.app"#))
    }

    func testConnectingTwiceAddsNothingAndAMovedAppReplacesItsOldHook() throws {
        let once = try CodexHooks.merged(theirs, hook: hook)
        let twice = try CodexHooks.merged(once, hook: hook)
        XCTAssertEqual(commands(twice, "Stop"), [CodexHooks.command(hook: hook)])
        let moved = try CodexHooks.merged(once, hook: "/Users/me/Applications/Deskling.app/Contents/Helpers/deskling-hook")
        XCTAssertEqual(commands(moved, "SessionStart").count, 2)
    }

    func testDisconnectingRemovesOnlyOurs() throws {
        let back = try CodexHooks.removed(try CodexHooks.merged(theirs, hook: hook))
        let hooks = try XCTUnwrap(back["hooks"] as? [String: Any])
        XCTAssertEqual(Set(hooks.keys), ["SessionStart", "SubagentStart"])
        XCTAssertEqual(commands(back, "SessionStart"), ["bash herdr-agent-state.sh session"])
        XCTAssertFalse(CodexHooks.isConnected(back))
    }

    func testAFileWeCannotReadIsLeftAlone() throws {
        let file = makeTempDirectory().appendingPathComponent("hooks.json")
        try Data("{ not json".utf8).write(to: file)
        XCTAssertThrowsError(try CodexHooks.update(file) { try CodexHooks.merged($0, hook: self.hook) })
        XCTAssertEqual(try String(contentsOf: file), "{ not json")
        XCTAssertThrowsError(try CodexHooks.merged(["hooks": ["Stop": "oops"]], hook: hook))
    }

    func testUpdateWritesTheFileAndKeepsABackup() throws {
        let file = makeTempDirectory().appendingPathComponent("hooks.json")
        let original = try JSONSerialization.data(withJSONObject: theirs)
        try original.write(to: file)
        try CodexHooks.update(file) { try CodexHooks.merged($0, hook: self.hook) }
        XCTAssertTrue(CodexHooks.connected(file))
        XCTAssertEqual(try Data(contentsOf: file.appendingPathExtension("before-deskling")), original)

        let fresh = makeTempDirectory().appendingPathComponent("codex/hooks.json")
        try CodexHooks.update(fresh) { try CodexHooks.merged($0, hook: self.hook) }
        XCTAssertTrue(CodexHooks.connected(fresh))
    }
}

@MainActor
final class PerformerAgentTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    private func makePerformer(cursor: @escaping () -> CGPoint = { CGPoint(x: -999, y: -999) }) -> (Performer, CharacterWindow) {
        let window = CharacterWindow(size: CharacterSize.medium.size)
        let performer = Performer(
            character: Character.clawd(directory: stagedAnimations()), window: window,
            settings: Settings(defaults: UserDefaults(suiteName: "clawd.tests.\(UUID().uuidString)")!),
            visibleFrame: { self.screen }, cursorLocation: cursor)
        return (performer, window)
    }

    func testAlertBringsHimToTheMiddleUntilCleared() async throws {
        let (performer, window) = makePerformer()
        defer { performer.stop() }
        performer.start()
        performer.alert("clawd needs you")
        try await Task.sleep(for: .milliseconds(700))

        XCTAssertEqual(window.frame.midX, screen.midX, accuracy: 2)
        XCTAssertEqual(performer.alertText, "clawd needs you")

        performer.clearAlert()
        XCTAssertNil(performer.alertText)
    }

    func testHeStopsToWatchANearbyCursor() async throws {
        var cursor = CGPoint(x: -999, y: -999)
        let (performer, window) = makePerformer(cursor: { cursor })
        defer { performer.stop() }
        performer.start()
        try await Task.sleep(for: .milliseconds(200))
        cursor = CGPoint(x: window.frame.minX - 20, y: window.frame.midY)
        try await Task.sleep(for: .milliseconds(400))

        let watching = window.origin
        XCTAssertEqual(window.facing, .left)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(window.origin, watching, "he should stand still while the cursor is close")
    }
}

final class ClawdHookTests: XCTestCase {
    /// Runs the built helper the way a hook does and listens for what it posts.
    func testHookBinaryPostsTheEventAndExitsCleanly() throws {
        let binary = URL(fileURLWithPath: "\(#filePath)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/debug/deskling-hook")
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: binary.path), "run swift build first")

        let session = UUID().uuidString
        let received = expectation(description: "event posted")
        let observer = DistributedNotificationCenter.default().addObserver(
            forName: AgentEvent.notificationName, object: nil, queue: .main
        ) { notification in
            guard let event = AgentEvent(userInfo: notification.userInfo), event.session == session else { return }
            XCTAssertEqual(event, AgentEvent(agent: "codex", kind: .needsInput, session: session, project: "api"))
            received.fulfill()
        }
        defer { DistributedNotificationCenter.default().removeObserver(observer) }

        let process = Process()
        process.executableURL = binary
        process.arguments = ["--agent", "codex"]
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        try process.run()
        input.fileHandleForWriting.write(Data(
            #"{"hook_event_name":"PermissionRequest","session_id":"\#(session)","cwd":"/w/api","tool_name":"Bash"}"#.utf8))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertTrue(output.fileHandleForReading.readDataToEndOfFile().isEmpty, "a hook's stdout can reach the agent")
        wait(for: [received], timeout: 3)
    }

    func testHookBinaryIgnoresGarbage() throws {
        let binary = URL(fileURLWithPath: "\(#filePath)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/debug/deskling-hook")
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: binary.path), "run swift build first")
        let process = Process()
        process.executableURL = binary
        let input = Pipe()
        process.standardInput = input
        try process.run()
        input.fileHandleForWriting.write(Data("not json".utf8))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }
}

@MainActor
final class DrawnCharacterTests: XCTestCase {
    /// Every character in apps/deskling/characters, as `make animations` stages them.
    func testEveryShippedCharacterLoadsAndRenders() throws {
        let staged = stagedAnimations().deletingLastPathComponent().appendingPathComponent("characters")
        let roster = Roster(clawdDirectory: stagedAnimations(), charactersDirectory: staged)
        let folders = (try? FileManager.default.contentsOfDirectory(atPath: staged.path)) ?? []
        XCTAssertEqual(roster.characters.count, folders.count + 1, "a staged character failed to load")

        for character in roster.characters.dropFirst() {
            let catalog = character.catalog
            let walking = try XCTUnwrap(catalog.load("walking"), character.id)
            XCTAssertGreaterThan(CGFloat(walking.frameCount), character.standingFrame, character.id)
            XCTAssertNotNil(catalog.load("waving"), "\(character.id) has no wave for the entrance")
            for name in catalog.names {
                let item = try XCTUnwrap(catalog.load(name), "\(character.id)/\(name)")
                let image = try XCTUnwrap(FrameRenderer.render(item.animation, frame: 0, pixelSize: CGSize(width: 275, height: 185)))
                XCTAssertGreaterThan(PixelStats(image).opaqueFraction, 0.005, "\(character.id)/\(name) is blank")
            }
        }
    }
}

@MainActor
final class SelectScreenTests: XCTestCase {
    private func roster() -> Roster {
        Roster(clawdDirectory: stagedAnimations(),
               charactersDirectory: stagedAnimations().deletingLastPathComponent().appendingPathComponent("characters"))
    }

    func testGeneratedIdleKeepsTheFeetPlanted() throws {
        let clawd = Character.clawd(directory: stagedAnimations())
        let frames = SelectFrames.ready(for: clawd)
        XCTAssertEqual(frames.count, SelectFrames.idleSteps.count)
        let still = PixelStats(frames[0]), crouched = PixelStats(frames[2])
        XCTAssertEqual(still.lowestOpaqueRow, crouched.lowestOpaqueRow, "feet stay on the floor")
        XCTAssertGreaterThan(try XCTUnwrap(crouched.highestOpaqueRow), try XCTUnwrap(still.highestOpaqueRow), "the crouch lowers the head")
    }

    func testEveryCharacterGetsAMenubarIcon() {
        for character in roster().characters {
            let icon = MenuIcon.make(for: character)
            XCTAssertNotNil(icon, character.id)
            XCTAssertLessThanOrEqual(icon?.size.height ?? 99, 18, character.id)
            XCTAssertTrue(icon?.isTemplate ?? false, character.id)
        }
    }

    /// Writes .build/select-screen.png and .build/menu-icons.png to look at.
    func testWritesSelectScreenAndIcons() throws {
        let characters = roster().characters
        var idle: [String: [CGImage]] = [:]
        for character in characters { idle[character.id] = SelectFrames.ready(for: character) }
        let screen = SelectScreen(characters: characters, welcome: true, selected: 1, choose: { _ in }, idle: idle)
        let renderer = ImageRenderer(content: screen)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage)
        let build = stagedAnimations().deletingLastPathComponent()
        try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            .write(to: build.appendingPathComponent("select-screen.png"))

        let icons = characters.compactMap { MenuIcon.make(for: $0) }
        let strip = NSImage(size: NSSize(width: icons.count * 40, height: 24), flipped: false) { _ in
            NSColor.white.setFill(); NSRect(x: 0, y: 0, width: icons.count * 40, height: 24).fill()
            for (index, icon) in icons.enumerated() {
                icon.draw(in: NSRect(x: CGFloat(index * 40) + 4, y: 3, width: icon.size.width, height: icon.size.height))
            }
            return true
        }
        let tiff = try XCTUnwrap(strip.tiffRepresentation)
        try XCTUnwrap(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
            .write(to: build.appendingPathComponent("menu-icons.png"))
    }
}
