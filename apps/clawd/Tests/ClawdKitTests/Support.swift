import Foundation
import XCTest

/// The flat directory `make animations` stages from apps/website/assets.
func stagedAnimations(file: StaticString = #filePath, line: UInt = #line) -> URL {
    let packageRoot = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let directory = packageRoot.appendingPathComponent(".build/animations")
    if !FileManager.default.fileExists(atPath: directory.path) {
        XCTFail("Staged animations missing. Run `make check`.", file: file, line: line)
    }
    return directory
}

func makeTempDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("clawd-tests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
