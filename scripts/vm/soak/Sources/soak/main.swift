import AppKit
import Lottie

// usage: soak <animations dir> <dict|legacy> <relief 0|1> <rounds> [lateLoad]
let args = CommandLine.arguments
let dir = URL(fileURLWithPath: args[1])
let strategy: DecodingStrategy = args[2] == "legacy" ? .legacyCodable : .dictionaryBased
let relief = args[3] == "1"
let rounds = Int(args[4])!

func footprintMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    _ = withUnsafeMutablePointer(to: &info) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) } }
    return Double(info.phys_footprint) / 1_048_576
}
func lifetimePeakMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    _ = withUnsafeMutablePointer(to: &info) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) } }
    return Double(info.ledger_phys_footprint_peak) / 1_048_576
}
func heapMB() -> (inUse: Double, reserved: Double) {
    var s = malloc_statistics_t()
    malloc_zone_statistics(nil, &s)
    return (Double(s.size_in_use) / 1_048_576, Double(s.size_allocated) / 1_048_576)
}
func load(_ name: String) -> LottieAnimation? {
    guard let data = try? Data(contentsOf: dir.appendingPathComponent("\(name).json")) else { return nil }
    return try? LottieAnimation.from(data: data, strategy: strategy)
}
func spin(_ s: TimeInterval) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let panel = NSPanel(contentRect: CGRect(x: 20, y: 120, width: 120, height: 81), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
panel.isOpaque = false; panel.backgroundColor = .clear; panel.level = .statusBar; panel.ignoresMouseEvents = true
let container = NSView(frame: panel.contentLayoutRect); container.wantsLayer = true
let view = LottieAnimationView(configuration: LottieConfiguration(renderingEngine: .mainThread))
view.frame = container.bounds; view.contentMode = .scaleAspectFit
container.addSubview(view); panel.contentView = container
panel.orderFrontRegardless()

let names = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
    .filter { $0.pathExtension == "json" }.map { $0.deletingPathExtension().lastPathComponent }.filter { $0 != "walking" }.sorted()
let walking = load("walking")!
view.animation = walking; view.currentFrame = 26
spin(0.5)
print(String(format: "start: footprint %.1f MB", footprintMB()))
var peak = 0.0
for round in 1...rounds {
    for name in names {
        var act: LottieAnimation?
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async { act = load(name); done.signal() }
        while done.wait(timeout: .now()) == .timedOut { spin(0.005) }
        guard let a = act else { continue }
        view.animation = a
        var f = a.startFrame
        while f < a.endFrame { view.currentFrame = f; spin(0.004); f += 6 }
        peak = max(peak, footprintMB())
        view.animation = walking; view.currentFrame = 26
        act = nil
        spin(0.01)
        if relief { malloc_zone_pressure_relief(nil, 0) }
    }
    spin(0.3)
    let h = heapMB()
    print(String(format: "round %2d: footprint %5.1f MB  peak %5.1f  heap in use %5.1f  heap reserved %5.1f", round, footprintMB(), peak, h.inUse, h.reserved))
    fflush(stdout)
}

print(String(format: "lifetime peak %.1f MB", lifetimePeakMB()))
