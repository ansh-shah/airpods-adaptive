import Foundation
import CoreAudio
import IOBluetooth
import ObjectiveC

/// Runtime-gated bridge to Apple's HAL mode property. It operates on the exact
/// paired device selected by the user, using its mapped output endpoint.
enum AudioModeControl {
    static func outputID(_ device: IOBluetoothDevice) -> AudioDeviceID? {
        let selector = NSSelectorFromString("outputAudioDeviceID")
        guard device.responds(to: selector),
              let implementation = class_getMethodImplementation(type(of: device), selector) else { return nil }
        typealias Getter = @convention(c) (AnyObject, Selector) -> UInt32
        let id = unsafeBitCast(implementation, to: Getter.self)(device, selector)
        return id == kAudioObjectUnknown ? nil : id
    }
    static func read(_ device: IOBluetoothDevice) -> ListeningMode? {
        guard let id = outputID(device) else { return nil }
        var address = modeAddress
        var size: UInt32 = 4, value: UInt32 = 0
        guard AudioObjectHasProperty(id, &address),
              AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr,
              size == 4, value <= UInt8.max else { return nil }
        return ListeningMode(rawValue: UInt8(value))
    }
    static func set(_ mode: ListeningMode, on device: IOBluetoothDevice) -> Bool {
        guard let id = outputID(device) else { return false }
        var address = modeAddress
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(id, &address, &settable) == noErr,
              settable.boolValue else { return false }
        var value = UInt32(mode.rawValue)
        return AudioObjectSetPropertyData(id, &address, 0, nil, 4, &value) == noErr
    }
    static func requestAudioConnection(_ device: IOBluetoothDevice) {
        guard let cls = NSClassFromString("IOBluetoothAudioManager") else { return }
        let shared = NSSelectorFromString("sharedAudioManager")
        guard let method = class_getClassMethod(cls, shared) else { return }
        typealias Shared = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
        let getter = unsafeBitCast(method_getImplementation(method), to: Shared.self)
        guard let manager = getter(cls as AnyObject, shared)?.takeUnretainedValue() else { return }
        let connect = NSSelectorFromString("connectToAudioDevice:")
        guard let method = class_getInstanceMethod(type(of: manager), connect) else { return }
        typealias Connect = @convention(c) (AnyObject, Selector, AnyObject) -> Void
        unsafeBitCast(method_getImplementation(method), to: Connect.self)(manager, connect, device)
    }
    static func isDefaultOutput(_ device: IOBluetoothDevice) -> Bool {
        var address = outputAddress
        var size: UInt32 = 4, value: UInt32 = 0
        return AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &value) == noErr
            && outputID(device) == value
    }
    static func restoreOutput(_ device: IOBluetoothDevice) -> Bool {
        guard var id = outputID(device) else { return false }
        var address = outputAddress
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, 4, &id) == noErr
    }
    private static var modeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: 0x6c73746d, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }
    private static var outputAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }
}
