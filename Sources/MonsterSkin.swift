import SwiftUI
import AppKit

// Hallmark · pre-emit critique: P5 H5 E4 S5 R5 V4
// Component-scope: preserves the established monster skin and nests all three pad rows inside its carved sockets.
struct MonsterSkinView: View {
    @ObservedObject var bluetooth: BluetoothStore
    @ObservedObject var midi: MIDIStore
    var isActive: Bool
    @State private var momentary = MonsterMomentaryPads()
    private let pads = MonsterColourPad.all
    private let image = Bundle.main.url(forResource: "MonsterRGB-Mouth", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
    var body: some View {
        Group {
            if let image {
                GeometryReader { geometry in
                    let selectedPad = momentary.activeIndex.map { pads[$0] }
                    ZStack {
                        Image(nsImage: image).resizable().interpolation(.high).accessibilityHidden(true)
                        MonsterEye(active: isActive, colour: selectedPad.map(\.rgb), colourToken: selectedPad?.note)
                            .frame(width: geometry.size.width * 0.214, height: geometry.size.height * 0.117)
                            .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.237)
                        ForEach(pads.indices, id: \.self) { index in
                            let active = momentary.activeIndex == index
                            MonsterPadButton(pad: pads[index], index: index, active: active,
                                             geometryWidth: geometry.size.width,
                                             enabled: isActive, pressingChanged: { pressed in
                                if pressed { beginPad(index, source: "mouse-\(index)", sendMIDI: true) }
                                else { endPad(index, source: "mouse-\(index)", sendMIDI: true) }
                            }, pulse: { pulse(index) })
                                .frame(width: geometry.size.width * 0.196, height: geometry.size.height * 0.058)
                                .position(x: padX(index, width: geometry.size.width),
                                          y: padY(index, height: geometry.size.height))
                        }
                    }
                }
            } else { Text("The LED MØNSTER artwork could not be loaded.") }
        }
        .background(MonsterMomentaryKeyMonitor(active: isActive) { key in
            guard let index = pads.firstIndex(where: { $0.key.lowercased() == key }) else { return }
            beginPad(index, source: "key-\(key)", sendMIDI: true)
        } keyUp: { key in
            guard let index = pads.firstIndex(where: { $0.key.lowercased() == key }) else { return }
            endPad(index, source: "key-\(key)", sendMIDI: true)
        }.frame(width: 0, height: 0))
        .onReceive(midi.noteOn) { index in
            guard isActive else { return }
            beginPad(index, source: "midi-\(index)", sendMIDI: false)
        }
        .onReceive(midi.noteOff) { index in
            endPad(index, source: "midi-\(index)", sendMIDI: false)
        }
        .onChange(of: isActive) { active in
            if active {
                if bluetooth.controlReady { bluetooth.setPower(false) }
            } else { endAllPads() }
        }
        .onChange(of: bluetooth.controlReady) { ready in
            if ready && isActive { bluetooth.setPower(false) }
        }
        .onChange(of: midi.enabled) { enabled in
            if !enabled { endAllPads() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            endAllPads()
        }
        .onAppear {
            if isActive && bluetooth.controlReady { bluetooth.setPower(false) }
        }
        .onDisappear { endAllPads() }
    }
    private func beginPad(_ index: Int, source: String, sendMIDI: Bool) {
        var next = momentary
        let transition = next.press(index, source: source)
        guard transition != .none else { return }
        momentary = next
        if sendMIDI { midi.sendPadDown(index) }
        apply(transition)
    }
    private func endPad(_ index: Int, source: String, sendMIDI: Bool) {
        if sendMIDI { midi.sendPadUp(index) }
        var next = momentary
        let transition = next.release(source: source)
        guard transition != .none else { return }
        momentary = next
        apply(transition)
    }
    private func endAllPads() {
        midi.sendAllPadsOff()
        var next = momentary
        let transition = next.releaseAll()
        momentary = next
        apply(transition)
    }
    private func pulse(_ index: Int) {
        let source = "accessibility-\(UUID().uuidString)"
        beginPad(index, source: source, sendMIDI: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            endPad(index, source: source, sendMIDI: true)
        }
    }
    private func apply(_ transition: MonsterPadTransition) {
        switch transition {
        case .none: break
        case .colour: commit()
        case .off:
            if bluetooth.controlReady { bluetooth.setPower(false) }
        }
    }
    private func commit() {
        guard let selected = momentary.activeIndex, bluetooth.controlReady else { return }
        let pad = pads[selected]
        bluetooth.setColour(red: pad.red, green: pad.green, blue: pad.blue, brightness: 1)
    }
    private func padX(_ index: Int, width: CGFloat) -> CGFloat {
        let column = index < 6 ? index % 3 : index - 6
        return width * [0.23, 0.5, 0.77][column]
    }
    private func padY(_ index: Int, height: CGFloat) -> CGFloat {
        height * (index < 3 ? 0.402 : index < 6 ? 0.472 : 0.542)
    }
}

private struct MonsterPadButton: View {
    let pad: MonsterColourPad
    let index: Int
    let active: Bool
    let geometryWidth: CGFloat
    let enabled: Bool
    let pressingChanged: (Bool) -> Void
    let pulse: () -> Void

