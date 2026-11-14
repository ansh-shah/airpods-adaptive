import SwiftUI
import AppKit
import AirPodsCore

@main
struct AirPodsAdaptiveApp: App {
    @StateObject private var controller = AirPodsController()
    var body: some Scene {
        MenuBarExtra("AirPods Adaptive", systemImage: "earbuds") {
            ControlPanel(controller: controller)
        }.menuBarExtraStyle(.window)
    }
}

struct ControlPanel: View {
    @ObservedObject var controller: AirPodsController
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "earbuds").font(.title2)
                VStack(alignment: .leading, spacing: 3) {
                    Text("AirPods Adaptive").font(.headline)
                    Text("Choose how much outside sound to let in")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if controller.devices.isEmpty {
                Text("Pair your AirPods in macOS Bluetooth settings.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Picker("AirPods", selection: $controller.selectedID) {
                    ForEach(controller.devices) { device in
                        Text(device.name + (device.connected ? " · connected" : ""))
                            .tag(device.id)
                    }
                }.disabled(controller.connecting || controller.ready)
            }
            if controller.ready {
                Picker("Listening mode", selection: Binding(
                    get: { controller.mode?.rawValue ?? 0 },
                    set: { if let mode = ListeningMode(rawValue: $0) { controller.setMode(mode) } }
                )) {
                    if controller.mode == nil { Text("Unknown").tag(UInt8(0)) }
                    ForEach(ListeningMode.allCases, id: \.rawValue) { mode in
                        Text(mode.name).tag(mode.rawValue)
                    }
                }.disabled(controller.pending)
                Divider()
                HStack {
                    Text("Adaptive noise reduction").font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(Int(controller.requestedStrength))").monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $controller.requestedStrength, in: 0...100, step: 1, onEditingChanged: { editing in
                    if !editing { controller.setStrength(Int(controller.requestedStrength)) }
                }).disabled(controller.mode == nil)
                    .accessibilityLabel("Adaptive noise reduction")
                HStack {
                    Text("More outside sound")
                    Spacer()
                    Text("Less outside sound")
                }.font(.caption).foregroundStyle(.secondary)
                HStack {
                    ForEach([0, 25, 50, 75, 100], id: \.self) { level in
                        Button("\(level)") {
                            controller.requestedStrength = Double(level)
                            controller.setStrength(level)
                        }.frame(maxWidth: .infinity)
                    }
                }.disabled(controller.mode == nil)
                if controller.mode == nil {
                    Text("Slider unavailable: no listening mode report from the AirPods.")
                        .font(.caption).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Last device report: " + (controller.strength.map { "\($0) / 100" } ?? "not received"))
                    .font(.caption).foregroundStyle(.secondary)
                Text("Adjusting this control switches to Adaptive mode. It does not set the strength of full Noise Cancellation.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: 8) {
                if controller.connecting { ProgressView().controlSize(.small) }
                Text(controller.status).font(.caption).fixedSize(horizontal: false, vertical: true)
            }
            if !controller.ready && !controller.connecting {
                Text("Connect selects Adaptive mode and briefly reconnects Bluetooth, which may pause your audio. Later adjustments use the same session.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if controller.ready || controller.connecting {
                    Button(controller.connecting ? "Cancel" : "Disconnect controls") { controller.disconnect() }
                } else {
                    Button("Connect controls") { controller.connect() }
                        .buttonStyle(.borderedProminent).disabled(controller.devices.isEmpty)
                    Button("Refresh") { controller.refreshDevices() }
                }
                Spacer()
                Button("Quit") { controller.disconnect(); NSApp.terminate(nil) }
            }
        }
        .padding(20).frame(width: 380)
        .onChange(of: controller.strength) { value in
            if let value, !controller.pending { controller.requestedStrength = Double(value) }
        }
    }
}
