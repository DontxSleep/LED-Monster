import Foundation
@main struct ProtocolTests {
    static func main() {
        precondition(BJLEDProtocol.power(true).hex == "69 96 02 01 01")
        precondition(BJLEDProtocol.power(false).hex == "69 96 02 01 00")
        let red = BJLEDProtocol.colour(red: 1, green: 0, blue: 0, brightness: 1)!
        let green = BJLEDProtocol.colour(red: 0, green: 1, blue: 0, brightness: 1)!
        precondition(red.hex == "69 96 05 02 FF 00 00")
        precondition(green.hex == "69 96 05 02 00 FF 00")
        precondition(BJLEDProtocol.colour(red: 0, green: 0, blue: 1, brightness: 1)!.hex == "69 96 05 02 00 00 FF")
        precondition(BJLEDProtocol.colour(red: 1, green: 1, blue: 1, brightness: 0.5)!.hex == "69 96 05 02 7F 7F 7F")
        precondition(BJLEDProtocol.colour(red: 1, green: 1, blue: 1, brightness: 0)!.hex == "69 96 05 02 00 00 00")
        precondition(BJLEDProtocol.colour(red: .nan, green: 0, blue: 0, brightness: 1) == nil)
        precondition(BJLEDProtocol.colour(red: 1, green: 0, blue: 0, brightness: 1.1) == nil)
        precondition(BJLEDProtocol.matches(name: "BJ_LED_M", service: "EEA0", characteristic: "EE01", withoutResponse: true))
        precondition(BJLEDProtocol.matches(name: "BJ_LED_M", service: "0000eea0-0000-1000-8000-00805f9b34fb", characteristic: "0000ee01-0000-1000-8000-00805f9b34fb", withoutResponse: true))
        precondition(!BJLEDProtocol.matches(name: "iPhone", service: "EEA0", characteristic: "EE01", withoutResponse: true))
        precondition(!BJLEDProtocol.matches(name: "BJ_LED_M", service: "EEA0", characteristic: "EE02", withoutResponse: true))
        precondition(!BJLEDProtocol.matches(name: "BJ_LED_M", service: "EEA0", characteristic: "EE01", withoutResponse: false))
        precondition(!BJLEDProtocol.matches(name: "BJ_LED_M", service: "0000eea0-0000-1000-2000-00805f9b34fb", characteristic: "EE01", withoutResponse: true))
        var buffer = LightCommandBuffer()
        buffer.colour(red, turnOn: true)
        buffer.colour(green, turnOn: false)
        precondition(buffer.items.count == 2)
        precondition(buffer.pop()?.packet == BJLEDProtocol.power(true))
        precondition(buffer.pop()?.packet == green)
        precondition(buffer.pop() == nil)
        buffer.colour(red, turnOn: true); buffer.power(false)
        precondition(buffer.items.count == 1)
        precondition(buffer.pop()?.packet == BJLEDProtocol.power(false))
        buffer.colour(red, turnOn: true); buffer.clear()
        precondition(buffer.pop() == nil)
        print("PASS: documented packet fixtures, RGB scaling, invalid inputs, GATT/name gates, ordering, coalescing, power-off priority and disconnect queue clearing")
    }
}
