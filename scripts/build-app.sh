#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

architectures=(arm64 x86_64)
case "${1:-}" in
  ""|--universal)
    if [ "$#" -gt 1 ]; then echo 'Unexpected build arguments' >&2; exit 2; fi
    ;;
  --arch)
    if [ "$#" -ne 2 ]; then echo '--arch requires exactly one architecture' >&2; exit 2; fi
    case "${2:-}" in
      arm64|x86_64) architectures=("$2") ;;
      *) echo 'Usage: scripts/build-app.sh [--universal | --arch arm64 | --arch x86_64]' >&2; exit 2 ;;
    esac
    ;;
  *) echo 'Usage: scripts/build-app.sh [--universal | --arch arm64 | --arch x86_64]' >&2; exit 2 ;;
esac

app_dir="$project_dir/dist/AirPods Adaptive.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
binaries=()
for build_arch in "${architectures[@]}"; do
  target_triple="$build_arch-apple-macosx13.0"
  swift build --build-system native -c release --triple "$target_triple" \
    --product AirPodsAdaptive \
    -Xswiftc -gnone \
    -Xswiftc -file-prefix-map -Xswiftc "$project_dir=/source/airpods-adaptive"
  binary_dir="$(swift build --build-system native -c release --triple "$target_triple" --show-bin-path)"
  binaries+=("$binary_dir/AirPodsAdaptive")
done

if [ "${#binaries[@]}" -eq 1 ]; then
  cp "${binaries[0]}" "$app_dir/Contents/MacOS/AirPodsAdaptive"
else
  lipo -create "${binaries[@]}" -output "$app_dir/Contents/MacOS/AirPodsAdaptive"
fi
# Remove local compiler paths and debugging information from the download.
strip -S "$app_dir/Contents/MacOS/AirPodsAdaptive"

cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>AirPodsAdaptive</string>
<key>CFBundleIdentifier</key><string>io.github.ansh-shah.airpods-adaptive</string>
<key>CFBundleName</key><string>AirPods Adaptive</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSBluetoothAlwaysUsageDescription</key><string>Connect to your paired AirPods to adjust Adaptive Audio and read back their settings.</string>
</dict></plist>
PLIST
cp LICENSE THIRD_PARTY_NOTICES.md PRIVACY.md "$app_dir/Contents/Resources/"
plutil -lint "$app_dir/Contents/Info.plist"
codesign --force --sign - "$app_dir"
codesign --verify --strict "$app_dir"
printf 'Built %s (%s)\n' "$app_dir" "${architectures[*]}"
