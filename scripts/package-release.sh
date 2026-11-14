#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
./scripts/build-app.sh "$@"

app_dir="$project_dir/dist/AirPods Adaptive.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_dir/Contents/Info.plist")"
binary_arches="$(lipo -archs "$app_dir/Contents/MacOS/AirPodsAdaptive")"
case "$binary_arches" in
  *arm64*x86_64*|*x86_64*arm64*) archive_arch=universal ;;
  *arm64*) archive_arch=arm64 ;;
  *x86_64*) archive_arch=x86_64 ;;
  *) echo "Unexpected binary architecture: $binary_arches" >&2; exit 1 ;;
esac

mkdir -p releases
archive="$project_dir/releases/airpods-adaptive-$version-macos-$archive_arch.zip"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "$app_dir" "$archive"
unzip -tq "$archive"
(cd releases && shasum -a 256 "$(basename "$archive")") > "$archive.sha256"
printf 'Packaged %s\n' "$archive"
