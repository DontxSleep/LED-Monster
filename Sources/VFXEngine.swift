import Combine
import Foundation

struct LEDMonsterVFXColour: Identifiable, Equatable {
    let id: String
    let name: String
    let red: Double
    let green: Double
    let blue: Double

    init(id: String, name: String, red: Double, green: Double, blue: Double) {
        self.id = id
        self.name = name
        self.red = red
        self.green = green
        self.blue = blue
    }

    static let black = LEDMonsterVFXColour(id: "black", name: "Black", red: 0, green: 0, blue: 0)

    /// Sixteen fixed sRGB choices for the VFX colour-picker. These are UI/source
    /// colours only; the existing BJLEDProtocol colour command remains unchanged.
    static let palette: [LEDMonsterVFXColour] = [
        .init(id: "red", name: "Red", red: 1, green: 0, blue: 0),
        .init(id: "orange", name: "Orange", red: 1, green: 0.25, blue: 0),
        .init(id: "amber", name: "Amber", red: 1, green: 127.0 / 255.0, blue: 0),
        .init(id: "yellow", name: "Yellow", red: 1, green: 1, blue: 0),
        .init(id: "lime", name: "Lime", red: 127.0 / 255.0, green: 1, blue: 0),
        .init(id: "green", name: "Green", red: 0, green: 1, blue: 0),
        .init(id: "spring", name: "Spring", red: 0, green: 1, blue: 127.0 / 255.0),
        .init(id: "cyan", name: "Cyan", red: 0, green: 1, blue: 1),
        .init(id: "azure", name: "Azure", red: 0, green: 127.0 / 255.0, blue: 1),
        .init(id: "blue", name: "Blue", red: 0, green: 0, blue: 1),
        .init(id: "violet", name: "Violet", red: 127.0 / 255.0, green: 0, blue: 1),
        .init(id: "magenta", name: "Magenta", red: 1, green: 0, blue: 1),
        .init(id: "rose", name: "Rose", red: 1, green: 0, blue: 127.0 / 255.0),
        .init(id: "pink", name: "Pink", red: 1, green: 0.4, blue: 0.8),
        .init(id: "warm-white", name: "Warm White", red: 1, green: 214.0 / 255.0, blue: 160.0 / 255.0),
        .init(id: "white", name: "White", red: 1, green: 1, blue: 1)
    ]

    static func mixed(from: LEDMonsterVFXColour, to: LEDMonsterVFXColour, amount: Double) -> LEDMonsterVFXColour {
        let amount = min(1, max(0, amount))
        let blend: (Double, Double) -> Double = { start, end in start + ((end - start) * amount) }
        return .init(id: "fade", name: "Fade", red: blend(from.red, to.red),
                     green: blend(from.green, to.green), blue: blend(from.blue, to.blue))
    }
}

enum LEDMonsterVFXMode: String, CaseIterable, Identifiable {
    case flashOne = "Colour Flash 1"
    case quick = "Colour Flash Quick"
    case slow = "Colour Flash Slow"
    case fade = "Colour Flash Fade"
    case jump = "Colour Flash Jump"

    var id: String { rawValue }
}

struct LEDMonsterVFXFrame: Equatable {
    let colour: LEDMonsterVFXColour
    let duration: TimeInterval
}

/// Pure pattern state, kept separate from timers so every mode can be tested
/// deterministically and the UI can change without touching the sequence rules.
struct LEDMonsterVFXPattern {
    private(set) var mode: LEDMonsterVFXMode
    private var lastRandomIndex: Int?
    private var pulseIsDark = false
    private var fadeFrom: LEDMonsterVFXColour?
    private var fadeTo: LEDMonsterVFXColour?
    private var fadeStep = 0
    private var fadeSteps = 0

    init(mode: LEDMonsterVFXMode) {
        self.mode = mode
    }

    mutating func reset(mode: LEDMonsterVFXMode? = nil) {
        if let mode { self.mode = mode }
        lastRandomIndex = nil
        pulseIsDark = false
        fadeFrom = nil
        fadeTo = nil
        fadeStep = 0
        fadeSteps = 0
    }

