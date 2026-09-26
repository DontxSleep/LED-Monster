import Foundation
import CoreMIDI
import Combine

@main struct MIDITests {
    static func main() {
        var parser = MIDINoteParser()
        precondition(parser.read([0x90, 60]).isEmpty)
        precondition(parser.read([100, 61, 0, 62, 0xF8, 100]) == [
            .init(note: 60, pressed: true), .init(note: 61, pressed: false), .init(note: 62, pressed: true)
        ])
        precondition(parser.read([0x80,60,100,0xB0,60,100,0xC0,60]) == [.init(note: 60, pressed: false)])
        precondition(parser.read([0xF0,0x01,60,100,0xF7,60,100]).isEmpty)
        precondition(parser.read([0x9F,65,1]) == [.init(note: 65, pressed: true)])

        var momentary = MonsterMomentaryPads()
        precondition(momentary.press(0, source: "q") == .colour(0) && momentary.activeIndex == 0)
        precondition(momentary.press(1, source: "w") == .colour(1) && momentary.activeIndex == 1)
        precondition(momentary.release(source: "w") == .colour(0) && momentary.activeIndex == 0)
        precondition(momentary.release(source: "q") == .off && momentary.activeIndex == nil)
        precondition(momentary.release(source: "q") == .none)
        precondition(momentary.press(2, source: "mouse-blue") == .colour(2))
        precondition(momentary.releaseAll() == .off && momentary.isEmpty)
        let expected = ["69 96 05 02 FF 00 00","69 96 05 02 00 FF 00","69 96 05 02 00 00 FF","69 96 05 02 FF FF 00","69 96 05 02 00 FF FF","69 96 05 02 FF 00 FF","69 96 05 02 FF 7F 00","69 96 05 02 00 FF 7F","69 96 05 02 7F 00 FF"]
        precondition(MonsterColourPad.all.map(\.key) == ["Q","W","E","R","T","Y","A","S","D"])
        for (index,pad) in MonsterColourPad.all.enumerated() {
            precondition(pad.note == 60 + index)
            precondition(BJLEDProtocol.colour(red: pad.red, green: pad.green, blue: pad.blue, brightness: 1)!.hex == expected[index])
        }
        let store = MIDIStore(name: "LED Monster Test")
        precondition(store.virtualInput != 0 && store.virtualOutput != 0)
        var received: [Int] = [], released: [Int] = []
        let onSubscription = store.noteOn.sink { received.append($0) }
        let offSubscription = store.noteOff.sink { released.append($0) }
        var client = MIDIClientRef(), output = MIDIPortRef(), input = MIDIPortRef()
        precondition(MIDIClientCreateWithBlock("LED Monster Test Sender" as CFString, &client, nil) == noErr)
        precondition(MIDIOutputPortCreate(client, "Sender" as CFString, &output) == noErr)
        var outgoingNotes: [UInt8] = []
        precondition(MIDIInputPortCreateWithBlock(client, "Observer" as CFString, &input, { packets,_ in
            let packet = packets.pointee.packet
            let bytes = withUnsafeBytes(of: packet.data) { Array($0.prefix(Int(packet.length))) }
            DispatchQueue.main.async { outgoingNotes += bytes }
        }) == noErr)
        precondition(MIDIPortConnectSource(input, store.virtualOutput, nil) == noErr)
        func transmit(_ bytes: [UInt8]) {
            var packets = MIDIPacketList()
            withUnsafeMutablePointer(to: &packets) { list in
                let first = MIDIPacketListInit(list)
                bytes.withUnsafeBufferPointer { buffer in
                    _ = MIDIPacketListAdd(list, MemoryLayout<MIDIPacketList>.size, first, 0, bytes.count, buffer.baseAddress!)
                }
                precondition(MIDISend(output, store.virtualInput, list) == noErr)
            }
        }
        transmit((60...68).flatMap { [UInt8(0x90), UInt8($0), UInt8(100)] })
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        precondition(received == [0,1,2,3,4,5,6,7,8], "Incoming MIDI did not map all nine pads: \(received)")
        transmit([0x80,60,100,0x90,61,0,0x90,59,100,0x90,69,100])
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        precondition(received.count == 9)
        precondition(released == [0,1], "Incoming note-off did not map to pad release: \(released)")
        store.enabled = false
        transmit([0x90,60,100,0x80,60,0])
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        precondition(received.count == 9 && released.count == 2)
        store.enabled = true
        store.sendPadDown(8)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        store.sendPadUp(8)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        precondition(outgoingNotes == [0x90,68,100,0x80,68,0], "Output must include matched note on/off: \(outgoingNotes)")
        precondition(received.count == 9, "Own output must not feed back into input")
        onSubscription.cancel(); offSubscription.cancel()
        MIDIClientDispose(client)
        print("PASS: momentary pad gate; six solid and three gradient-midpoint RGB fixtures; split/running-status MIDI; note-on and note-off mapping; disabled input; matched virtual output holds; no self-loop")
    }
}
