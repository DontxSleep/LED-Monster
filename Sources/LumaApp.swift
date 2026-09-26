// Hallmark · native workbench adaptation · Midnight · no decorative motion.
// Audience: personal use · purpose: control the room lighting · tone: calm, focused.
// Pre-emit critique: P4 H4 E4 S5 R5 V4. Native controls provide focus and disabled states.
import SwiftUI
import AppKit

enum Theme {
    static let background = Color(red: 0.063, green: 0.075, blue: 0.082)
    static let surface = Color(red: 0.102, green: 0.118, blue: 0.129)
    static let line = Color(red: 0.224, green: 0.259, blue: 0.278)
    static let ink = Color(red: 0.953, green: 0.957, blue: 0.937)
    static let muted = Color(red: 0.686, green: 0.725, blue: 0.741)
    static let accent = Color(red: 0.831, green: 0.929, blue: 0.667)
    static let error = Color(red: 1, green: 0.710, blue: 0.667)
}
private enum ProgrammePage: String, CaseIterable, Identifiable {
    case monster
    case vfx
    case mood
    case colour
    case details

    var id: String { rawValue }
    var title: String {
        switch self {
        case .monster: return "LED MØNSTER"
        case .mood: return "Mood mode"
        case .vfx: return "LED MØNSTER VFX"
        case .colour: return "Colour studio"
        case .details: return "Connection details"
        }
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
@main struct LumaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var bluetooth = BluetoothStore()
    var body: some Scene {
        Window("LED MØNSTER", id: "main") {
            StudioView(bluetooth: bluetooth)
                .frame(minWidth: 520, minHeight: 520)
                .background(MonsterWindowStyle())
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in bluetooth.shutdown() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 700, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Controller") {
                Button("Scan nearby") { bluetooth.scan() }.keyboardShortcut("r", modifiers: .command).disabled(bluetooth.currentID != nil)
                Button("Stop scan") { bluetooth.stopScan() }.disabled(!bluetooth.scanning)
                Button("Disconnect") { bluetooth.disconnect() }.disabled(bluetooth.currentID == nil)
                Divider()
                Button("Export report…") { bluetooth.exportReport() }.keyboardShortcut("e", modifiers: .command)
            }
        }
    }
}
struct StudioView: View {
    @ObservedObject var bluetooth: BluetoothStore
    @StateObject private var midi = MIDIStore()
    @StateObject private var vfx = LEDMonsterVFXController()
    @StateObject private var mood = LEDMonsterMoodController()
    @State private var page: ProgrammePage = .monster
    @State private var showOtherDevices = false
    @State private var panelOpen = false
    var body: some View {
        GeometryReader { area in
            ZStack(alignment: .topLeading) {
                MonsterSkinView(bluetooth: bluetooth, midi: midi, isActive: page == .monster && !panelOpen)
                    .allowsHitTesting(page == .monster && !panelOpen)
                    .accessibilityHidden(page != .monster || panelOpen)
                VStack {
                    MonsterWindowDragArea().frame(height: 35)
                    Spacer()
                    MonsterWindowDragArea().frame(height: 20)
                }.padding(.horizontal, 110)
                if page != .monster {
                    ScrollView {
                        switch page {
                        case .monster:
                            EmptyView()
                        case .mood:
                            LEDMonsterMoodView(bluetooth: bluetooth, controller: mood)
                                .padding(20)
                        case .vfx:
                            LEDMonsterVFXView(bluetooth: bluetooth, controller: vfx,
                                              keyboardEnabled: !panelOpen)
                                .padding(20)
                        case .colour:
                            ColourView(bluetooth: bluetooth).padding(20)
                        case .details:
                            DetailsView(bluetooth: bluetooth).padding(20)
                        }
                    }
                    .background(Theme.background.opacity(0.98), in: RoundedRectangle(cornerRadius: 18))
                    .padding(.top, 64).padding(.horizontal, 20).padding(.bottom, 20)
                    .allowsHitTesting(!panelOpen)
                    .accessibilityHidden(panelOpen)
                }
                if panelOpen {
                    Color.black.opacity(0.35).contentShape(Rectangle()).onTapGesture { panelOpen = false }
                    ScrollView {
                        sidebar.frame(minHeight: 690)
                    }
                    .frame(width: min(340, area.size.width - 40), height: area.size.height - 88)
                    .background(Theme.background, in: RoundedRectangle(cornerRadius: 18))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.line))
                    .padding(.leading, 20).padding(.top, 64)
                }
                HStack(spacing: 8) {
                    Button { panelOpen.toggle() } label: {
                        Image(systemName: panelOpen ? "xmark" : "line.3.horizontal")
                            .frame(width: 30, height: 28)
                    }
                    .accessibilityLabel(panelOpen ? "Close parameters" : "Open parameters")
                    .help("Bluetooth, programme mode and MIDI keyboard")
                    .keyboardShortcut("l", modifiers: .command)
                    if page != .monster && !panelOpen {
                        Button { page = .monster } label: { Label("Monster", systemImage: "arrow.uturn.backward") }
                    }
                    Spacer()
                    Button("On", systemImage: "power") { bluetooth.setPower(true) }
                        .disabled(!bluetooth.controlReady || page == .monster)
                    Button("Off") { vfx.stop(); mood.stop(); bluetooth.setPower(false) }.disabled(!bluetooth.controlReady)
                }
                .buttonStyle(MonsterOverlayButtonStyle())
                .padding(.horizontal, 20).padding(.top, 16)
                if let error = bluetooth.error {
                    VStack {
                        Spacer()
                        HStack {
                            Text(error).font(.caption)
                            Button("Dismiss") { bluetooth.error = nil }
                        }.padding(12).background(Theme.background, in: RoundedRectangle(cornerRadius: 12))
                    }.padding(24)
                }
            }
            .mask {
                // Feather only the outer alpha boundary; the artwork and controls stay sharp.
                RoundedRectangle(cornerRadius: area.size.width * 0.065, style: .continuous)
                    .inset(by: 5).fill(.white).blur(radius: 2.5)
            }
            // Keep keyboard focus available without drawing a system-accent box over the artwork.
            .monsterFocusEffectDisabled()
            .background(MonsterFocusRingSuppressor().allowsHitTesting(false))
            .foregroundStyle(Theme.ink).tint(Theme.accent)
        }
        .onAppear { [bluetooth] in
            vfx.output = { [weak bluetooth] colour, brightness in
                bluetooth?.setColour(red: colour.red, green: colour.green,
                                     blue: colour.blue, brightness: brightness)
            }
            mood.output = { [weak bluetooth] colour, brightness in
                bluetooth?.setColour(red: colour.red, green: colour.green,
                                     blue: colour.blue, brightness: brightness)
            }
        }
        .onChange(of: page) { next in
            panelOpen = false
            if next != .vfx && vfx.isRunning { vfx.stop() }
            if next != .mood && mood.isRunning { mood.stop() }
        }
        .onChange(of: panelOpen) { open in
            if open && vfx.isRunning { vfx.stop() }
            if open && mood.isRunning { mood.stop() }
        }
        .onChange(of: bluetooth.controlReady) { ready in
            if !ready && vfx.isRunning { vfx.stop() }
            if !ready && mood.isRunning { mood.stop() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            vfx.stop(); mood.stop()
        }
        .onDisappear { vfx.stop(); mood.stop(); vfx.output = nil; mood.output = nil }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Parameters").font(.title2.bold())
            HStack {
                Button("Minimise") { NSApp.keyWindow?.miniaturize(nil) }
                Button("Close app") { NSApp.terminate(nil) }
            }.font(.caption)
            Text("Programme mode").font(.headline)
            Picker("Programme mode", selection: $page) {
                ForEach(ProgrammePage.allCases) { option in
                    Text(option.title).tag(option)
                }
            }.labelsHidden().pickerStyle(.menu)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Toggle("MIDI keyboard", isOn: $midi.enabled)
                Text(midi.status).font(.caption)
                Text(midi.sources.isEmpty ? "Connect a USB MIDI keyboard, or route your DAW to LED MØNSTER Input." : midi.sources.joined(separator: ", "))
                    .font(.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                Text("Q W E R T Y · solid pads · notes 60–65\nA S D · gradient midpoints · notes 66–68\nAll MIDI channels · note-on selects colour")
                    .font(.caption).foregroundStyle(Theme.muted)
                Text(midi.lastNote).font(.caption)
            }
            Divider()
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                Text(bluetooth.adapter).font(.callout)
            }.foregroundStyle(Theme.muted)
            Button {
                if bluetooth.scanning { bluetooth.stopScan() } else { bluetooth.scan() }
            } label: {
                HStack {
                    if bluetooth.scanning { ProgressView().controlSize(.small) }
                    Text(bluetooth.scanning ? "Stop scan" : "Scan nearby")
                    Spacer()
                    Image(systemName: bluetooth.scanning ? "stop.fill" : "magnifyingglass")
                }.padding(.vertical, 5)
            }.buttonStyle(.borderedProminent).disabled(bluetooth.currentID != nil)
            Text("Power on your strip and close MohuanLED on your phone before connecting.")
                .font(.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Your lights").font(.headline)
                Spacer()
                Text("\(bluetooth.devices.filter { $0.name == BJLEDProtocol.name }.count)").foregroundStyle(Theme.muted)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if bluetooth.devices.filter({ showOtherDevices || $0.name == BJLEDProtocol.name }).isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "wave.3.right").font(.title).foregroundStyle(Theme.muted)
                            Text(bluetooth.scanning ? "Finding your strip…" : "No strip found yet").font(.headline)
                            Text(bluetooth.scanning ? "Scanning for 12 seconds." : "Click Scan nearby to find BJ_LED_M.")
                                .font(.caption).foregroundStyle(Theme.muted)
                        }.padding(.vertical, 20)
                    }
                    ForEach(bluetooth.devices.filter { showOtherDevices || $0.name == BJLEDProtocol.name }) { device in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: device.name == BJLEDProtocol.name ? "light.beacon.max" : "wave.3.right").foregroundStyle(Theme.accent)
                                Text(device.name == BJLEDProtocol.name ? "LED strip" : device.name).font(.headline).lineLimit(2)
                            }
                            if device.name == BJLEDProtocol.name { Text(device.name).font(.caption).foregroundStyle(Theme.muted) }
                            Text(device.rssi.map { "\($0) dBm" } ?? "Signal unavailable").font(.caption).foregroundStyle(Theme.muted)
                            if showOtherDevices { Text(device.id.uuidString).font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.muted).textSelection(.enabled) }
                            if bluetooth.currentID == device.id {
                                Text(bluetooth.connection).font(.caption).foregroundStyle(Theme.accent)
                                HStack {
                                    if bluetooth.connected { Button("Details") { page = .details } }
                                    Button(bluetooth.connected ? "Disconnect" : "Cancel") { vfx.stop(); mood.stop(); bluetooth.disconnect() }
                                }
                            } else {
                                Button(device.connectable ? "Connect" : "Not connectable") { bluetooth.connect(device.id) }
                                    .disabled(bluetooth.currentID != nil || !device.connectable)
                            }
                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            Toggle("Show other devices", isOn: $showOtherDevices).toggleStyle(.checkbox).font(.caption).foregroundStyle(Theme.muted)
            Text("Everything stays on your Mac.").font(.caption2).foregroundStyle(Theme.muted)
        }.padding(24).background(Theme.background)
    }
}

