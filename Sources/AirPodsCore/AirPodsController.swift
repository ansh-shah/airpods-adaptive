import Foundation
import Combine
import IOBluetooth

public struct PairedPod: Identifiable {
    public let id: String
    public let name: String
    public let connected: Bool
}

/// Owns one AAP channel per explicit session. Never disconnects automatically
/// after a lost channel, and never writes settings on app startup.
public final class AirPodsController: NSObject, ObservableObject, IOBluetoothL2CAPChannelDelegate {
    @Published public private(set) var devices: [PairedPod] = []
    @Published public var selectedID: String = ""
    @Published public var requestedStrength: Double = 50
    @Published public private(set) var status = "Connect to read your AirPods settings."
    @Published public private(set) var ready = false
    @Published public private(set) var connecting = false
    @Published public private(set) var mode: ListeningMode?
    @Published public private(set) var strength: Int?
    @Published public private(set) var pending = false
    @Published public private(set) var confirmedWrites = 0
    public var log: ((String) -> Void)?

    private var channel: IOBluetoothL2CAPChannel?
    private var device: IOBluetoothDevice?
    private var parser = SettingsParser()
    private var connectionTimer: Timer?
    private var requestTimer: Timer?
    private var attempt = 0
    private var generation = 0
    private var desiredStrength: Int?
    private var desiredMode: ListeningMode?
    private var strengthSent = false
    private var handshakeReceived = false
    private var shouldRestoreOutput = false
    private var routeTimer: Timer?

    public override init() { super.init(); refreshDevices() }

    public func refreshDevices() {
        let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        devices = paired.filter { ($0.name ?? "").localizedCaseInsensitiveContains("airpods") }
            .compactMap { d in
                guard let address = d.addressString else { return nil }
                return PairedPod(id: address, name: d.name ?? "AirPods", connected: d.isConnected())
            }.sorted { $0.name < $1.name }
        if !devices.contains(where: { $0.id == selectedID }) {
            selectedID = devices.first(where: { $0.connected })?.id ?? devices.first?.id ?? ""
        }
    }

