import Foundation

struct LightScene: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var red: Double
    var green: Double
    var blue: Double
    var brightness: Double
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 32 &&
        [red, green, blue, brightness].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }
    static let defaults = [
        LightScene(name: "Warm evening", red: 1, green: 0.48, blue: 0.16, brightness: 0.75),
        LightScene(name: "Ocean", red: 0.12, green: 0.60, blue: 1, brightness: 0.80),
        LightScene(name: "Soft rose", red: 1, green: 0.32, blue: 0.52, brightness: 0.60)
    ]
    static func decode(_ data: Data) throws -> [LightScene] {
        let scenes = try JSONDecoder().decode([LightScene].self, from: data)
        guard scenes.count <= 24, scenes.allSatisfy(\.isValid), Set(scenes.map(\.id)).count == scenes.count else {
            throw CocoaError(.coderReadCorrupt)
        }
        return scenes
    }
}
struct LogEntry: Codable, Identifiable {
    var id = UUID()
    var time = Date()
    var event: String
    var details: String
}
struct DeviceRecord: Codable, Identifiable {
    var id: UUID
    var name: String
    var rssi: Int?
    var connectable: Bool
    var advertisedServices: [String]
    var manufacturerDataHex: String?
    var serviceDataHex: [String: String]
}
struct CharacteristicRecord: Codable, Identifiable {
    var id: String
    var uuid: String
    var serviceUUID: String
    var properties: [String]
    var notifying: Bool
    var valueHex: String?
}
struct ServiceRecord: Codable, Identifiable {
    var id: String
    var uuid: String
    var primary: Bool
    var characteristics: [CharacteristicRecord]
}
struct DiscoveryReport: Encodable {
    let schemaVersion = 2
    var protocolStatus = "unidentified"
    let referenceApp = "MohuanLED 1.4.7 (961) — com.kimoji.flutter.bleled"
    let referenceAppDoesNotIdentifyConnectedDevice = true
    var capturedAt = Date()
    var adapter: String
    var device: DeviceRecord?
    var nearbyDevices: [DeviceRecord]
    var services: [ServiceRecord]
    var logs: [LogEntry]
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}
extension Data {
    var hex: String { map { String(format: "%02X", $0) }.joined(separator: " ") }
}
