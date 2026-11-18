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

/// SplitMix64, so randomized tests are repeatable.
struct Seeded: RandomNumberGenerator {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