private extension View {
    @ViewBuilder
    func monsterFocusEffectDisabled() -> some View {
        if #available(macOS 14.0, *) { focusEffectDisabled() }
        else { self }
    }
}

struct ColourView: View {
    @ObservedObject var bluetooth: BluetoothStore
    @State private var red = 1.0
    @State private var green = 0.48
    @State private var blue = 0.16
    @State private var brightness = 0.75
    @State private var power = true
    @State private var scenes = LightScene.defaults
    @State private var sceneName = ""
    @State private var message = ""
    @State private var fineTune = false
    @State private var hexInput = "FF7A29"
    @State private var removedScene: LightScene?
    private let sceneKey = "luma.mac.scenes.v1"
    private var colour: Color { Color(red: red, green: green, blue: blue) }
    private var hex: String { String(format: "%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded())) }
    private let swatches: [(String, Double, Double, Double)] = [
        ("Warm white", 1, 0.77, 0.51), ("White", 1, 1, 1), ("Amber", 1, 0.38, 0.04),
        ("Rose", 1, 0.12, 0.35), ("Violet", 0.55, 0.16, 1), ("Blue", 0.06, 0.42, 1),
        ("Mint", 0.10, 1, 0.64)
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set the mood.").font(.system(size: 34, weight: .semibold))
                    Text(bluetooth.controlReady ? "Your room, in your colour." : "Connect your strip. Find your colour.").foregroundStyle(Theme.muted)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button { power = true; bluetooth.setPower(true) } label: { Label("On", systemImage: "power").frame(minWidth: 42) }
                    Button { power = false; bluetooth.setPower(false) } label: { Text("Off").frame(minWidth: 30) }
                }.controlSize(.large).disabled(!bluetooth.controlReady)
            }
            HStack(alignment: .center, spacing: 32) {
                VStack(spacing: 12) {
                    ColourWheel(red: $red, green: $green, blue: $blue) { commit() }
                        .frame(maxWidth: 300)
                    HStack(spacing: 8) {
                        Circle().fill(colour).frame(width: 10, height: 10)
                        Text("#" + hex).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                    }.foregroundStyle(Theme.muted)
                }.frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Brightness").font(.headline)
                            Spacer()
                            Text("\(Int((brightness * 100).rounded()))").font(.system(size: 36, weight: .light, design: .rounded)).monospacedDigit()
                            Text("%").foregroundStyle(Theme.muted)
                        }
                        Slider(value: $brightness, in: 0...1, onEditingChanged: { editing in if !editing { commit() } }).accessibilityLabel("Brightness")
                        HStack { Image(systemName: "sun.min"); Spacer(); Image(systemName: "sun.max") }.font(.caption).foregroundStyle(Theme.muted)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick colours").font(.headline)
                        HStack(spacing: 10) {
                            ForEach(swatches.indices, id: \.self) { i in
                                let swatch = swatches[i]
                                Button { red = swatch.1; green = swatch.2; blue = swatch.3; commit() } label: {
                                    Circle().fill(Color(red: swatch.1, green: swatch.2, blue: swatch.3)).frame(width: 25, height: 25)
                                        .overlay(Circle().strokeBorder(Theme.ink.opacity(0.3), lineWidth: 1))
                                }.buttonStyle(.plain).help(swatch.0).accessibilityLabel(swatch.0)
                            }
                        }
                    }
                    Button { commit() } label: {
                        HStack { Text("Apply to strip"); Spacer(); Image(systemName: "arrow.up.right") }.padding(.vertical, 7)
                    }.buttonStyle(.borderedProminent).disabled(!bluetooth.controlReady)
                    Text(bluetooth.controlReady ? (power ? "Changes send when you release the control." : "Last requested: off. Choosing a colour turns the strip on.") : "Offline preview · no commands sent")
                        .font(.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity)
            }.padding(24).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
            DisclosureGroup(isExpanded: $fineTune) {
                VStack(spacing: 16) {
                    HStack(spacing: 20) { channel("Red", value: $red); channel("Green", value: $green); channel("Blue", value: $blue) }
                    HStack {
                        Text("Hex colour").foregroundStyle(Theme.muted)
                        TextField("FF7A29", text: $hexInput).textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(width: 100)
                            .onSubmit { applyHex() }
                        Button("Set colour") { applyHex() }.disabled(parsedHex == nil)
                        Spacer()
                    }
                }.padding(.top, 16)
            } label: { Text("Fine tune").font(.callout).foregroundStyle(Theme.muted) }
            Divider()
            HStack(alignment: .firstTextBaseline) {
                Text("Saved scenes").font(.title3.weight(.semibold))
                Spacer()
                Text("\(scenes.count) of 24").font(.caption).foregroundStyle(Theme.muted)
            }
            if scenes.isEmpty { Text("Save a colour below to make it a one-click scene.").foregroundStyle(Theme.muted) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .leading)], spacing: 12) {
                ForEach(scenes) { scene in
                    HStack {
                        Button { apply(scene) } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 8).fill(Color(red: scene.red, green: scene.green, blue: scene.blue)).frame(width: 36, height: 44)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(scene.name).fontWeight(.medium).lineLimit(1)
                                    Text("\(Int((scene.brightness * 100).rounded()))% brightness").font(.caption).foregroundStyle(Theme.muted)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain).help(bluetooth.controlReady ? "Apply \(scene.name)" : "Preview \(scene.name)")
                        Menu {
                            Button("Remove scene") { removedScene = scene; save(scenes.filter { $0.id != scene.id }) }
                        } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 20).accessibilityLabel("Options for \(scene.name)")
                    }.padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            HStack {
                TextField("Name this colour…", text: $sceneName).textFieldStyle(.roundedBorder)
                    .onChange(of: sceneName) { value in if value.count > 32 { sceneName = String(value.prefix(32)) } }
                    .onSubmit { addScene() }
                Button("Save scene", systemImage: "plus") { addScene() }.disabled(sceneName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || scenes.count >= 24)
            }
            HStack {
                if !message.isEmpty { Text(message).font(.caption).foregroundStyle(Theme.muted) }
                if let removedScene {
                    Button("Undo remove") {
                        if scenes.count < 24 && !scenes.contains(where: { $0.id == removedScene.id }) { save(scenes + [removedScene]) }
                        self.removedScene = nil
                    }.font(.caption)
                }
                Spacer()
            }
        }.onAppear {
            if let data = UserDefaults.standard.data(forKey: sceneKey) {
                do { scenes = try LightScene.decode(data) }
                catch { message = "Saved scenes could not be read. Default previews are available." }
            }
        }
    }
    private var parsedHex: UInt32? {
        let value = hexInput.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard value.count == 6, value.allSatisfy({ $0.isHexDigit }) else { return nil }
        return UInt32(value, radix: 16)
    }
    private func applyHex() {
        guard let value = parsedHex else { return }
        red = Double((value >> 16) & 255) / 255; green = Double((value >> 8) & 255) / 255; blue = Double(value & 255) / 255
        commit()
    }
    private func channel(_ name: String, value: Binding<Double>) -> some View {
        VStack(spacing: 6) {
            HStack { Text(name); Spacer(); Text("\(Int((value.wrappedValue * 255).rounded()))").monospacedDigit().foregroundStyle(Theme.muted) }
            Slider(value: value, in: 0...1, onEditingChanged: { editing in if !editing { commit() } }).accessibilityLabel(name)
        }
    }
    private func commit() {
        hexInput = hex
        guard bluetooth.controlReady else { return }
        power = true
        bluetooth.setColour(red: red, green: green, blue: blue, brightness: brightness)
    }
    private func apply(_ scene: LightScene) {
        red = scene.red; green = scene.green; blue = scene.blue; brightness = scene.brightness; power = true; commit()
    }
    private func addScene() {
        let scene = LightScene(name: sceneName.trimmingCharacters(in: .whitespacesAndNewlines), red: red, green: green, blue: blue, brightness: brightness)
        guard scene.isValid, scenes.count < 24 else { return }
        save(scenes + [scene]); sceneName = ""
    }
    private func save(_ next: [LightScene]) {
        do { let data = try JSONEncoder().encode(next); UserDefaults.standard.set(data, forKey: sceneKey); scenes = next; message = "Saved on this Mac." }
        catch { message = "Could not save your scenes. Try again." }
    }
}
struct DetailsView: View {
    @ObservedObject var bluetooth: BluetoothStore
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Understand the connection.").font(.system(size: 28, weight: .semibold))
            Text("Discover the controller’s services and read the values it exposes.").foregroundStyle(Theme.muted)
            VStack(alignment: .leading, spacing: 8) {
                Label("MohuanLED app identified", systemImage: "checkmark.circle")
                Text("Version 1.4.7 · build 961 · reactive_ble_mobile").font(.callout).foregroundStyle(Theme.muted)
                Text("Community BJ_LED protocol: service EEA0, command characteristic EE01. Controls require BJ_LED_M and a matching writable characteristic. Sent commands are logged below; physical results are not read back.").font(.caption).foregroundStyle(Theme.muted)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
            if bluetooth.services.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(bluetooth.connected ? "No services available yet" : "Connect your controller first").font(.headline)
                    Text("Use Scan nearby, choose a device, then inspect its services here.").foregroundStyle(Theme.muted)
                }.padding(.vertical, 20)
            }
            ForEach(bluetooth.services) { service in
                VStack(alignment: .leading, spacing: 12) {
                    Text(service.primary ? "Primary service" : "Secondary service").font(.headline)
                    Text(service.uuid).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                    ForEach(service.characteristics) { c in
                        Divider()
                        Text(c.uuid).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                        Text(c.properties.joined(separator: " · ")).font(.caption).foregroundStyle(Theme.muted)
                        if let value = c.valueHex { Text(value.isEmpty ? "Empty value" : value).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
                        HStack {
                            if c.properties.contains("Read") { Button("Read value") { bluetooth.read(c.id) }.disabled(bluetooth.busy.contains(c.id)) }
                            if c.properties.contains("Notify") || c.properties.contains("Indicate") {
                                Button(c.notifying ? "Stop listening" : "Listen") { bluetooth.toggleNotifications(c.id) }.disabled(bluetooth.busy.contains(c.id))
                            }
                            if bluetooth.busy.contains(c.id) { ProgressView().controlSize(.small) }
                        }
                    }
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
            }
            Text("Reads are manual. Listening enables standard Bluetooth notifications; it does not send colour commands.").font(.caption).foregroundStyle(Theme.muted)
            Divider()
            HStack { Text("Activity").font(.title3.weight(.semibold)); Spacer(); Button("Clear log") { bluetooth.logs = [] } }
            if bluetooth.logs.isEmpty { Text("No activity yet.").foregroundStyle(Theme.muted) }
            ForEach(Array(bluetooth.logs.suffix(60).reversed())) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text(entry.event).font(.system(.callout, design: .monospaced)); Spacer(); Text(entry.time, style: .time).font(.caption).foregroundStyle(Theme.muted) }
                    if !entry.details.isEmpty { Text(entry.details).font(.caption).foregroundStyle(Theme.muted).textSelection(.enabled) }
                }
            }
            Text("Showing the latest 60 events. Reports retain up to 500 events and include nearby device identifiers.").font(.caption).foregroundStyle(Theme.muted)
        }
    }
}