    mutating func next(colours: [LEDMonsterVFXColour], bpm: Double,
                       randomIndex: (Int) -> Int) -> LEDMonsterVFXFrame? {
        guard !colours.isEmpty, bpm.isFinite, bpm > 0 else { return nil }
        let beat = 60.0 / bpm

        switch mode {
        case .flashOne:
            return nextPulse(colours, duration: beat * 0.5, randomIndex: randomIndex)

        case .quick:
            return nextPulse(colours, duration: beat * 0.25, randomIndex: randomIndex)

        case .slow:
            return nextPulse(colours, duration: beat, randomIndex: randomIndex)

        case .jump:
            return .init(colour: chooseRandom(colours, randomIndex: randomIndex), duration: beat)

        case .fade:
            // Do not generate fade updates faster than the app's verified 120ms
            // BLE write clock. Faster intermediate values would only be coalesced.
            if fadeFrom == nil {
                let first = chooseRandom(colours, randomIndex: randomIndex)
                fadeFrom = first
                return .init(colour: first, duration: max(0.12, beat / 4))
            }
            if fadeTo == nil {
                fadeTo = chooseRandom(colours, randomIndex: randomIndex)
                fadeSteps = max(2, Int(floor(beat / 0.12)))
                fadeStep = 0
            }
            guard let from = fadeFrom, let to = fadeTo else { return nil }
            fadeStep += 1
            let frame = LEDMonsterVFXFrame(
                colour: .mixed(from: from, to: to, amount: Double(fadeStep) / Double(fadeSteps)),
                duration: max(0.12, beat / Double(fadeSteps))
            )
            if fadeStep >= fadeSteps {
                fadeFrom = to
                fadeTo = nil
            }
            return frame
        }
    }

    private mutating func nextPulse(_ colours: [LEDMonsterVFXColour], duration: TimeInterval,
                                    randomIndex: (Int) -> Int) -> LEDMonsterVFXFrame {
        let colour: LEDMonsterVFXColour
        if pulseIsDark {
            colour = .black
        } else {
            colour = chooseRandom(colours, randomIndex: randomIndex)
        }
        pulseIsDark.toggle()
        return .init(colour: colour, duration: max(0.12, duration))
    }

    private mutating func chooseRandom(_ colours: [LEDMonsterVFXColour],
                                       randomIndex: (Int) -> Int) -> LEDMonsterVFXColour {
        guard colours.count > 1 else {
            lastRandomIndex = 0
            return colours[0]
        }
        var index = randomIndex(colours.count)
        index = min(colours.count - 1, max(0, index))
        if index == lastRandomIndex { index = (index + 1) % colours.count }
        lastRandomIndex = index
        return colours[index]
    }
}

struct LEDMonsterTapTempo {
    static let bpmRange = 30.0...300.0
    private var lastTap: TimeInterval?
    private var intervals: [TimeInterval] = []

    mutating func reset() {
        lastTap = nil
        intervals.removeAll()
    }

    mutating func recordTap(at time: TimeInterval) -> Double? {
        guard time.isFinite else { return nil }
        guard let previous = lastTap else {
            lastTap = time
            return nil
        }
        let interval = time - previous
        let shortest = 60.0 / Self.bpmRange.upperBound
        let longest = 60.0 / Self.bpmRange.lowerBound
        if interval > longest {
            lastTap = time
            intervals.removeAll()
            return nil
        }
        // Ignore an accidental double-tap instead of letting it disturb the
        // current tempo or the timestamp used by the next intentional tap.
        guard interval >= shortest else { return measuredBPM }
        lastTap = time
        intervals.append(interval)
        if intervals.count > 6 { intervals.removeFirst(intervals.count - 6) }
        return measuredBPM
    }

    private var measuredBPM: Double? {
        guard !intervals.isEmpty else { return nil }
        let sorted = intervals.sorted()
        let middle = sorted.count / 2
        let median = sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
        return min(Self.bpmRange.upperBound, max(Self.bpmRange.lowerBound, 60.0 / median))
    }
}

final class LEDMonsterVFXCancellation {
    private var action: (() -> Void)?
    init(_ action: @escaping () -> Void) { self.action = action }
    func cancel() { action?(); action = nil }
    deinit { cancel() }
}

struct LEDMonsterVFXScheduler {
    let schedule: (TimeInterval, @escaping () -> Void) -> LEDMonsterVFXCancellation

    static let mainRunLoop = LEDMonsterVFXScheduler { delay, action in
        let timer = Timer(timeInterval: max(0.001, delay), repeats: false) { _ in action() }
        RunLoop.main.add(timer, forMode: .common)
        return LEDMonsterVFXCancellation { timer.invalidate() }
    }
}

/// UI-facing VFX state. `output` is the only hardware integration point:
/// wire it to BluetoothStore.setColour(red:green:blue:brightness:).
@MainActor
final class LEDMonsterVFXController: ObservableObject {
    @Published var mode: LEDMonsterVFXMode = .flashOne {
        didSet { if oldValue != mode { reconfigureRunningPattern() } }
    }
    @Published var bpm: Double = 120 {
        didSet {
            let clamped = min(LEDMonsterTapTempo.bpmRange.upperBound,
                              max(LEDMonsterTapTempo.bpmRange.lowerBound, bpm.isFinite ? bpm : 120))
            guard bpm == clamped else {
                bpm = clamped
                return
            }
            if oldValue != clamped { reconfigureRunningPattern() }
        }
    }
    @Published var brightness: Double = 1 {
        didSet {
            let clamped = min(1, max(0, brightness.isFinite ? brightness : 1))
            guard brightness == clamped else {
                brightness = clamped
                return
            }
            if oldValue != clamped, isRunning, let currentColour {
                output?(currentColour, clamped)
            }
        }
    }
    @Published private(set) var selectedColourIDs: [String]
    @Published private(set) var isRunning = false
    @Published private(set) var status = "Four colours ready · choose an effect, then start VFX."
    @Published private(set) var currentColour: LEDMonsterVFXColour?

