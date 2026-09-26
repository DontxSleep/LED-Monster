import Foundation

/// Interoperability facts, independently encoded. Sources and revisions: PROTOCOL.md.
enum BJLEDProtocol {
    static let serviceUUID = "EEA0"
    static let commandUUID = "EE01"
    static let name = "BJ_LED_M"
    static func power(_ on: Bool) -> Data { Data([0x69, 0x96, 0x02, 0x01, on ? 0x01 : 0x00]) }
    static func colour(red: Double, green: Double, blue: Double, brightness: Double) -> Data? {
        guard [red, green, blue, brightness].allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return nil }
        // Brightness is software scaling, not an unverified eighth byte.
        let channel: (Double) -> UInt8 = { UInt8(($0 * 255 * brightness).rounded(.down)) }
        return Data([0x69, 0x96, 0x05, 0x02, channel(red), channel(green), channel(blue)])
    }
    static func shortUUID(_ value: String) -> String {
        let upper = value.uppercased()
        let suffix = "-0000-1000-8000-00805F9B34FB"
        if upper.hasPrefix("0000"), upper.count == 36, upper.hasSuffix(suffix) {
            return String(upper.dropFirst(4).prefix(4))
        }
        return upper
    }
    static func matches(name: String?, service: String, characteristic: String, withoutResponse: Bool) -> Bool {
        name == Self.name && shortUUID(service) == serviceUUID && shortUUID(characteristic) == commandUUID && withoutResponse
    }
}
struct LightCommand: Equatable {
    enum Kind { case power, colour }
    let kind: Kind
    let packet: Data
    let label: String
}
/// Bounded, ordered pending work. A new intent replaces unsent colour changes;
/// power-off takes precedence, so no stale power-on/colour survives it.
struct LightCommandBuffer {
    private(set) var items: [LightCommand] = []
    mutating func power(_ on: Bool) {
        items.removeAll()
        items.append(LightCommand(kind: .power, packet: BJLEDProtocol.power(on), label: on ? "Power on" : "Power off"))
    }
    mutating func colour(_ data: Data, turnOn: Bool) {
        items.removeAll { $0.kind == .colour }
        if turnOn { power(true) }
        items.append(LightCommand(kind: .colour, packet: data, label: "Colour and brightness"))
    }
    mutating func pop() -> LightCommand? { items.isEmpty ? nil : items.removeFirst() }
    mutating func clear() { items.removeAll() }
}

/// Common modes keep BLE writes running while AppKit tracks an active knob drag.
enum ControlWriteClock {
    static func schedule(_ action: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: 0.12, repeats: true) { _ in action() }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
