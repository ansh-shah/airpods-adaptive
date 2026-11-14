import Foundation
import AirPodsCore

let args = Array(CommandLine.arguments.dropFirst())
let usage = """
Usage:
  airpods-probe                    List paired AirPods; no connection changes.
  airpods-probe --connect          Reconnect and read settings for 12 seconds.
  airpods-probe --connect --strength 0..100
                                  Switch to Adaptive and request noise reduction.
  Add --device 'exact name' when more than one pair is available.
Connect briefly interrupts Bluetooth audio. Settings persist after the probe exits.
"""
if args.contains("--help") { print(usage); exit(0) }
var name: String?
var targetStrength: Int?
var shouldConnect = false
var i = 0
while i < args.count {
    switch args[i] {
    case "--connect": shouldConnect = true
    case "--device":
        guard i + 1 < args.count else { print(usage); exit(2) }
        i += 1; name = args[i]
    case "--strength":
        guard i + 1 < args.count, let n = Int(args[i + 1]), (0...100).contains(n) else { print(usage); exit(2) }
        i += 1; targetStrength = n
    default: print(usage); exit(2)
    }
    i += 1
}
guard targetStrength == nil || shouldConnect else { print("--strength requires --connect"); exit(2) }
let controller = AirPodsController()
controller.log = { print($0); fflush(stdout) }
for pod in controller.devices { print("\(pod.name): \(pod.connected ? "connected" : "paired")") }
if let name {
    let matches = controller.devices.filter { $0.name == name }
    guard matches.count == 1 else { print("Device name must match exactly one pair."); exit(2) }
    controller.selectedID = matches[0].id
} else if shouldConnect && controller.devices.count > 1 {
    print("Specify --device 'exact name' to select one pair."); exit(2)
}
if !shouldConnect { exit(0) }
guard !controller.devices.isEmpty else { print("No paired AirPods found."); exit(1) }
controller.connect()
let deadline = Date().addingTimeInterval(65)
var readyAt: Date?
var sent = false
while Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    if controller.ready {
        if readyAt == nil { readyAt = Date() }
        if let targetStrength, !sent, Date().timeIntervalSince(readyAt!) > 2 {
            sent = true; controller.setStrength(targetStrength)
        }
        if sent && !controller.pending { break }
        if targetStrength == nil && Date().timeIntervalSince(readyAt!) >= 12 { break }
    } else if !controller.connecting { break }
}
print(controller.status)
print("Mode: \(controller.mode?.name ?? "unreported"); adaptive noise reduction: \(controller.strength.map(String.init) ?? "unreported")")
let success = targetStrength == nil ? (controller.ready && controller.mode != nil) : controller.confirmedWrites > 0
controller.disconnect()
exit(success ? 0 : 1)
