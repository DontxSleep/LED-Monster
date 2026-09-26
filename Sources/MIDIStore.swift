import Foundation
import Combine
import CoreMIDI

final class MIDIStore: ObservableObject {
    @Published var enabled = true
    @Published private(set) var sources: [String] = []
    @Published private(set) var status = "Starting MIDI…"
    @Published private(set) var lastNote = "No MIDI note received"
    let noteOn = PassthroughSubject<Int, Never>()
    let noteOff = PassthroughSubject<Int, Never>()
    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private(set) var virtualInput = MIDIEndpointRef()
    private(set) var virtualOutput = MIDIEndpointRef()
    private var connectedSources = Set<MIDIEndpointRef>()
    private let lock = NSLock()
    private var parsers: [UInt: MIDINoteParser] = [:]

    init(name: String = "LED MØNSTER") {
        let result = MIDIClientCreateWithBlock(name as CFString, &client) { [weak self] notification in
            if notification.pointee.messageID == .msgObjectAdded || notification.pointee.messageID == .msgObjectRemoved {
                DispatchQueue.main.async { self?.refreshSources() }
            }
        }
        guard result == noErr else { status = "MIDI unavailable (\(result))"; return }
        var code = MIDIInputPortCreateWithBlock(client, "Pad input" as CFString, &port) { [weak self] packets, context in
            self?.receive(packets, source: context.map { UInt(bitPattern: $0) } ?? 0)
        }
        guard code == noErr else { status = "MIDI input unavailable (\(code))"; return }
        code = MIDIDestinationCreateWithBlock(client, "\(name) Input" as CFString, &virtualInput) { [weak self] packets, _ in
            self?.receive(packets, source: 0)
        }
        guard code == noErr else { status = "Virtual MIDI input unavailable (\(code))"; return }
        code = MIDISourceCreate(client, "\(name) Pads" as CFString, &virtualOutput)
        guard code == noErr else { status = "Virtual MIDI output unavailable (\(code))"; return }
        refreshSources()
    }
    func refreshSources() {
        guard port != 0 else { return }
        let available = Set((0..<MIDIGetNumberOfSources()).map { MIDIGetSource($0) }.filter { $0 != virtualOutput && $0 != 0 })
        for endpoint in connectedSources.subtracting(available) { MIDIPortDisconnectSource(port, endpoint) }
        connectedSources.formIntersection(available)
        var failed = false
        for endpoint in available.subtracting(connectedSources) {
            if MIDIPortConnectSource(port, endpoint, UnsafeMutableRawPointer(bitPattern: UInt(endpoint))) == noErr {
                connectedSources.insert(endpoint)
            } else { failed = true }
        }
        lock.lock()
        parsers = parsers.filter { $0.key == 0 || connectedSources.contains(MIDIEndpointRef($0.key)) }
        lock.unlock()
        sources = connectedSources.map { endpoint in
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
            return name?.takeRetainedValue() as String? ?? "MIDI keyboard"
        }.sorted()
        status = failed ? "Some MIDI inputs could not connect" : "MIDI ready · notes 60–68"
    }
    private func receive(_ packets: UnsafePointer<MIDIPacketList>, source: UInt) {
        var notes: [MIDINoteEvent] = []
        lock.lock()
        var parser = parsers[source] ?? MIDINoteParser()
        do {
            var packet = UnsafeRawPointer(packets).advanced(by: MemoryLayout<MIDIPacketList>.offset(of: \.packet)!).assumingMemoryBound(to: MIDIPacket.self)
            for _ in 0..<packets.pointee.numPackets {
                let bytes = UnsafeRawPointer(packet).advanced(by: MemoryLayout<MIDIPacket>.offset(of: \.data)!).assumingMemoryBound(to: UInt8.self)
                notes += parser.read(Array(UnsafeBufferPointer(start: bytes, count: Int(packet.pointee.length))))
                packet = UnsafePointer(MIDIPacketNext(packet))
            }
        }
        parsers[source] = parser
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.enabled else { return }
            for event in notes {
                guard let index = MonsterColourPad.all.firstIndex(where: { $0.note == event.note }) else { continue }
                self.lastNote = "Note \(event.note) \(event.pressed ? "on" : "off") → \(MonsterColourPad.all[index].name)"
                if event.pressed { self.noteOn.send(index) }
                else { self.noteOff.send(index) }
            }
        }
    }
    // Only mouse/QWERTY triggers publish output. Received MIDI is never echoed.
    func sendPadDown(_ index: Int) {
        guard enabled, MonsterColourPad.all.indices.contains(index), virtualOutput != 0 else { return }
        let note = MonsterColourPad.all[index].note
        send([0x90, note, 100])
    }
    func sendPadUp(_ index: Int) {
        guard enabled, MonsterColourPad.all.indices.contains(index), virtualOutput != 0 else { return }
        send([0x80, MonsterColourPad.all[index].note, 0])
    }
    func sendAllPadsOff() {
        guard enabled else { return }
        for index in MonsterColourPad.all.indices { sendPadUp(index) }
    }
    private func send(_ bytes: [UInt8]) {
        guard virtualOutput != 0 else { return }
        var packets = MIDIPacketList()
        withUnsafeMutablePointer(to: &packets) { list in
            let first = MIDIPacketListInit(list)
            bytes.withUnsafeBufferPointer { buffer in
                _ = MIDIPacketListAdd(list, MemoryLayout<MIDIPacketList>.size, first, 0, bytes.count, buffer.baseAddress!)
            }
            let result = MIDIReceived(virtualOutput, list)
            if result != noErr { status = "MIDI output error (\(result))" }
        }
    }
    deinit { if client != 0 { MIDIClientDispose(client) } }
}
