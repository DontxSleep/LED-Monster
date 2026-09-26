import Foundation
@main struct ModelTests {
    static func main() throws {
        let originals = LightScene.defaults
        let data = try JSONEncoder().encode(originals)
        let decoded = try LightScene.decode(data)
        precondition(decoded == originals)
        var malformed = originals[0]; malformed.red = 3
        do { _ = try LightScene.decode(JSONEncoder().encode([malformed])); fatalError("Invalid channel accepted") } catch {}
        do { _ = try LightScene.decode(JSONEncoder().encode([originals[0], originals[0]])); fatalError("Duplicate scene accepted") } catch {}
        precondition(Data([0x00, 0xFF, 0x80]).hex == "00 FF 80")
        precondition(Data().hex == "")
        let report = DiscoveryReport(adapter: "Not started", device: nil, nearbyDevices: [], services: [], logs: [])
        let json = try JSONSerialization.jsonObject(with: report.encoded()) as! [String: Any]
        precondition(json["protocolStatus"] as? String == "unidentified")
        precondition(json["referenceAppDoesNotIdentifyConnectedDevice"] as? Bool == true)
        precondition((json["nearbyDevices"] as? [Any])?.isEmpty == true)
        print("PASS: scene persistence, invalid values, duplicate IDs, exact byte encoding, unidentified report")
    }
}