    var body: some View {
        Button {} label: {
            if pad.isGradient {
                MonsterGradientPadFace(pad: pad, active: active,
                                       cornerRadius: geometryWidth * 0.023,
                                       keySize: max(15, geometryWidth * 0.03),
                                       lightText: index == 8)
            } else {
                MonsterSolidPadFace(pad: pad, active: active,
                                    cornerRadius: geometryWidth * 0.023,
                                    keySize: max(15, geometryWidth * 0.03),
                                    alwaysLightText: index == 2)
            }
        }
        .buttonStyle(MonsterMomentaryPadStyle(pressingChanged: pressingChanged))
        .disabled(!enabled)
        .accessibilityLabel("\(pad.name)\(pad.isGradient ? " gradient midpoint" : ""), key \(pad.key), MIDI note \(pad.note)")
        .accessibilityValue(active ? "Held, light on" : "Released, light off")
        .accessibilityAction(named: "Momentary pulse", pulse)
        .help(pad.isGradient ? "Hold for the \(pad.name) midpoint; release to switch off" :
                "Hold for pure \(pad.name.lowercased()); release to switch off")
    }
}

private struct MonsterSolidPadFace: View {
    let pad: MonsterColourPad
    let active: Bool
    let cornerRadius: CGFloat
    let keySize: CGFloat
    let alwaysLightText: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.sRGB, red: pad.red, green: pad.green, blue: pad.blue, opacity: 1))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(active ? Color.white : .clear, lineWidth: 3))
            .overlay(alignment: .bottom) {
                HStack {
                    Text(pad.key).font(.system(size: keySize, weight: .bold, design: .rounded))
                    Text(pad.name).font(.caption.bold())
                }
                .foregroundStyle(alwaysLightText ? .white : .black)
                .padding(4)
            }
    }
}

private struct MonsterGradientPadFace: View {
    let pad: MonsterColourPad
    let active: Bool
    let cornerRadius: CGFloat
    let keySize: CGFloat
    let lightText: Bool

    var body: some View {
        let colour: (RGBChannels) -> Color = { channels in
            Color(.sRGB, red: channels.red, green: channels.green, blue: channels.blue, opacity: 1)
        }
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(LinearGradient(colors: [colour(pad.start), colour(pad.end)],
                                 startPoint: .leading, endPoint: .trailing))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(active ? Color.white : .clear, lineWidth: 3))
            .overlay(alignment: .bottom) {
                HStack {
                    Text(pad.key).font(.system(size: keySize, weight: .bold, design: .rounded))
                    Text(pad.name).font(.caption.bold())
                }
                .foregroundStyle(lightText ? .white : .black)
                .padding(4)
            }
    }
}

private struct MonsterMomentaryPadStyle: ButtonStyle {
    let pressingChanged: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .onChange(of: configuration.isPressed, perform: pressingChanged)
    }
}

