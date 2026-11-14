# AirPods Adaptive

Adjust Adaptive Audio from your Mac's menu bar. A slider lets you choose how much outside sound your AirPods let in, with presets at 0, 25, 50, 75 and 100.

This app is for Macs whose built-in controls do not expose that adjustment. It targets macOS 13 and later, including Intel Macs and Apple Silicon. Accessory control still depends on the AirPods model, firmware and macOS Bluetooth behavior. The recorded hardware test is AirPods 5 on macOS 26.7.1; operation on older releases needs hardware testing. See [compatibility](docs/compatibility.md).

The slider changes the noise reduction bias in Adaptive mode. It does not vary the strength of the separate Noise Cancellation mode.

## Install

For a packaged download, unzip `airpods-adaptive-0.1.0-macos-universal.zip`, then copy `AirPods Adaptive.app` to your Applications folder or `~/Applications`. The app has an ad-hoc signature and is not notarized. If macOS or your organization's policy blocks it, use an approved installation process or build from source. The app requires no administrator access of its own.

To build it yourself, install Apple's Command Line Tools with Swift 5.9 or later, then run these commands from the source directory:

```sh
./scripts/build-app.sh
open 'dist/AirPods Adaptive.app'
```

The default build includes Intel and Apple Silicon code. To build only one architecture, use `./scripts/build-app.sh --arch arm64` or `./scripts/build-app.sh --arch x86_64`. The project uses Apple's frameworks and has no external Swift package dependencies.

## Use the controls

1. Pair your AirPods in macOS Bluetooth settings. Keep "AirPods" in their device name so the app can find them.
2. Open the earbuds icon in the menu bar and select your pair. Click **Refresh** if it is missing.
3. Click **Connect controls** when a brief audio interruption is convenient. This selects Adaptive mode when the Mac exposes that control, then reconnects Bluetooth to open the accessory channel.
4. Once a listening mode is available, move the slider or choose a preset. Zero allows the most outside sound; 100 requests the most filtering. Adjusting the slider selects Adaptive mode.

The slider number is the requested value. **Last device report** shows the last value received from the accessory. A successful write does not establish that the AirPods applied it, and some firmware reports values intermittently. The app waits up to 25 seconds for a matching report and labels missing feedback.

**Disconnect controls** closes the control session. **Quit** closes it and exits. The AirPods can retain their last setting, so disconnecting does not reset the adjustment. Choose another listening mode in macOS, or request 50 to return to the slider's midpoint. Launching the app does not change settings.

## Limits and troubleshooting

- Connecting can pause a call or music and can move audio to the speakers. The app attempts to restore the previous AirPods output route. Restoration and uninterrupted playback are not guaranteed.
- If no listening mode arrives, the slider stays disabled. Disconnect and try **Connect controls** again. A lost session requires an explicit reconnect; the app does not reconnect in the background.
- AirPods must support Adaptive Audio. The app cannot add a listening mode to unsupported hardware. Upstream protocol evidence is described in the compatibility notes, separately from this app's hardware tests.
- Allow Bluetooth access if macOS requests it. A managed Mac may require an administrator-approved installation or Bluetooth policy change.
- This is a community app. Apple does not develop or endorse it.

## How it works

The app opens an L2CAP channel through IOBluetooth on PSM `0x1001`. It performs an accessory handshake, advertises capabilities and subscribes to settings reports. A session stays open for later adjustments, with at most three channel-open attempts for each explicit connection.

The accessory protocol uses setting `0x0D` for listening mode and `0x2E` for Adaptive noise reduction. The parser handles settings split across reads or combined into one read, and rejects malformed or out-of-range values. A runtime-checked Core Audio bridge selects Adaptive mode and attempts audio-route restoration when the relevant macOS interfaces are available. Those interfaces are undocumented and can differ between OS releases.

The app stores no device history and makes no internet requests. See [privacy](PRIVACY.md) for Bluetooth access and terminal output.

## Build and verify

```sh
./scripts/check.sh
./scripts/package-release.sh
```

The checks compile the app and terminal probe, then run packet and parser checks without accessing Bluetooth devices. The release script builds the universal app, verifies its ad-hoc signature and writes a ZIP plus a SHA-256 checksum to `releases/`. These checks do not establish hardware compatibility. [Contributing](CONTRIBUTING.md) describes a separate hardware test procedure.

The optional terminal probe builds with the package:

```sh
swift run --build-system native airpods-probe --help
```

Running it without arguments lists paired AirPods. `--connect` permits a Bluetooth reconnect, and `--connect --strength 25` also requests Adaptive mode and a value. Read its help before using it. Device names can appear in its terminal output.

## License and references

Code is available under the [MIT license](LICENSE). [Third-party notices](THIRD_PARTY_NOTICES.md) retain the transport reference's license and credit the protocol research.

Apple describes the adjustment in [Use Adaptive Audio with your AirPods](https://support.apple.com/en-us/104979). The app uses protocol information from [LibrePods](https://github.com/librepods-org/librepods/blob/main/docs/AAP%20Definitions.md) and the macOS reconnect approach documented by [airpods-ctl](https://github.com/BorgoGustavo/airpods-ctl).