    /// Called only by the user's Connect button, or explicit probe --connect.
    /// macOS usually requires reconnecting the Bluetooth link to open this PSM.
    public func connect() {
        disconnect()
        guard let target = IOBluetoothDevice(addressString: selectedID),
              devices.contains(where: { $0.id == selectedID }) else {
            status = "Pair your AirPods in Bluetooth settings, then refresh."
            return
        }
        device = target
        shouldRestoreOutput = AudioModeControl.isDefaultOutput(target)
        mode = AudioModeControl.read(target)
        connecting = true
        attempt = 0
        if mode == .adaptive { openAttempt() }
        else if AudioModeControl.set(.adaptive, on: target) {
            status = "Selecting Adaptive before connecting controls…"
            let session = generation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, self.generation == session, self.connecting else { return }
                self.mode = AudioModeControl.read(target)
                self.openAttempt()
            }
        } else { openAttempt() }
    }

    private func openAttempt() {
        guard connecting, let device else { return }
        attempt += 1
        status = "Connecting… audio may pause (attempt \(attempt)/3)."
        log?("Opening AAP channel, attempt \(attempt)")
        // This is the connect-time window found by airpods-ctl; audio briefly
        // stops here. The channel remains open for later slider changes.
        if device.isConnected() {
            let result = device.closeConnection()
            guard result == kIOReturnSuccess else {
                fail("Could not reconnect AirPods (\(errorCode(result))).")
                return
            }
        }
        var candidate: IOBluetoothL2CAPChannel?
        let result = device.openL2CAPChannelAsync(&candidate, withPSM: 0x1001, delegate: self)
        channel = candidate
        if result != kIOReturnSuccess || candidate == nil { retryOpen(); return }
        let session = generation
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            guard let self, self.generation == session, self.connecting else { return }
            self.retryOpen()
        }
    }

    private func retryOpen() {
        connectionTimer?.invalidate(); connectionTimer = nil
        let old = channel; channel = nil; old?.close()
        guard connecting else { return }
        guard attempt < 3 else { fail("Cannot open the AirPods control channel. Try Connect again."); return }
        let session = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, self.generation == session else { return }
            self.openAttempt()
        }
    }

    public func disconnect() {
        generation += 1
        let routeDevice = shouldRestoreOutput ? device : nil
        shouldRestoreOutput = false
        routeTimer?.invalidate(); routeTimer = nil
        connectionTimer?.invalidate(); requestTimer?.invalidate()
        connectionTimer = nil; requestTimer = nil
        connecting = false; ready = false; pending = false
        desiredStrength = nil; desiredMode = nil; strengthSent = false
        mode = nil; strength = nil
        parser = SettingsParser()
        handshakeReceived = false
        let old = channel; channel = nil; old?.close()
        if let routeDevice {
            AudioModeControl.requestAudioConnection(routeDevice)
            _ = AudioModeControl.restoreOutput(routeDevice)
            let closedSession = generation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, self.generation == closedSession,
                      !self.connecting, !self.ready else { return }
                _ = AudioModeControl.restoreOutput(routeDevice)
            }
        }
        device = nil
        status = "Control session closed."
    }

    public func setMode(_ value: ListeningMode) {
        guard ready, !pending else { return }
        if let device, AudioModeControl.set(value, on: device) {
            desiredMode = value; desiredStrength = nil; pending = true
            status = "Requesting \(value.name)…"
            startRequestTimeout()
            let session = generation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, self.generation == session, self.desiredMode == value,
                      AudioModeControl.read(device) == value else { return }
                self.mode = value; self.pending = false
                self.desiredMode = nil; self.requestTimer?.invalidate()
                self.status = "macOS reports \(value.name)."
            }
            return
        }
        desiredMode = value; desiredStrength = nil; pending = true
        status = "Requesting \(value.name)…"
        guard write(AAP.mode(value)) else { return }
        startRequestTimeout()
    }

    public func setStrength(_ value: Int) {
        guard ready, mode != nil, AAP.strength(value) != nil else { return }
        requestTimer?.invalidate()
        desiredMode = .adaptive; desiredStrength = value; pending = true; strengthSent = false
        status = "Requesting Adaptive noise reduction: \(value)…"
        // Strength takes effect only in Adaptive mode. Wait for a device mode
        // report before writing it when switching from another mode.
        if mode == .adaptive { sendStrength() }
        else { guard write(AAP.mode(.adaptive)) else { return } }
        startRequestTimeout()
    }

    private func sendStrength() {
        guard let desiredStrength, let packet = AAP.strength(desiredStrength) else { return }
        strengthSent = true
        _ = write(packet)
    }

    private func startRequestTimeout() {
        requestTimer?.invalidate()
        requestTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: false) { [weak self] _ in
            guard let self, self.pending else { return }
            self.pending = false; self.desiredMode = nil; self.desiredStrength = nil
            self.status = "Request sent; the AirPods have not reported this value. Readback is intermittent on this firmware."
            self.log?(self.status)
        }
    }

    @discardableResult private func write(_ bytes: [UInt8]) -> Bool {
        guard let channel else { return false }
        var buffer = bytes
        let result = buffer.withUnsafeMutableBytes { channel.writeSync($0.baseAddress, length: UInt16(bytes.count)) }
        guard result == kIOReturnSuccess else { fail("Bluetooth write failed (\(errorCode(result)))."); return false }
        log?("TX " + bytes.map { String(format: "%02X", $0) }.joined(separator: " "))
        return true
    }

    private func fail(_ message: String) { disconnect(); status = message; log?(message) }
    private func errorCode(_ code: IOReturn) -> String { String(format: "0x%08X", code) }

    public func l2capChannelOpenComplete(_ opened: IOBluetoothL2CAPChannel!, status error: IOReturn) {
        guard opened === channel, connecting else { return }
        connectionTimer?.invalidate(); connectionTimer = nil
        guard error == kIOReturnSuccess else { retryOpen(); return }
        log?("AAP channel opened; awaiting handshake reply")
        let session = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.generation == session, self.connecting else { return }
            guard self.write(AAP.handshake) else { return }
            self.connectionTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
                guard let self, self.generation == session, !self.handshakeReceived else { return }
                self.fail("AirPods did not answer the control handshake. This session cannot control settings.")
            }
        }
    }

    private func completeHandshake() {
        guard connecting, !handshakeReceived else { return }
        handshakeReceived = true
        connectionTimer?.invalidate(); connectionTimer = nil
        let session = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, self.generation == session, self.connecting else { return }
            guard self.write(AAP.capabilities) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self, self.generation == session, self.connecting else { return }
                guard self.write(AAP.notifications) else { return }
                self.connecting = false; self.ready = true
                self.status = self.mode == nil
                    ? "Connected. Waiting for the listening mode report."
                    : "Connected in \(self.mode!.name). Choose an Adaptive value."
                self.log?(self.status)
                self.startRouteRecovery()
            }
        }
    }

    private func startRouteRecovery() {
        guard shouldRestoreOutput else { return }
        if let device { AudioModeControl.requestAudioConnection(device) }
        var attempts = 0
        routeTimer?.invalidate()
        routeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self, let device = self.device else { timer.invalidate(); return }
            attempts += 1
            if AudioModeControl.restoreOutput(device) || attempts >= 30 {
                timer.invalidate(); self.routeTimer = nil
            }
        }
    }

    public func l2capChannelData(_ source: IOBluetoothL2CAPChannel!, data pointer: UnsafeMutableRawPointer!, length: Int) {
        guard source === channel, let pointer, length > 0 else { return }
        let bytes = [UInt8](Data(bytes: pointer, count: length))
        log?("RX packet \(length) bytes; header " + bytes.prefix(6).map { String(format: "%02X", $0) }.joined(separator: " "))
        if bytes.count >= 4, Array(bytes.prefix(4)) == [1, 0, 4, 0] { completeHandshake() }
        // No full packet logging: metadata packets may contain serial numbers.
        for setting in parser.consume(bytes) {
            log?("RX setting \(String(format: "%02X", setting.opcode)) = \(setting.value)")
            if setting.opcode == 0x0d { mode = ListeningMode(rawValue: setting.value) }
            else { strength = Int(setting.value) }
            if pending {
                if mode == desiredMode, desiredStrength != nil, !strengthSent { sendStrength() }
                let matchedStrength = desiredStrength == nil || (strengthSent && setting.opcode == 0x2e && strength == desiredStrength)
                if mode == desiredMode, matchedStrength {
                    pending = false; requestTimer?.invalidate()
                    confirmedWrites += 1
                    desiredStrength = nil; desiredMode = nil
                    status = "Device reported \(mode?.name ?? "Unknown")" + (strength.map { " · noise reduction \($0)" } ?? "")
                    log?("Requested setting confirmed by device report")
                }
            } else {
                status = "Device reported \(mode?.name ?? "Unknown")" + (strength.map { " · noise reduction \($0)" } ?? "")
            }
        }
    }

    public func l2capChannelClosed(_ closed: IOBluetoothL2CAPChannel!) {
        guard closed === channel else { return }
        fail("AirPods control session ended. Click Connect to start again.")
    }
}
