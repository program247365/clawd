import AppKit
import AVFoundation
import ScreenCaptureKit

// usage: rec <owner pid> <seconds> <out.mov>   Records one window by itself, whatever is on top of it.
_ = NSApplication.shared
let pid = pid_t(CommandLine.arguments[1])!, seconds = Double(CommandLine.arguments[2])!
let out = URL(fileURLWithPath: CommandLine.arguments[3])
try? FileManager.default.removeItem(at: out)

final class Sink: NSObject, SCStreamOutput {
    let writer: AVAssetWriter, input: AVAssetWriterInput
    var started = false
    init(writer: AVAssetWriter, input: AVAssetWriterInput) { self.writer = writer; self.input = input }
    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid,
              let info = (CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]])?.first,
              let raw = info[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete else { return }
        if !started { writer.startSession(atSourceTime: buffer.presentationTimeStamp); started = true }
        if input.isReadyForMoreMediaData { input.append(buffer) }
    }
}

let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
guard let window = content.windows.filter({ $0.owningApplication?.processID == pid && $0.frame.height > 200 }).max(by: { $0.frame.width < $1.frame.width }) else {
    print("no window"); exit(1)
}
let config = SCStreamConfiguration()
let filter = SCContentFilter(desktopIndependentWindow: window)
config.width = Int(window.frame.width * CGFloat(filter.pointPixelScale)); config.height = Int(window.frame.height * CGFloat(filter.pointPixelScale))
config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
config.showsCursor = false
let writer = try AVAssetWriter(outputURL: out, fileType: .mov)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: config.width, AVVideoHeightKey: config.height])
input.expectsMediaDataInRealTime = true
writer.add(input); writer.startWriting()
let sink = Sink(writer: writer, input: input)
let stream = SCStream(filter: filter, configuration: config, delegate: nil)
try stream.addStreamOutput(sink, type: .screen, sampleHandlerQueue: DispatchQueue(label: "rec"))
try await stream.startCapture()
print("recording \(window.frame.size) for \(seconds)s")
try await Task.sleep(nanoseconds: UInt64(seconds * 1e9))
try await stream.stopCapture()
input.markAsFinished(); await writer.finishWriting()
print("done", writer.status.rawValue)
