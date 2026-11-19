#!/bin/bash
# Assembles dist/Deskling.app from a SwiftPM build directory. Does not sign.
# Usage: scripts/assemble.sh <directory containing the built Deskling binary>
set -euo pipefail

cd "$(dirname "$0")/.."
bin_dir="$1"
version="$(tr -d '[:space:]' < VERSION)"
app="dist/Deskling.app"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers" "$app/Contents/Resources/animations"
cp "$bin_dir/Deskling" "$app/Contents/MacOS/Deskling"
# Run by Claude Code and Codex hooks to tell the app what the agent is doing.
cp "$bin_dir/deskling-hook" "$app/Contents/Helpers/deskling-hook"
sed "s/@VERSION@/$version/g" Info.plist.in > "$app/Contents/Info.plist"
cp Resources/AppIcon.icns Resources/MenuIcon.png "Resources/MenuIcon@2x.png" "$app/Contents/Resources/"
cp .build/animations/*.json "$app/Contents/Resources/animations/"
cp -R .build/characters "$app/Contents/Resources/characters"
# The updater. Its XPC services are only for sandboxed apps, and Deskling is not one.
mkdir -p "$app/Contents/Frameworks"
ditto "$bin_dir/Sparkle.framework" "$app/Contents/Frameworks/Sparkle.framework"
rm -rf "$app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" "$app/Contents/Frameworks/Sparkle.framework/XPCServices"
# Resource bundles SwiftPM builds for dependencies (lottie-ios ships one).
find "$bin_dir" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$app/Contents/Resources/" \;
echo "$app ($version)"
