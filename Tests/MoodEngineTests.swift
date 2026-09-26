import Foundation

final class MoodManualScheduler {
    struct Pending { let action: () -> Void; var cancelled: Bool }
    var entries: [Pending] = []
    var scheduler: LEDMonsterVFXScheduler {
        LEDMonsterVFXScheduler { [weak self] _, action in
            guard let self else { return LEDMonsterVFXCancellation {} }
            let index = entries.count
            entries.append(.init(action: action, cancelled: false))
            return LEDMonsterVFXCancellation { [weak self] in
                guard let self, entries.indices.contains(index) else { return }
                entries[index].cancelled = true
            }
        }
    }
    func fire(_ index: Int, evenIfCancelled: Bool = false) {
        guard entries.indices.contains(index), evenIfCancelled || !entries[index].cancelled else { return }
        entries[index].action()
    }
}

@main
struct MoodEngineTests {
    @MainActor
    static func main() {
        let presets = LEDMonsterMoodPreset.presets
        precondition(presets.count == 6)
        precondition(Set(presets.map(\.id)).count == presets.count)
        precondition(presets.allSatisfy { $0.colours.count == 3 })

        var pattern = LEDMonsterMoodPattern(preset: presets[0], speed: .flow)
        let first = pattern.next()!
        precondition(first.colour == presets[0].colours[0])
        precondition(first.duration >= 0.12)
        let second = pattern.next()!
        precondition(second.colour != first.colour)
        precondition(second.colour.red >= min(presets[0].colours[0].red, presets[0].colours[1].red))
        precondition(second.colour.red <= max(presets[0].colours[0].red, presets[0].colours[1].red))

        let manual = MoodManualScheduler()
        let controller = LEDMonsterMoodController(scheduler: manual.scheduler)
        var output: [(LEDMonsterVFXColour, Double)] = []
        controller.output = { output.append(($0, $1)) }
        precondition(controller.start())
        precondition(controller.isRunning)
        precondition(output.count == 1)
        controller.brightness = 0.4
        precondition(output.last?.1 == 0.4)
        manual.fire(0)
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        precondition(output.count >= 3)
        controller.presetID = "ocean"
        precondition(controller.currentColour == LEDMonsterMoodPreset.presets.first(where: { $0.id == "ocean" })!.colours[0])
        let countBeforeStop = output.count
        controller.stop()
        manual.fire(2, evenIfCancelled: true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        precondition(output.count == countBeforeStop)
        precondition(!controller.isRunning)

        print("PASS: six mood presets; paced colour interpolation; live brightness; preset restart; safe stop and stale-callback suppression")
    }
}
