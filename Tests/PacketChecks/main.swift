import Foundation
import AirPodsCore

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
check(AAP.handshake == [0, 0, 4, 0, 1, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0], "Standard handshake with all-zero tail")
check(AAP.capabilities == [4,0,4,0,0x4d,0,0xd7,0,0,0,0,0,0,0], "Tested LibrePods feature mask")
let mode = AAP.mode(.adaptive)
let strength = AAP.strength(25)!
let bytes = [UInt8(0xaa), 0xbb] + mode + strength
for split in 0...bytes.count {
    var parser = SettingsParser()
    let reports = parser.consume(Array(bytes.prefix(split))) + parser.consume(Array(bytes.dropFirst(split)))
    check(reports.map(\.opcode) == [0x0d, 0x2e] && reports.map(\.value) == [4, 25], "Split boundary \(split)")
}
var parser = SettingsParser()
var bytewise: [Setting] = []
for byte in bytes { bytewise += parser.consume([byte]) }
check(bytewise.map(\.value) == [4, 25], "Bytewise stream")
var bad = AAP.strength(50)!
bad[7] = 101
var malformed = AAP.mode(.adaptive)
malformed[10] = 1
var recovery = SettingsParser()
let recovered = recovery.consume(bad + malformed + [UInt8](repeating: 0xff, count: 10000) + AAP.strength(0)!)
check(recovered.map(\.opcode) == [0x2e] && recovered.map(\.value) == [0], "Reject malformed frames and recover")
check(AAP.strength(-1) == nil && AAP.strength(101) == nil, "Strength range")
check(AAP.strength(0) == [4, 0, 4, 0, 9, 0, 0x2e, 0, 0, 0, 0], "More outside sound packet")
check(AAP.strength(100) == [4, 0, 4, 0, 9, 0, 0x2e, 100, 0, 0, 0], "Less outside sound packet")
print("PASS: all 25 split boundaries, bytewise input, coalesced settings, malformed reports, bounds, and recovery.")
