import Foundation

private final class TestScheduleBox {
    struct Entry {
        let delay: TimeInterval
        let action: () -> Void
        var cancelled: Bool
    }
    var entries: [Entry] = []

    var scheduler: LEDMonsterVFXScheduler {
        LEDMonsterVFXScheduler { [weak self] delay, action in
            guard let self else { return LEDMonsterVFXCancellation {} }
            let index = entries.count
            entries.append(.init(delay: delay, action: action, cancelled: false))
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

@main @MainActor
struct VFXEngineTests {
    static func close(_ lhs: Double, _ rhs: Double, accuracy: Double = 0.000_001) -> Bool {
        abs(lhs - rhs) <= accuracy
    }

    static func main() {
        let palette = LEDMonsterVFXColour.palette
        precondition(palette.count == 16)
        precondition(Set(palette.map(\.id)).count == 16)
        precondition(palette.allSatisfy { [ $0.red, $0.green, $0.blue ].allSatisfy { (0...1).contains($0) } })

        let four = Array(palette.prefix(4))
        var flash = LEDMonsterVFXPattern(mode: .flashOne)
        let on = flash.next(colours: four, bpm: 120, randomIndex: { _ in 0 })!
        let dark = flash.next(colours: four, bpm: 120, randomIndex: { _ in 0 })!
        let nextOn = flash.next(colours: four, bpm: 120, randomIndex: { _ in 0 })!
        precondition(on.colour == four[0] && dark.colour == .black && nextOn.colour == four[1])
        precondition(close(on.duration, 0.25) && close(dark.duration, 0.25))

        var quick = LEDMonsterVFXPattern(mode: .quick)
        let quick1 = quick.next(colours: four, bpm: 120, randomIndex: { _ in 1 })!
        let quickDark = quick.next(colours: four, bpm: 120, randomIndex: { _ in 1 })!
        let quick2 = quick.next(colours: four, bpm: 120, randomIndex: { _ in 1 })!
        precondition(quick1.colour == four[1] && quickDark.colour == .black && quick2.colour == four[2],
                     "Random modes must not immediately repeat")
        precondition(close(quick1.duration, 0.125) && close(quickDark.duration, 0.125))

        var slow = LEDMonsterVFXPattern(mode: .slow)
        let slowOn = slow.next(colours: four, bpm: 120, randomIndex: { _ in 0 })!
        let slowDark = slow.next(colours: four, bpm: 120, randomIndex: { _ in 0 })!
        precondition(close(slowOn.duration, 0.5) && close(slowDark.duration, 0.5) && slowDark.colour == .black)
        var jump = LEDMonsterVFXPattern(mode: .jump)
        precondition(close(jump.next(colours: four, bpm: 120, randomIndex: { _ in 3 })!.duration, 0.5))

        var exhaustive = LEDMonsterVFXPattern(mode: .jump)
        var previousID: String?
        for word in -8...16 {
            let colour = exhaustive.next(colours: four, bpm: 120, randomIndex: { _ in word })!.colour
            precondition(four.contains(colour) && colour.id != previousID)
            previousID = colour.id
        }

        var fade = LEDMonsterVFXPattern(mode: .fade)
        let fadeStart = fade.next(colours: four, bpm: 120, randomIndex: { _ in 0 })!
        let fadeOne = fade.next(colours: four, bpm: 120, randomIndex: { _ in 1 })!
        let fadeTwo = fade.next(colours: four, bpm: 120, randomIndex: { _ in 1 })!
        let fadeThree = fade.next(colours: four, bpm: 120, randomIndex: { _ in 1 })!
        let fadeFour = fade.next(colours: four, bpm: 120, randomIndex: { _ in 1 })!
        precondition(fadeStart.colour == four[0])
        precondition(close(fadeOne.colour.red, 1) && close(fadeOne.colour.green, 0.0625))
        precondition(close(fadeFour.colour.red, four[1].red) && close(fadeFour.colour.green, four[1].green))
        precondition([fadeStart, fadeOne, fadeTwo, fadeThree, fadeFour].allSatisfy { $0.duration >= 0.12 })

        var taps = LEDMonsterTapTempo()
        precondition(taps.recordTap(at: 10) == nil)
        precondition(close(taps.recordTap(at: 10.5)!, 120))
        precondition(close(taps.recordTap(at: 11.0)!, 120))
        precondition(close(taps.recordTap(at: 11.4)!, 120), "Median should resist one mistimed but valid tap")
        precondition(close(taps.recordTap(at: 11.45)!, 120), "Implausibly fast taps should be ignored")
        precondition(taps.recordTap(at: 20) == nil)
        precondition(close(taps.recordTap(at: 21)!, 60))

        let schedule = TestScheduleBox()
        let controller = LEDMonsterVFXController(scheduler: schedule.scheduler, randomIndex: { _ in 0 })
        var output: [(LEDMonsterVFXColour, Double)] = []
        controller.output = { output.append(($0, $1)) }
        controller.brightness = 0.6
        precondition(controller.start())
        precondition(controller.isRunning && output.count == 1 && close(output[0].1, 0.6))
        precondition(schedule.entries.count == 1)
        precondition(controller.start(), "Starting again should replace the current run")
        precondition(output.count == 2 && schedule.entries.count == 2 && schedule.entries[0].cancelled)
        schedule.fire(0, evenIfCancelled: true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        precondition(output.count == 2, "A callback from the replaced run must be ignored")
        schedule.fire(1)
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        precondition(output.count == 3)
        controller.brightness = 0.7
        precondition(output.count == 4 && close(output.last!.1, 0.7), "Running brightness changes should emit immediately")

        controller.stop()
        controller.stop()
        let countAtStop = output.count
        schedule.fire(2, evenIfCancelled: true) // Simulate a stale callback racing cancellation.
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        precondition(!controller.isRunning && output.count == countAtStop, "Stop must suppress stale timer work")

        precondition(!controller.chooseExactlyFour(["red", "red", "blue", "green"]))
        precondition(controller.chooseExactlyFour(["red", "green", "blue", "magenta"]))
        precondition(controller.selectedColours.map(\.id) == ["red", "green", "blue", "magenta"])
        precondition(!controller.toggleColour(id: "yellow"), "A fifth colour must be rejected")
        precondition(controller.toggleColour(id: "magenta"))
        precondition(!controller.start(), "VFX must not run without four selected colours")

        controller.tap(at: Date(timeIntervalSinceReferenceDate: 100))
        controller.tap(at: Date(timeIntervalSinceReferenceDate: 100.5))
        precondition(close(controller.bpm, 120))

        print("PASS: 16-colour palette; exact four-colour gate; tap tempo; all five VFX modes; random no-repeat; BLE-paced fades; safe start/stop and stale-callback suppression")
    }
}