    var output: ((LEDMonsterVFXColour, Double) -> Void)?

    var selectedColours: [LEDMonsterVFXColour] {
        selectedColourIDs.compactMap { id in LEDMonsterVFXColour.palette.first { $0.id == id } }
    }

    private let scheduler: LEDMonsterVFXScheduler
    private let randomIndex: (Int) -> Int
    private var scheduled: LEDMonsterVFXCancellation?
    private var pattern: LEDMonsterVFXPattern
    private var tapTempo = LEDMonsterTapTempo()
    private var generation = 0

    init(
        selectedColourIDs: [String] = ["red", "green", "blue", "yellow"],
        scheduler: LEDMonsterVFXScheduler = .mainRunLoop,
        randomIndex: @escaping (Int) -> Int = { Int.random(in: 0..<$0) }
    ) {
        let validUnique = selectedColourIDs.reduce(into: [String]()) { result, id in
            if result.count < 4, !result.contains(id), LEDMonsterVFXColour.palette.contains(where: { $0.id == id }) {
                result.append(id)
            }
        }
        self.selectedColourIDs = validUnique.count == 4 ? validUnique : ["red", "green", "blue", "yellow"]
        self.scheduler = scheduler
        self.randomIndex = randomIndex
        self.pattern = LEDMonsterVFXPattern(mode: .flashOne)
    }

    @discardableResult
    func chooseExactlyFour(_ ids: [String]) -> Bool {
        let unique = ids.reduce(into: [String]()) { result, id in
            if !result.contains(id), LEDMonsterVFXColour.palette.contains(where: { $0.id == id }) {
                result.append(id)
            }
        }
        guard unique.count == 4 else {
            status = "Choose exactly four different colours."
            return false
        }
        selectedColourIDs = unique
        status = "Four colours ready."
        reconfigureRunningPattern()
        return true
    }

    @discardableResult
    func toggleColour(id: String) -> Bool {
        guard LEDMonsterVFXColour.palette.contains(where: { $0.id == id }) else { return false }
        if let index = selectedColourIDs.firstIndex(of: id) {
            selectedColourIDs.remove(at: index)
            if isRunning { stop(reason: "VFX stopped · choose four colours.") }
            else { status = "\(selectedColourIDs.count) of 4 colours selected." }
            return true
        }
        guard selectedColourIDs.count < 4 else {
            status = "Four colours are already selected."
            return false
        }
        selectedColourIDs.append(id)
        status = selectedColourIDs.count == 4 ? "Four colours ready." : "\(selectedColourIDs.count) of 4 colours selected."
        return true
    }

    @discardableResult
    func start() -> Bool {
        guard selectedColours.count == 4 else {
            status = "Choose exactly four different colours."
            return false
        }
        stopScheduledWork()
        generation += 1
        pattern.reset(mode: mode)
        isRunning = true
        status = "Running · \(mode.rawValue)"
        emitNext(generation: generation)
        return true
    }

    func stop() { stop(reason: "VFX stopped.") }

    func tap(at date: Date = Date()) {
        if let measured = tapTempo.recordTap(at: date.timeIntervalSinceReferenceDate) {
            bpm = measured
            status = "Tap tempo · \(Int(measured.rounded())) BPM"
        } else {
            status = "Tap again to set BPM."
        }
    }

    private func stop(reason: String) {
        generation += 1
        stopScheduledWork()
        isRunning = false
        currentColour = nil
        status = reason
    }

    private func stopScheduledWork() {
        scheduled?.cancel()
        scheduled = nil
    }

    private func reconfigureRunningPattern() {
        guard isRunning else {
            pattern.reset(mode: mode)
            return
        }
        guard selectedColours.count == 4 else {
            stop(reason: "VFX stopped · choose four colours.")
            return
        }
        stopScheduledWork()
        generation += 1
        pattern.reset(mode: mode)
        status = "Running · \(mode.rawValue)"
        emitNext(generation: generation)
    }

    private func emitNext(generation expectedGeneration: Int) {
        guard isRunning, generation == expectedGeneration,
              let frame = pattern.next(colours: selectedColours, bpm: bpm, randomIndex: randomIndex) else {
            if isRunning { stop(reason: "VFX stopped · choose four colours.") }
            return
        }
        currentColour = frame.colour
        output?(frame.colour, brightness)
        scheduled = scheduler.schedule(frame.duration) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                guard self.isRunning, self.generation == expectedGeneration else { return }
                self.emitNext(generation: expectedGeneration)
            }
        }
    }

    deinit { scheduled?.cancel() }
}
