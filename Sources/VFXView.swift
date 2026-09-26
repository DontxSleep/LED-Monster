import SwiftUI

/// The VFX screen deliberately keeps the on-screen preview still. Only the small
/// output label changes while the physical strip runs the selected effect.
struct LEDMonsterVFXView: View {
    @ObservedObject var bluetooth: BluetoothStore
    @ObservedObject var controller: LEDMonsterVFXController
    let keyboardEnabled: Bool

    private let paletteColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    private let modeColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LED MØNSTER VFX")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text("Build a four-colour set, choose an effect, then run it on your strip.")
                        .font(.callout)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Label(bluetooth.controlReady ? "Ready" : "Connect strip",
                      systemImage: bluetooth.controlReady ? "bolt.fill" : "bolt.slash")
                    .font(.caption.bold())
                    .foregroundStyle(bluetooth.controlReady ? Theme.accent : Theme.muted)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    colourColumn.frame(minWidth: 330, maxWidth: .infinity)
                    controlColumn.frame(width: 260)
                }
                VStack(spacing: 14) {
                    colourColumn
                    controlColumn
                }
            }
        }
    }

    private var colourColumn: some View {
        VStack(spacing: 14) {
            card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Four-colour set").font(.headline)
                        Spacer()
                        Text("\(controller.selectedColours.count) / 4")
                            .font(.caption.bold()).monospacedDigit().foregroundStyle(Theme.muted)
                    }
                    LazyVGrid(columns: paletteColumns, spacing: 8) {
                        ForEach(0..<4, id: \.self) { index in selectedSlot(index) }
                    }
                    Text(controller.selectedColours.count == 4
                         ? "Remove one colour before choosing another."
                         : "Choose \(4 - controller.selectedColours.count) more colour\(controller.selectedColours.count == 3 ? "" : "s").")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }

            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("16-colour palette").font(.headline)
                    LazyVGrid(columns: paletteColumns, spacing: 8) {
                        ForEach(LEDMonsterVFXColour.palette) { colour in paletteButton(colour) }
                    }
                }
            }
        }
    }

    private var controlColumn: some View {
        VStack(spacing: 14) {
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Colour flash").font(.headline)
                    LazyVGrid(columns: modeColumns, spacing: 8) {
                        ForEach(LEDMonsterVFXMode.allCases) { mode in modeButton(mode) }
                    }
                    Label("Random order · avoids immediate repeats", systemImage: "shuffle")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }

            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tap tempo").font(.headline)
                    HStack(spacing: 12) {
                        tapButton
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(Int(controller.bpm.rounded()))")
                                .font(.system(size: 32, weight: .medium, design: .rounded))
                                .monospacedDigit()
                            Text("BPM").font(.caption.bold()).foregroundStyle(Theme.muted)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(Int(controller.bpm.rounded())) beats per minute")
                    }
                    Text("Press Space repeatedly to match the beat.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }

            card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Brightness").font(.headline)
                        Spacer()
                        Text("\(Int((controller.brightness * 100).rounded()))%")
                            .monospacedDigit().foregroundStyle(Theme.muted)
                    }
                    Slider(value: $controller.brightness, in: 0...1)
                        .accessibilityLabel("VFX brightness")
                    HStack(spacing: 10) {
                        Button("Start VFX", systemImage: "play.fill") { controller.start() }
                            .buttonStyle(.borderedProminent)
                            .disabled(!bluetooth.controlReady || controller.selectedColours.count != 4 || controller.isRunning)
                        Button("Stop", systemImage: "stop.fill") { controller.stop() }
                            .disabled(!controller.isRunning)
                    }
                    Text(startReason)
                        .font(.caption).foregroundStyle(Theme.muted)
                    HStack(spacing: 7) {
                        Circle()
                            .fill(controller.isRunning ? Theme.accent : Theme.muted.opacity(0.5))
                            .frame(width: 8, height: 8)
                        Text(controller.status).font(.caption).lineLimit(2)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
    }

    @ViewBuilder
    private func selectedSlot(_ index: Int) -> some View {
        if controller.selectedColours.indices.contains(index) {
            let colour = controller.selectedColours[index]
            Button { controller.toggleColour(id: colour.id) } label: {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(swatch(colour))
                    Text("\(index + 1)")
                        .font(.caption2.bold()).monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.black.opacity(0.68), in: Circle())
                        .padding(4)
                    Text(colour.name)
                        .font(.caption2.bold())
                        .foregroundStyle(textColour(for: colour))
                        .lineLimit(2).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(7)
                }
                .frame(minHeight: 48)
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.accent, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(colour.name) from colour \(index + 1)")
            .help("Remove \(colour.name) from the VFX set")
        } else {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(minHeight: 48)
                .overlay(Text("\(index + 1)").font(.caption.bold()).foregroundStyle(Theme.muted))
                .accessibilityLabel("Colour \(index + 1) is empty")
        }
    }

    private func paletteButton(_ colour: LEDMonsterVFXColour) -> some View {
        let selectedIndex = controller.selectedColourIDs.firstIndex(of: colour.id)
        return Button { controller.toggleColour(id: colour.id) } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(swatch(colour))
                if let selectedIndex {
                    Text("\(selectedIndex + 1)")
                        .font(.caption2.bold()).monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.black.opacity(0.68), in: Circle())
                        .padding(4)
                }
                HStack(spacing: 3) {
                    Text(colour.name).lineLimit(2).minimumScaleFactor(0.64)
                    if selectedIndex != nil { Image(systemName: "checkmark") }
                }
                .font(.caption2.bold())
                .foregroundStyle(textColour(for: colour))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(7)
            }
            .frame(minHeight: 48)
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(selectedIndex == nil ? Color.white.opacity(0.2) : Theme.accent,
                              lineWidth: selectedIndex == nil ? 1 : 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(colour.name)
        .accessibilityValue(selectedIndex.map { "Selected as colour \($0 + 1) of 4" } ?? "Not selected")
        .accessibilityAddTraits(selectedIndex == nil ? [] : .isSelected)
        .help(selectedIndex == nil ? "Add \(colour.name) to the four-colour set" : "Remove \(colour.name) from the four-colour set")
    }

    private func modeButton(_ mode: LEDMonsterVFXMode) -> some View {
        let selected = controller.mode == mode
        return Button { controller.mode = mode } label: {
            HStack(spacing: 8) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Theme.accent : Theme.muted)
                Text(shortTitle(for: mode)).lineLimit(1).minimumScaleFactor(0.78)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .background(selected ? Theme.accent.opacity(0.12) : Color.black.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? Theme.accent.opacity(0.7) : Theme.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.rawValue)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var tapButton: some View {
        Button { controller.tap() } label: {
            VStack(spacing: 5) {
                Text("Tap to BPM").fontWeight(.semibold)
                Text("SPACE")
                    .font(.caption2.bold()).tracking(1)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 5))
            }
            .frame(minWidth: 110, minHeight: 46)
        }
        .buttonStyle(.borderedProminent)
        .vfxSpaceShortcut(enabled: keyboardEnabled)
        .disabled(!keyboardEnabled)
        .accessibilityHint("Press repeatedly to measure beats per minute")
    }

    private var startReason: String {
        if !bluetooth.controlReady { return "Connect BJ_LED_M before starting VFX." }
        if controller.selectedColours.count != 4 { return "Choose exactly four colours before starting." }
        return "The selected effect runs randomly at the current BPM."
    }

    private func shortTitle(for mode: LEDMonsterVFXMode) -> String {
        switch mode {
        case .flashOne: return "Flash 1"
        case .quick: return "Quick"
        case .slow: return "Slow"
        case .fade: return "Fade"
        case .jump: return "Jump"
        }
    }

    private func swatch(_ colour: LEDMonsterVFXColour) -> LinearGradient {
        LinearGradient(
            colors: [Color(red: colour.red, green: colour.green, blue: colour.blue),
                     Color(red: colour.red * 0.78, green: colour.green * 0.78, blue: colour.blue * 0.78)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private func textColour(for colour: LEDMonsterVFXColour) -> Color {
        let luminance = 0.2126 * colour.red + 0.7152 * colour.green + 0.0722 * colour.blue
        return luminance > 0.57 ? .black : .white
    }
}

private extension View {
    @ViewBuilder
    func vfxSpaceShortcut(enabled: Bool) -> some View {
        if enabled { keyboardShortcut(.space, modifiers: []) }
        else { self }
    }
}
