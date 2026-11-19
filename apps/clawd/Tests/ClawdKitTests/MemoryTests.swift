import ClawdKit
import Lottie
import QuartzCore
import XCTest

/// What Activity Monitor calls "Memory": the process's physical footprint, in megabytes.
func footprintMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
}

@MainActor
final class MemoryTests: XCTestCase {
    /// Lottie's default decoder needs about 190MB to parse the largest act and leaves about 80MB behind.
    /// Its Codable decoder needs about 25MB and renders every animation pixel-for-pixel the same.
    func testParsingTheLargestActStaysLight() throws {
        let directory = stagedAnimations()
        let largest = try XCTUnwrap(
            try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
                .filter { $0.pathExtension == "json" }
                .max { ((try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) < ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) })
        let before = footprintMB()

        let act = AnimationCatalog(directory: directory).load(largest.deletingPathExtension().lastPathComponent)

        XCTAssertNotNil(act)
        let grew = footprintMB() - before
        print(String(format: "parsing %@ grew memory by %.0f MB", largest.lastPathComponent, grew))
        XCTAssertLessThan(grew, 60)
    }

    /// Shows every animation in turn, the way the app does, for several rounds.
    /// A leak would make each round end higher than the last.
    ///
    /// The view is deliberately not in a window. In a test process a window's drawing work is never
    /// taken by the window server, so discarded layers pile up and look like a leak that the real app,
    /// measured over 100 minutes, does not have.
    func testShowingEveryActRepeatedlyDoesNotGrowMemory() {
        let catalog = AnimationCatalog(directory: stagedAnimations())
        let view = LottieAnimationView(configuration: FrameRenderer.configuration)
        view.frame = CGRect(origin: .zero, size: ClawdSize.medium.size)
        view.wantsLayer = true
        var afterEachRound: [Double] = []

        for _ in 0..<4 {
            for name in catalog.names {
                autoreleasepool {
                    guard let act = catalog.load(name) else { return }
                    view.animation = act.animation
                    view.currentFrame = 0
                    view.currentFrame = CGFloat(act.frameCount / 2)
                }
                CATransaction.flush()
                RunLoop.current.run(until: Date().addingTimeInterval(0.005))
                Memory.returnUnused()
            }
            afterEachRound.append(footprintMB())
        }

        print("memory after each round (MB):", afterEachRound.map { String(format: "%.1f", $0) })
        XCTAssertLessThan(afterEachRound[3] - afterEachRound[1], 3, "memory kept growing between rounds: \(afterEachRound)")
    }
}
