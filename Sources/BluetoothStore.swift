import AppKit
import CoreBluetooth
import Combine
import UniformTypeIdentifiers

final class BluetoothStore: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var adapter = "Not started"
    @Published var scanning = false
    @Published var connection = "Not connected"
    @Published var devices: [DeviceRecord] = []
    @Published var services: [ServiceRecord] = []
    @Published var logs: [LogEntry] = []
    @Published var error: String?
    @Published var currentID: UUID?
    @Published var connected = false
    @Published var busy: Set<String> = []
    @Published var controlReady = false
    @Published var commandStatus = "Connect BJ_LED_M to control your strip."
    @Published var requestedPower: Bool?
    private var commandHandle: CBCharacteristic?
    private var commandBuffer = LightCommandBuffer()
    private var writeTimer: Timer?
    private var blockedSince: Date?
    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var current: CBPeripheral?
    private var handles: [String: CBCharacteristic] = [:]
    private var scanTimer: Timer?
    private var connectionTimer: Timer?
    private var pendingScan = false
    private var cancelling = false
    private var operationTimers: [String: Timer] = [:]

    func log(_ event: String, _ details: String = "") {
        logs.append(LogEntry(event: event, details: details))
        if logs.count > 500 { logs.removeFirst(logs.count - 500) }
    }
    func scan() {
        guard current == nil else { return }
        error = nil
        if central == nil {
            pendingScan = true
            adapter = "Waiting for Bluetooth permission"
            central = CBCentralManager(delegate: self, queue: .main)
            return
        }
        guard central?.state == .poweredOn else {
            error = "Bluetooth is not ready. Turn it on and allow Luma in System Settings → Privacy & Security → Bluetooth."
            return
        }
        devices = []; peripherals = [:]
        central?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        scanning = true
        log("scan.started")
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in self?.stopScan() }
    }
    func stopScan() {
        pendingScan = false
        scanTimer?.invalidate(); scanTimer = nil
        central?.stopScan()
        if scanning { log("scan.stopped") }
        scanning = false
    }
    func connect(_ id: UUID) {
        guard current == nil, central?.state == .poweredOn, let peripheral = peripherals[id],
              devices.first(where: { $0.id == id })?.connectable == true else { return }
        stopScan(); error = nil
        services = []; handles = [:]
        current = peripheral; currentID = id; cancelling = false
        connection = "Connecting…"
        peripheral.delegate = self
        central?.connect(peripheral)
        log("connect.requested", id.uuidString)
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            guard let self, self.current?.identifier == id, !self.connected else { return }
            self.error = "Connection timed out. Keep the controller nearby and close its original app, then try again."
            self.disconnect()
        }
    }
    func disconnect() {
        guard let current else { return }
        resetCommands()
        cancelling = true; connected = false; connection = "Disconnecting…"
        connectionTimer?.invalidate()
        operationTimers.values.forEach { $0.invalidate() }; operationTimers = [:]; busy = []
        central?.cancelPeripheralConnection(current)
    }
    private func clearConnection() {
        resetCommands()
        connectionTimer?.invalidate(); connectionTimer = nil
        operationTimers.values.forEach { $0.invalidate() }; operationTimers = [:]
        current?.delegate = nil
        current = nil; currentID = nil; connected = false; cancelling = false
        services = []; handles = [:]; busy = []
        connection = "Not connected"
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: adapter = "Bluetooth on"
        case .poweredOff: adapter = "Bluetooth off"
        case .unauthorized: adapter = "Permission needed"
        case .unsupported: adapter = "Bluetooth unavailable"
        case .resetting: adapter = "Bluetooth restarting"
        default: adapter = "Checking Bluetooth"
        }
        log("adapter", adapter)
        if central.state == .poweredOn {
            if pendingScan { pendingScan = false; scan() }
        } else if central.state != .unknown && central.state != .resetting {
            stopScan(); clearConnection()
            if central.state == .unauthorized { error = "Allow Luma in System Settings → Privacy & Security → Bluetooth, then scan again." }
        } else {
            if scanning { stopScan() }
            clearConnection()
        }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard scanning else { return }
        let id = peripheral.identifier
        guard peripherals[id] != nil || devices.count < 100 else { return }
        let record = DeviceRecord(id: id,
            name: advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "Unnamed device",
            rssi: RSSI.intValue == 127 ? nil : RSSI.intValue,
            connectable: (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? true,
            advertisedServices: (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []).map(\.uuidString),
            manufacturerDataHex: (advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data)?.hex,
            serviceDataHex: Dictionary(uniqueKeysWithValues: (advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] ?? [:]).map { ($0.key.uuidString, $0.value.hex) }))
        if peripherals[id] == nil { log("device.discovered", "\(record.name) · \(id.uuidString)") }
        peripherals[id] = peripheral
        devices.removeAll { $0.id == id }; devices.append(record)
        devices.sort { ($0.rssi ?? -999) > ($1.rssi ?? -999) }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard current === peripheral, !cancelling else { central.cancelPeripheralConnection(peripheral); return }
        connectionTimer?.invalidate(); connected = true; connection = "Discovering services…"
        log("connected", peripheral.identifier.uuidString)
        peripheral.discoverServices(nil)
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard current === peripheral else { return }
        if !cancelling { self.error = error?.localizedDescription ?? "Could not connect. Try again with the original app closed." }
        log("connect.failed", error?.localizedDescription ?? "Cancelled")
        clearConnection()
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard current === peripheral else { return }
        log("disconnected", error?.localizedDescription ?? peripheral.identifier.uuidString)
        if let error, !cancelling { self.error = error.localizedDescription }
        clearConnection()
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard current === peripheral, connected else { return }
        if let error { self.error = error.localizedDescription; connection = "Service discovery failed"; return }
        refreshServices(peripheral)
        for service in peripheral.services ?? [] { peripheral.discoverCharacteristics(nil, for: service) }
        connection = "Connected"
        log("services.discovered", "\(peripheral.services?.count ?? 0) services")
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard current === peripheral, connected else { return }
        if let error { self.error = error.localizedDescription; log("discovery.failed", error.localizedDescription) }
        refreshServices(peripheral)
    }
    private func key(_ c: CBCharacteristic) -> String { String(describing: ObjectIdentifier(c)) }
    private func refreshServices(_ peripheral: CBPeripheral) {
        var nextHandles: [String: CBCharacteristic] = [:]
        services = (peripheral.services ?? []).map { service in
            ServiceRecord(id: String(describing: ObjectIdentifier(service)), uuid: service.uuid.uuidString, primary: service.isPrimary,
                characteristics: (service.characteristics ?? []).map { c in
                    let id = key(c); nextHandles[id] = c
                    var properties: [String] = []
                    if c.properties.contains(.read) { properties.append("Read") }
                    if c.properties.contains(.write) { properties.append("Write with response") }
                    if c.properties.contains(.writeWithoutResponse) { properties.append("Write without response") }
                    if c.properties.contains(.notify) { properties.append("Notify") }
                    if c.properties.contains(.indicate) { properties.append("Indicate") }
                    return CharacteristicRecord(id: id, uuid: c.uuid.uuidString, serviceUUID: service.uuid.uuidString, properties: properties, notifying: c.isNotifying, valueHex: c.value?.hex)
                })
        }
        handles = nextHandles
        let name = devices.first { $0.id == currentID }?.name
        let candidates = nextHandles.values.filter {
            BJLEDProtocol.matches(name: name, service: $0.service?.uuid.uuidString ?? "",
                                  characteristic: $0.uuid.uuidString,
                                  withoutResponse: $0.properties.contains(.writeWithoutResponse))
        }
        let wasReady = controlReady
        commandHandle = candidates.count == 1 ? candidates.first : nil
        controlReady = connected && !cancelling && commandHandle != nil
        if controlReady && !wasReady {
            commandStatus = "BJ_LED_M ready · choose a colour or power command."
            log("control.ready", "service=EEA0 characteristic=EE01 mode=withoutResponse; community protocol, physical result unverified")
        } else if !controlReady && wasReady { resetCommands() }
    }
    private func startOperation(_ id: String) {
        busy.insert(id)
        operationTimers[id]?.invalidate()
        operationTimers[id] = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            self?.busy.remove(id); self?.operationTimers.removeValue(forKey: id)
            self?.error = "The controller did not respond. Retry or reconnect."
        }
    }
    private func finishOperation(_ id: String) {
        busy.remove(id); operationTimers.removeValue(forKey: id)?.invalidate()
    }
    func read(_ id: String) {
        guard connected, !busy.contains(id), let current, let c = handles[id], c.properties.contains(.read) else { return }
        startOperation(id); current.readValue(for: c)
    }
    func toggleNotifications(_ id: String) {
        guard connected, !busy.contains(id), let current, let c = handles[id], c.properties.contains(.notify) || c.properties.contains(.indicate) else { return }
        startOperation(id); current.setNotifyValue(!c.isNotifying, for: c)
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard current === peripheral, connected else { return }
        finishOperation(key(characteristic))
        if let error { self.error = error.localizedDescription; log("value.failed", error.localizedDescription) }
        else { log("value.received", "service=\(characteristic.service?.uuid.uuidString ?? "") characteristic=\(characteristic.uuid.uuidString) hex=\(characteristic.value?.hex ?? "unavailable")") }
        refreshServices(peripheral)
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard current === peripheral, connected else { return }
        finishOperation(key(characteristic))
        if let error { self.error = error.localizedDescription }
        log("notification.state", "\(characteristic.uuid.uuidString) · \(characteristic.isNotifying ? "listening" : "off")\(error.map { " · " + $0.localizedDescription } ?? "")")
        refreshServices(peripheral)
    }
    private func resetCommands() {
        writeTimer?.invalidate(); writeTimer = nil
        commandBuffer.clear(); blockedSince = nil; commandHandle = nil
        controlReady = false; requestedPower = nil
        commandStatus = "Connect BJ_LED_M to control your strip."
    }
    func setPower(_ on: Bool) {
        guard controlReady else { error = "Connect BJ_LED_M and wait for service discovery before sending commands."; return }
        commandBuffer.power(on); requestedPower = on
        commandStatus = "Queued: power \(on ? "on" : "off")"
        startWriter()
    }
    func setColour(red: Double, green: Double, blue: Double, brightness: Double) {
        guard controlReady else { return }
        guard let packet = BJLEDProtocol.colour(red: red, green: green, blue: blue, brightness: brightness) else {
            error = "Colour and brightness must be within their slider ranges."; return
        }
        // An explicit colour action turns the strip on; connecting never sends commands.
        commandBuffer.colour(packet, turnOn: requestedPower != true)
        requestedPower = true
        commandStatus = "Queued: colour and brightness"
        startWriter()
    }
    private func startWriter() {
        guard writeTimer == nil else { return }
        writeTimer = ControlWriteClock.schedule { [weak self] in self?.drainCommand() }
    }
    private func drainCommand() {
        guard controlReady, connected, !cancelling, central?.state == .poweredOn,
              let current, current.state == .connected, let commandHandle,
              commandHandle.service?.peripheral === current else { resetCommands(); return }
        guard !commandBuffer.items.isEmpty else {
            writeTimer?.invalidate(); writeTimer = nil; blockedSince = nil; return
        }
        guard current.canSendWriteWithoutResponse else {
            if blockedSince == nil { blockedSince = Date() }
            if let start = blockedSince, Date().timeIntervalSince(start) > 5 {
                commandBuffer.clear(); writeTimer?.invalidate(); writeTimer = nil
                blockedSince = nil; requestedPower = nil
                error = "Bluetooth could not send the command. Reconnect the strip and try again."
                commandStatus = "Command not sent."
            }
            return
        }
        blockedSince = nil
        guard let command = commandBuffer.pop() else { return }
        guard command.packet.count <= current.maximumWriteValueLength(for: .withoutResponse) else {
            commandBuffer.clear(); requestedPower = nil
            error = "The controller's write size is too small."; commandStatus = "Command not sent."; return
        }
        current.writeValue(command.packet, for: commandHandle, type: .withoutResponse)
        commandStatus = "Sent: \(command.label.lowercased()) · no device acknowledgement"
        log("command.sent", "device=\(current.identifier.uuidString) service=EEA0 characteristic=EE01 mode=withoutResponse hex=\(command.packet.hex)")
    }
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        // The running 120ms timer drains after backpressure clears, preserving pacing.
        guard current === peripheral else { return }
        blockedSince = nil
    }
    func exportReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Luma-controller-report.json"
        panel.message = "Includes nearby device identifiers and Bluetooth data. Choose where to save your report."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let report = DiscoveryReport(protocolStatus: controlReady ? "community-bj-led-protocol-hardware-unverified" : "unidentified", adapter: adapter, device: devices.first { $0.id == currentID }, nearbyDevices: devices, services: services, logs: logs)
            try report.encoded().write(to: url, options: .atomic)
            log("report.saved", url.lastPathComponent)
        } catch { self.error = "Could not save the report: \(error.localizedDescription)" }
    }
    func shutdown() { stopScan(); disconnect() }
}
