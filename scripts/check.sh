#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
bash -n scripts/build-app.sh scripts/package-release.sh scripts/check.sh
swift build --build-system native
swift run --build-system native PacketChecks
