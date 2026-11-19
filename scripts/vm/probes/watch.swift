import AppKit

typealias MainConnection = @convention(c) () -> Int32
typealias CopySpaces = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
let h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)!
func sym<T>(_ n: String, _ t: T.Type) -> T { unsafeBitCast(dlsym(h, n)!, to: t) }
let cid = sym("SLSMainConnectionID", MainConnection.self)()
let copySpaces = sym("SLSCopySpacesForWindows", CopySpaces.self)

let dir = CommandLine.arguments[1]
let seconds = Double(CommandLine.arguments[2])!
let logURL = URL(fileURLWithPath: dir + "/watch.log")
FileManager.default.createFile(atPath: logURL.path, contents: nil)
let logHandle = try! FileHandle(forWritingTo: logURL)
let start = Date()
func log(_ s: String) {
    let t = String(format: "%7.1f", Date().timeIntervalSince(start))
    logHandle.write("\(t) \(s)\n".data(using: .utf8)!)
}

func orangePixels(_ path: String) -> Int {
    guard let rep = NSBitmapImageRep(data: (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()) else { return -1 }
    var n = 0
    for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
        for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
            guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
            let r = c.redComponent, g = c.greenComponent, b = c.blueComponent
            if abs(r - 0.85) < 0.06, abs(g - 0.47) < 0.06, abs(b - 0.34) < 0.06 { n += 1 }
        }
    }
    return n
}

var tick = 0
var lastLine = ""
func sample() {
    tick += 1
    let session = CGSessionCopyCurrentDictionary() as? [String: Any] ?? [:]
    let locked = (session["CGSSessionScreenIsLocked"] as? Bool) ?? false
    let asleep = CGDisplayIsAsleep(CGMainDisplayID()) != 0
    let all = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
    var clawd = ""
    var bounds = CGRect.zero
    for w in all where (w["kCGWindowOwnerName"] as? String) == "Clawd" {
        let b = CGRect(dictionaryRepresentation: w["kCGWindowBounds"] as! CFDictionary) ?? .zero
        guard (w["kCGWindowLayer"] as? Int) == 25, b.width >= 100, b.width <= 300 else { continue }
        let id = w["kCGWindowNumber"] as! Int
        let on = w["kCGWindowIsOnscreen"] as? Bool ?? false
        let spaces = { (mask: Int32) in (copySpaces(cid, mask, [NSNumber(value: id)] as CFArray)?.takeRetainedValue() as? [NSNumber] ?? []).map(\.stringValue).joined(separator: ",") }
        clawd += "win=\(id) layer=\(w["kCGWindowLayer"] ?? "?") onscreen=\(on) alpha=\(w["kCGWindowAlpha"] ?? "?") spaces7=[\(spaces(7))] spacesAll=[\(spaces(-1))] "
        bounds = b
    }
    let high = Set(all.filter { ($0["kCGWindowIsOnscreen"] as? Bool ?? false) && ($0["kCGWindowLayer"] as? Int ?? 0) >= 300 }
        .map { "\($0["kCGWindowOwnerName"] ?? "?")@\($0["kCGWindowLayer"] ?? 0)" }).sorted().joined(separator: " ")
    var line = "locked=\(locked) asleep=\(asleep) \(clawd)| high: \(high)"
    if tick % 4 == 0, bounds != .zero {
        let path = "\(dir)/shot.png"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x", "-R", "\(Int(bounds.minX)),\(Int(bounds.minY)),\(Int(bounds.width)),\(Int(bounds.height))", path]
        try? p.run(); p.waitUntilExit()
        let n = orangePixels(path)
        line += " | orange=\(n)"
        if tick % 40 == 0 { try? FileManager.default.copyItem(atPath: path, toPath: "\(dir)/shot-\(tick / 2)s.png") }
        log(line + String(format: " x=%.0f y=%.0f", bounds.minX, bounds.minY))
        return
    }
    if line != lastLine { log(line); lastLine = line }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let dnc = DistributedNotificationCenter.default()
for name in ["com.apple.screenIsLocked", "com.apple.screenIsUnlocked", "com.apple.screensaver.didstart", "com.apple.screensaver.didstop"] {
    dnc.addObserver(forName: .init(name), object: nil, queue: .main) { _ in log("EVENT \(name)") }
}
NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
    log("EVENT didChangeScreenParameters screens=\(NSScreen.screens.map { $0.frame })")
}
for (name, label) in [(NSWorkspace.didWakeNotification, "didWake"), (NSWorkspace.screensDidSleepNotification, "screensDidSleep"), (NSWorkspace.screensDidWakeNotification, "screensDidWake"), (NSWorkspace.willSleepNotification, "willSleep")] {
    NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { _ in log("EVENT \(label)") }
}
Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in sample() }
Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in exit(0) }
app.run()
