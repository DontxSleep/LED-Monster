import Foundation
import CoreFoundation

@main struct LiveBrightnessTests {
    static func main() {
        let trackingMode = CFRunLoopMode(rawValue: "NSEventTrackingRunLoopMode" as CFString)
        CFRunLoopAddCommonMode(CFRunLoopGetMain(), trackingMode)
        var buffer = LightCommandBuffer()
        var sent: [Data] = []
        let timer = ControlWriteClock.schedule {
            if let value = buffer.pop() { sent.append(value.packet) }
        }
        defer { timer.invalidate() }
        // Model pointer updates between timer ticks, without leaving tracking mode.
        for step in [1.0, 0.8, 0.6, 0.4, 0.2, 0.0] {
            for value in [min(1, step + 0.05), step] {
                buffer.colour(BJLEDProtocol.colour(red: 1, green: 0, blue: 0, brightness: value)!, turnOn: false)
            }
            CFRunLoopRunInMode(trackingMode, 0.14, false)
        }
        precondition(sent.count == 6, "Writer stalled during mouse tracking: \(sent.count)")
        precondition(sent.first!.hex == "69 96 05 02 FF 00 00")
        precondition(sent.last!.hex == "69 96 05 02 00 00 00")
        precondition(zip(sent, sent.dropFirst()).allSatisfy { $0[4] > $1[4] })
        precondition(buffer.items.isEmpty)
        print("PASS: live writes during mouse-tracking mode; brightness decreases through six steps to zero; pending values coalesce without a release event")
    }
}