private struct MonsterMomentaryKeyMonitor: NSViewRepresentable {
    let active: Bool
    let keyDown: (String) -> Void
    let keyUp: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView {
        context.coordinator.update(active: active, keyDown: keyDown, keyUp: keyUp)
        context.coordinator.start()
        return NSView(frame: .zero)
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(active: active, keyDown: keyDown, keyUp: keyUp)
    }
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) { coordinator.stop() }

    final class Coordinator {
        private var monitor: Any?
        private var active = false
        private var held = Set<String>()
        private var keyDown: (String) -> Void = { _ in }
        private var keyUp: (String) -> Void = { _ in }
        private let allowed = Set(["q", "w", "e", "r", "t", "y", "a", "s", "d"])

        func update(active nextActive: Bool,
                    keyDown nextKeyDown: @escaping (String) -> Void,
                    keyUp nextKeyUp: @escaping (String) -> Void) {
            keyDown = nextKeyDown
            keyUp = nextKeyUp
            if active && !nextActive { releaseHeldKeys() }
            active = nextActive
        }
        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
                self?.handle(event) ?? event
            }
        }
        func stop() {
            releaseHeldKeys()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
        private func handle(_ event: NSEvent) -> NSEvent? {
            guard active,
                  event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
                  let key = event.charactersIgnoringModifiers?.lowercased(),
                  allowed.contains(key) else { return event }
            if event.type == .keyDown {
                guard !event.isARepeat, held.insert(key).inserted else { return nil }
                keyDown(key)
            } else if held.remove(key) != nil {
                keyUp(key)
            }
            return nil
        }
        private func releaseHeldKeys() {
            let keys = held
            held.removeAll()
            keys.forEach(keyUp)
        }
        deinit { stop() }
    }
}

private extension MonsterColourPad {
    var rgb: RGBChannels { .init(red: red, green: green, blue: blue) }
}

private struct EyeOpening: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: r.midY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY), control: CGPoint(x: r.midX, y: -r.height * 0.48))
            p.addQuadCurve(to: CGPoint(x: 0, y: r.midY), control: CGPoint(x: r.midX, y: r.height * 1.48))
        }
    }
}

struct MonsterEye: View {
    let active: Bool
    let colour: RGBChannels?
    let colourToken: UInt8?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var opening = 1.0
    private var animate: Bool { active && !reduceMotion && scenePhase == .active }
    var body: some View {
        GeometryReader { g in
            let iris = colour ?? RGBChannels(red: 0, green: 0.62, blue: 1)
            ZStack {
                EyeOpening().fill(LinearGradient(colors: [Color(red: 0.16, green: 0.22, blue: 0.19), .black, Color(red: 0.26, green: 0.29, blue: 0.23)], startPoint: .top, endPoint: .bottom))
                ZStack {
                    Color(red: 0.005, green: 0.045, blue: 0.09)
                    Circle().fill(RadialGradient(colors: [
                        Color(.sRGB, red: min(1, iris.red + 0.42), green: min(1, iris.green + 0.42), blue: min(1, iris.blue + 0.42), opacity: 1),
                        Color(.sRGB, red: iris.red, green: iris.green, blue: iris.blue, opacity: 1),
                        Color(.sRGB, red: iris.red * 0.12, green: iris.green * 0.12, blue: iris.blue * 0.12, opacity: 1)
                    ], center: .center, startRadius: 2, endRadius: g.size.height * 0.52))
                        .frame(width: g.size.height, height: g.size.height)
                    ForEach(0..<40, id: \.self) { i in
                        Rectangle().fill(Color.white.opacity(i % 2 == 0 ? 0.34 : 0.14))
                            .frame(width: 1, height: g.size.height * 0.31)
                            .offset(y: -g.size.height * 0.32).rotationEffect(.degrees(Double(i) * 9))
                    }
                    Ellipse().fill(.black).frame(width: g.size.height * 0.15, height: g.size.height * 0.9)
                    Ellipse().fill(.white.opacity(0.85)).frame(width: g.size.height * 0.12, height: g.size.height * 0.2)
                        .offset(x: -g.size.height * 0.19, y: -g.size.height * 0.2)
                }.clipShape(EyeOpening()).scaleEffect(x: 1, y: opening)
            }
        }
        .animation(.easeOut(duration: 0.13), value: colourToken)
        .accessibilityHidden(true).allowsHitTesting(false)
        .task(id: animate) {
            opening = 1
            guard animate else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64.random(in: 6...12) * 1_000_000_000)
                    withAnimation(.easeIn(duration: 0.14)) { opening = 0.015 }
                    try await Task.sleep(nanoseconds: 190_000_000)
                    withAnimation(.easeOut(duration: 0.22)) { opening = 1 }
                } catch { opening = 1; return }
            }
        }
    }
}
