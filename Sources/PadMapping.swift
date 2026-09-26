import Foundation

struct RGBChannels: Equatable {
    let red, green, blue: Double
}

struct MonsterColourPad {
    let name: String
    let key: String
    let note: UInt8
    let start, end: RGBChannels
    var red: Double { (start.red + end.red) / 2 }
    var green: Double { (start.green + end.green) / 2 }
    var blue: Double { (start.blue + end.blue) / 2 }
    var isGradient: Bool {
        start.red != end.red || start.green != end.green || start.blue != end.blue
    }
    static let all: [MonsterColourPad] = [
        solid("Red", key: "Q", note: 60, 1, 0, 0),
        solid("Green", key: "W", note: 61, 0, 1, 0),
        solid("Blue", key: "E", note: 62, 0, 0, 1),
        solid("Yellow", key: "R", note: 63, 1, 1, 0),
        solid("Cyan", key: "T", note: 64, 0, 1, 1),
        solid("Magenta", key: "Y", note: 65, 1, 0, 1),
        gradient("Orange", key: "A", note: 66, from: .init(red: 1, green: 0, blue: 0), to: .init(red: 1, green: 1, blue: 0)),
        gradient("Spring", key: "S", note: 67, from: .init(red: 0, green: 1, blue: 0), to: .init(red: 0, green: 1, blue: 1)),
        gradient("Violet", key: "D", note: 68, from: .init(red: 0, green: 0, blue: 1), to: .init(red: 1, green: 0, blue: 1))
    ]

    private static func solid(_ name: String, key: String, note: UInt8, _ red: Double, _ green: Double, _ blue: Double) -> MonsterColourPad {
        let colour = RGBChannels(red: red, green: green, blue: blue)
        return .init(name: name, key: key, note: note, start: colour, end: colour)
    }
    private static func gradient(_ name: String, key: String, note: UInt8, from: RGBChannels, to: RGBChannels) -> MonsterColourPad {
        .init(name: name, key: key, note: note, start: from, end: to)
    }
}

struct MIDINoteEvent: Equatable {
    let note: UInt8
    let pressed: Bool
}

enum MonsterPadTransition: Equatable {
    case none
    case colour(Int)
    case off
}

/// Tracks independent mouse, computer-keyboard and MIDI holds. The newest held
/// source controls the strip; releasing it restores the previous held pad, or
/// switches the strip off when no source remains.
struct MonsterMomentaryPads {
    private var held: [String: Int] = [:]
    private var order: [String] = []

    var activeIndex: Int? { order.last.flatMap { held[$0] } }
    var isEmpty: Bool { held.isEmpty }

    mutating func press(_ index: Int, source: String) -> MonsterPadTransition {
        guard MonsterColourPad.all.indices.contains(index) else { return .none }
        if held[source] == index, order.last == source { return .none }
        held[source] = index
        order.removeAll { $0 == source }
        order.append(source)
        return .colour(index)
    }

    mutating func release(source: String) -> MonsterPadTransition {
        guard held.removeValue(forKey: source) != nil else { return .none }
        order.removeAll { $0 == source }
        return activeIndex.map(MonsterPadTransition.colour) ?? .off
    }

    mutating func releaseAll() -> MonsterPadTransition {
        guard !held.isEmpty else { return .none }
        held.removeAll()
        order.removeAll()
        return .off
    }
}

// One parser per source; running status can span CoreMIDI packets.
struct MIDINoteParser {
    private var status: UInt8 = 0
    private var data: [UInt8] = []
    private var sysEx = false
    mutating func read(_ bytes: [UInt8]) -> [MIDINoteEvent] {
        var notes: [MIDINoteEvent] = []
        for byte in bytes {
            if byte >= 0xF8 { continue } // Realtime messages do not disturb running status.
            if byte & 0x80 != 0 {
                data.removeAll()
                if byte == 0xF0 { sysEx = true; status = 0 }
                else if byte >= 0xF0 { sysEx = false; status = 0 }
                else { sysEx = false; status = byte }
                continue
            }
            guard !sysEx, status >= 0x80 else { continue }
            data.append(byte)
            let needed = (status & 0xF0 == 0xC0 || status & 0xF0 == 0xD0) ? 1 : 2
            if data.count == needed {
                if status & 0xF0 == 0x90 {
                    notes.append(.init(note: data[0], pressed: data[1] > 0))
                } else if status & 0xF0 == 0x80 {
                    notes.append(.init(note: data[0], pressed: false))
                }
                data.removeAll()
            }
        }
        return notes
    }
}
