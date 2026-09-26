import SwiftUI

struct LEDMonsterMoodView: View {
    @ObservedObject var bluetooth: BluetoothStore
    @ObservedObject var controller: LEDMonsterMoodController
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mood mode")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text("Choose an atmosphere and let the colours drift gently.")
                        .font(.callout).foregroundStyle(Theme.muted)
                }
                Spacer()
                Label(bluetooth.controlReady ? "Ready" : "Connect strip",
                      systemImage: bluetooth.controlReady ? "bolt.fill" : "bolt.slash")
                    .font(.caption.bold())
                    .foregroundStyle(bluetooth.controlReady ? Theme.accent : Theme.muted)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    presetCard.frame(minWidth: 330, maxWidth: .infinity)
                    controlsCard.frame(width: 260)
                }
                VStack(spacing: 14) {
                    presetCard
                    controlsCard
                }
            }
        }
    }

    private var presetCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose a mood").font(.headline)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(LEDMonsterMoodPreset.presets) { preset in
                        presetButton(preset)
                    }
                }
            }
        }
    }

    private var controlsCard: some View {
        VStack(spacing: 14) {
            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Transition").font(.headline)
                    ForEach(LEDMonsterMoodSpeed.allCases) { speed in
                        Button { controller.speed = speed } label: {
                            HStack {
                                Image(systemName: controller.speed == speed ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(controller.speed == speed ? Theme.accent : Theme.muted)
                                Text(speed.title)
                                Spacer()
                                Text(speed.detail).foregroundStyle(Theme.muted)
                            }
                            .padding(.horizontal, 10).frame(minHeight: 36)
                            .background(controller.speed == speed ? Theme.accent.opacity(0.12) : Color.black.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(controller.speed == speed ? "Selected" : "Not selected")
                    }
                }
            }

            card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Brightness").font(.headline)
                        Spacer()
                        Text("\(Int((controller.brightness * 100).rounded()))%")
                            .monospacedDigit().foregroundStyle(Theme.muted)
                    }
                    Slider(value: $controller.brightness, in: 0...1)
                        .accessibilityLabel("Mood brightness")
                    HStack(spacing: 10) {
                        Button("Start mood", systemImage: "play.fill") { controller.start() }
                            .buttonStyle(.borderedProminent)
                            .disabled(!bluetooth.controlReady || controller.isRunning)
                        Button("Stop", systemImage: "stop.fill") { controller.stop() }
                            .disabled(!controller.isRunning)
                    }
                    Text(bluetooth.controlReady ? "Smooth RGB fades use the selected speed." : "Connect BJ_LED_M before starting.")
                        .font(.caption).foregroundStyle(Theme.muted)
                    HStack(spacing: 7) {
                        Circle().fill(controller.isRunning ? Theme.accent : Theme.muted.opacity(0.5))
                            .frame(width: 8, height: 8)
                        Text(controller.status).font(.caption).lineLimit(2)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func presetButton(_ preset: LEDMonsterMoodPreset) -> some View {
        let selected = controller.presetID == preset.id
        return Button { controller.presetID = preset.id } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(preset.name).font(.headline)
                Text(preset.subtitle).font(.caption).lineLimit(1).minimumScaleFactor(0.72)
            }
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .bottomLeading)
            .background(LinearGradient(colors: preset.colours.map {
                Color(red: $0.red, green: $0.green, blue: $0.blue)
            }, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(selected ? Theme.accent : Color.white.opacity(0.22), lineWidth: selected ? 3 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
    }
}
