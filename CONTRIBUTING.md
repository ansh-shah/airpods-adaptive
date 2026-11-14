# Contributing

Use macOS with Apple's Command Line Tools and Swift 5.9 or later. The app depends on SwiftUI, Core Audio and IOBluetooth, so Linux builds are not supported.

## Local checks

```sh
./scripts/check.sh
./scripts/build-app.sh
```

The first command builds every target and runs `PacketChecks`. These tests exercise the actual packet generator and stream parser. They do not instantiate the Bluetooth controller or connect to a device. Add packet fixtures as byte arrays, with device identifiers removed.

The second command creates a universal app in `dist/`. It does not launch the app. Use `./scripts/package-release.sh` to build and package it for distribution. Release builds use an ad-hoc signature; notarization requires a separate developer signing process.

## Hardware tests

Hardware tests need someone who can accept a brief Bluetooth and audio interruption. Run them when a call or other audio session will not be disrupted.

Record the Mac's architecture, macOS version, AirPods model and firmware. Keep device names, Bluetooth addresses and serial numbers out of reports. Check the following separately:

- The app opens without changing the AirPods' settings.
- **Connect controls** reaches a working session and reports a listening mode.
- Presets request the expected Adaptive values. Record device reports separately from audible observations.
- Disconnect, channel loss and a new connection leave the controls in a usable state.
- Note whether audio resumes on the AirPods, and what happens after sleep and wake.

An accepted Bluetooth write is transport evidence. A matching settings report is device readback. A listening observation is subjective evidence. Keep all three distinct when reporting results. For compatibility claims, include the tested OS and hardware combination.

## Changes and issues

Keep changes focused on accessory control, compatibility or usability. Preserve the distinction between Adaptive noise reduction and full Noise Cancellation. Runtime-check undocumented selectors and Core Audio properties before use, retain explicit user control over reconnects, and avoid raw accessory packet logs.

For a bug report, include the steps, requested value, displayed status and whether a matching device report arrived. Share only sanitized output. Credit protocol sources and retain their license notices when reusing code.
