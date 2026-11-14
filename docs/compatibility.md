# Compatibility

## macOS and architecture

The deployment target is macOS 13.0. SwiftUI's menu bar UI sets that minimum. The release build includes `arm64` and `x86_64` slices for Apple Silicon and Intel Macs.

The deployment target records the minimum OS requested by the build. Accessory behavior also depends on firmware and macOS interfaces. This app has historical hardware evidence on macOS 26.7.1 with AirPods 5. Earlier macOS versions and Intel hardware have not received a recorded end-to-end test of this app.

The app checks for the macOS audio-device selector and Core Audio listening-mode property at runtime. If they are unavailable, it can use accessory mode reports received over Bluetooth. If neither path supplies a valid mode, the strength slider remains disabled.

## AirPods

The accessory must support Adaptive Audio. The recorded AirPods 5 test found audible changes while requesting values from 0 to 100 in steps of 10. A matching accessory strength report arrived for value 0; readback for the other steps was intermittent. This was a listening test, not an acoustic measurement.

LibrePods documents the Adaptive adjustment protocol using AirPods Pro 2. The airpods-ctl reconnect experiment also used AirPods Pro 2. Those are upstream findings, not test results for this app. Other Adaptive-capable AirPods may implement the same protocol, but each combination needs its own test.

AirPods without Adaptive Audio cannot gain it through this app. For discovery, the paired device's name must contain "AirPods".

## What remains to test

macOS 13 through 15, later OS releases beyond the recorded test, Intel runtime behavior, additional AirPods models and firmware versions, sustained playback, route restoration, long sessions and sleep/wake need hardware coverage. A successful build or packet test does not establish any of those results.

The app uses undocumented accessory settings and runtime macOS interfaces. Firmware or OS changes can affect them. It does not change firmware, install a daemon or require Apple-only entitlements.
