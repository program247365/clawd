@testable import DesklingKit
import XCTest

final class AgentAppTests: XCTestCase {
    func testOnlyAWarpSessionLinkIsEverOpened() {
        XCTAssertEqual(
            AgentApp.warpSession("warp://session/d550512df8c942dab6a54f43ee5c5d23")?.absoluteString,
            "warp://session/d550512df8c942dab6a54f43ee5c5d23")
        for bad in [nil, "", "warp://session/", "https://example.com", "warp://action/new_tab",
                    "warp://session/../x", "warp://session/abc?x=1", "file:///etc/passwd", "warp://session/é"] {
            XCTAssertNil(AgentApp.warpSession(bad), bad ?? "nil")
        }
    }

    func testTerminalIsOnlyEverAskedAboutAPlainTerminalDevice() throws {
        let script = try XCTUnwrap(AgentApp.terminalScript(tty: "/dev/ttys003"))
        XCTAssertTrue(script.contains(#"if tty of t is "/dev/ttys003" then"#))
        for bad in [nil, "", "/dev/ttys", "/dev/tty", "/dev/console", #"/dev/ttys1" & do shell script "x"#, "/dev/ttys0١"] {
            XCTAssertNil(AgentApp.terminalScript(tty: bad), bad ?? "nil")
        }
    }
}
