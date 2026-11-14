# Privacy

AirPods Adaptive works with devices already paired to your Mac. It has no account, telemetry, analytics, advertising or update-checking service. The app and terminal probe contain no internet request code.

## Bluetooth and device data

The app reads paired device names, Bluetooth addresses and connection state through macOS. It uses an address in memory to keep your selected pair separate from other devices. It does not save device names, addresses or serial numbers to a file or preference store.

Only clicking **Connect controls**, or running the terminal probe with `--connect`, opens the accessory control channel. Connecting can change listening mode and interrupt audio. The menu app sends strength requests when you finish moving the slider or select a preset. The AirPods can keep those settings after the app exits.

macOS controls Bluetooth permission and maintains its own device records and system logs. This app does not change those retention policies.

## Terminal output

The optional terminal probe prints paired device names, connection status, request packets and parsed settings. It does not print Bluetooth addresses or full incoming accessory packets. Full incoming packets can contain serial numbers, so the logger prints only a six-byte header and recognized setting values.

Terminal scrollback, redirected output and system logs can outlive a session. Remove device names and other identifiers before sharing a bug report.

## Removing the app

Quit the app and delete its application bundle. There is no application account or saved device-history database to remove. Deleting the app does not unpair your AirPods or reset a setting stored by the accessory. You can manage Bluetooth permissions and paired devices in macOS System Settings.
