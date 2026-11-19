#!/bin/bash
# Assembles dist/Clawd.app from a SwiftPM build directory. Does not sign.
# Usage: scripts/assemble.sh <directory containing the built Clawd binary>
set -euo pipefail

cd "$(dirname "$0")/.."
bin_dir="$1"
version="$(tr -d '[:space:]' < VERSION)"
app="dist/Clawd.app"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/animations"
cp "$bin_dir/Clawd" "$app/Contents/MacOS/Clawd"
sed "s/@VERSION@/$version/g" Info.plist.in > "$app/Contents/Info.plist"
cp Resources/AppIcon.icns Resources/MenuIcon.png "Resources/MenuIcon@2x.png" "$app/Contents/Resources/"
cp .build/animations/*.json "$app/Contents/Resources/animations/"
# Resource bundles SwiftPM builds for dependencies (lottie-ios ships one).
find "$bin_dir" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$app/Contents/Resources/" \;
echo "$app ($version)"
