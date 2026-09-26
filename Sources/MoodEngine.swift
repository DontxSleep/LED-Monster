import Combine
import Foundation

struct LEDMonsterMoodPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let colours: [LEDMonsterVFXColour]

    static let presets: [LEDMonsterMoodPreset] = [
        .init(id: "relax", name: "Relax", subtitle: "Lavender and soft blue", colours: [
            .init(id: "relax-violet", name: "Lavender", red: 0.58, green: 0.24, blue: 1),
            .init(id: "relax-blue", name: "Soft blue", red: 0.12, green: 0.48, blue: 1),
            .init(id: "relax-rose", name: "Soft rose", red: 1, green: 0.28, blue: 0.58)
        ]),
        .init(id: "sunset", name: "Sunset", subtitle: "Amber, coral and rose", colours: [
            .init(id: "sunset-amber", name: "Amber", red: 1, green: 0.48, blue: 0.04),
            .init(id: "sunset-coral", name: "Coral", red: 1, green: 0.16, blue: 0.08),
            .init(id: "sunset-rose", name: "Rose", red: 1, green: 0.04, blue: 0.38)
        ]),
        .init(id: "ocean", name: "Ocean", subtitle: "Deep blue through cyan", colours: [
            .init(id: "ocean-blue", name: "Deep blue", red: 0.02, green: 0.12, blue: 1),
            .init(id: "ocean-azure", name: "Azure", red: 0, green: 0.52, blue: 1),
            .init(id: "ocean-cyan", name: "Cyan", red: 0, green: 1, blue: 0.9)
        ]),
        .init(id: "forest", name: "Forest", subtitle: "Emerald and spring green", colours: [
            .init(id: "forest-green", name: "Emerald", red: 0, green: 0.52, blue: 0.18),
            .init(id: "forest-spring", name: "Spring", red: 0, green: 1, blue: 0.46),
            .init(id: "forest-lime", name: "Lime", red: 0.5, green: 1, blue: 0.04)
        ]),
        .init(id: "focus", name: "Focus", subtitle: "Warm and clear whites", colours: [
            .init(id: "focus-warm", name: "Warm white", red: 1, green: 0.72, blue: 0.42),
            .init(id: "focus-white", name: "White", red: 1, green: 1, blue: 1),
            .init(id: "focus-cool", name: "Cool white", red: 0.58, green: 0.82, blue: 1)
        ]),
        .init(id: "midnight", name: "Midnight", subtitle: "Blue, violet and magenta", colours: [
            .init(id: "midnight-blue", name: "Blue", red: 0.03, green: 0.08, blue: 0.72),
            .init(id: "midnight-violet", name: "Violet", red: 0.38, green: 0.02, blue: 0.82),
            .init(id: "midnight-magenta", name: "Magenta", red: 0.78, green: 0.02, blue: 0.62)
        ])
    ]
}

enum LEDMonsterMoodSpeed: Double, CaseIterable, Identifiable {
    case drift = 16
    case glow = 8
    case flow = 4

    var id: Double { rawValue }
    var title: String {
        switch self {
        case .drift: return "Drift"
        case .glow: return "Glow"
        case .flow: return "Flow"
        }
    }
    var detail: String { "\(Int(rawValue)) sec" }
}

struct LEDMonsterMoodPattern {
    private(set) var preset: LEDMonsterMoodPreset
    private(set) var speed: LEDMonsterMoodSpeed
    private var currentIndex = 0
    private var targetIndex = 1
    private var step = 0

    init(preset: LEDMonsterMoodPreset, speed: LEDMonsterMoodSpeed) {
        self.preset = preset
        self.speed = speed
    }

    mutating func reset(preset: LEDMonsterMoodPreset? = nil, speed: LEDMonsterMoodSpeed? = nil) {
        if let preset { self.preset = preset }
        if let speed { self.speed = speed }
        currentIndex = 0
        targetIndex = min(1, max(0, self.preset.colours.count - 1))
        step = 0
    }

    mutating func next() -> LEDMonsterVFXFrame? {
        guard !preset.colours.isEmpty else { return nil }
        guard preset.colours.count > 1 else {
            return .init(colour: preset.colours[0], duration: 0.12)
        }
        let from = preset.colours[currentIndex]
        let to = preset.colours[targetIndex]
        if step == 0 {
            step = 1
            return .init(colour: from, duration: 0.12)
        }
        let steps = max(2, Int(floor(speed.rawValue / 0.12)))
        let frame = LEDMonsterVFXFrame(
            colour: .mixed(from: from, to: to, amount: Double(step) / Double(steps)),
            duration: 0.12
        )
        if step >= steps {
            currentIndex = targetIndex
            targetIndex = (targetIndex + 1) % preset.colours.count
            step = 1
        } else {
            step += 1
        }
        return frame
    }
}

@MainActor
final class LEDMonsterMoodController: ObservableObject {
    @Published var presetID: String = LEDMonsterMoodPreset.presets[0].id {
        didSet {
            guard LEDMonsterMoodPreset.presets.contains(where: { $0.id == presetID }) else {
                presetID = oldValue
                return
            }
            if oldValue != presetID { reconfigure() }
        }
    }
    @Published var speed: LEDMonsterMoodSpeed = .glow {
        didSet { if oldValue != speed { reconfigure() } }
    }
    @Published var brightness: Double = 0.72 {
        didSet {
            let clamped = min(1, max(0, brightness.isFinite ? brightness : 0.72))
            guard brightness == clamped else { brightness = clamped; return }
            if oldValue != clamped, isRunning, let currentColour { output?(currentColour, clamped) }
        }
    }
    @Published private(set) var isRunning = false
    @Published private(set) var status = "Choose a mood, then start."
    @Published private(set) var currentColour: LEDMonsterVFXColour?

    var output: ((LEDMonsterVFXColour, Double) -> Void)?
    var preset: LEDMonsterMoodPreset {
        LEDMonsterMoodPreset.presets.first(where: { $0.id == presetID }) ?? LEDMonsterMoodPreset.presets[0]
    }

    private let scheduler: LEDMonsterVFXScheduler
    private var scheduled: LEDMonsterVFXCancellation?
    private var pattern: LEDMonsterMoodPattern
    private var generation = 0

    init(scheduler: LEDMonsterVFXScheduler = .mainRunLoop) {
        let initial = LEDMonsterMoodPreset.presets[0]
        pattern = LEDMonsterMoodPattern(preset: initial, speed: .glow)
        self.scheduler = scheduler
    }

    @discardableResult
    func start() -> Bool {
        stopScheduledWork()
        generation += 1
        pattern.reset(preset: preset, speed: speed)
        isRunning = true
        status = "Playing · (preset.name)"
        emitNext(generation: generation)
        return true
    }

    func stop() { stop(reason: "Mood stopped.") }

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

    private func reconfigure() {
        guard isRunning else {
            pattern.reset(preset: preset, speed: speed)
            status = "Ready · (preset.name)"
            return
        }
        stopScheduledWork()
        generation += 1
        pattern.reset(preset: preset, speed: speed)
        status = "Playing · (preset.name)"
        emitNext(generation: generation)
    }

    private func emitNext(generation expectedGeneration: Int) {
        guard isRunning, generation == expectedGeneration, let frame = pattern.next() else {
            if isRunning { stop(reason: "Mood stopped.") }
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
