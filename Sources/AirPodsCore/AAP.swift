import Foundation

public enum ListeningMode: UInt8, CaseIterable {
    case off = 1, cancellation = 2, transparency = 3, adaptive = 4
    public var name: String {
        switch self {
        case .off: return "Off"
        case .cancellation: return "Noise Cancellation"
        case .transparency: return "Transparency"
        case .adaptive: return "Adaptive"
        }
    }
}

public enum AAP {
    // Standard LibrePods handshake. The alternate 0x10 at byte 12 used by
    // airpods-ctl did not produce a reply on local AirPods 5 / firmware 9A350.
    public static let handshake: [UInt8] = [0, 0, 4, 0, 1, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    public static let capabilities: [UInt8] = [4, 0, 4, 0, 0x4d, 0, 0xd7, 0, 0, 0, 0, 0, 0, 0]
    public static let notifications: [UInt8] = [4, 0, 4, 0, 0x0f, 0, 0xff, 0xff, 0xff, 0xff]
    public static func mode(_ mode: ListeningMode) -> [UInt8] {
        [4, 0, 4, 0, 9, 0, 0x0d, mode.rawValue, 0, 0, 0]
    }
    public static func strength(_ value: Int) -> [UInt8]? {
        guard (0...100).contains(value) else { return nil }
        return [4, 0, 4, 0, 9, 0, 0x2e, UInt8(value), 0, 0, 0]
    }
}

public struct Setting: Equatable {
    public let opcode: UInt8
    public let value: UInt8
}

/// Extracts the two known fixed-size settings from coalesced reads, retaining
/// a possible partial frame between reads. Other packets are ignored.
public struct SettingsParser {
    private var buffer: [UInt8] = []
    public init() {}
    public mutating func consume(_ bytes: [UInt8]) -> [Setting] {
        buffer += bytes
        var result: [Setting] = []
        var offset = 0
        while offset + 11 <= buffer.count {
            if Array(buffer[offset..<offset + 6]) == [4, 0, 4, 0, 9, 0],
               [UInt8(0x0d), UInt8(0x2e)].contains(buffer[offset + 6]),
               Array(buffer[offset + 8..<offset + 11]) == [0, 0, 0] {
                let opcode = buffer[offset + 6], value = buffer[offset + 7]
                if (opcode == 0x0d && ListeningMode(rawValue: value) != nil)
                    || (opcode == 0x2e && value <= 100) {
                    result.append(Setting(opcode: opcode, value: value))
                }
                offset += 11
            } else { offset += 1 }
        }
        buffer = Array(buffer.suffix(min(10, buffer.count - offset)))
        return result
    }
}
