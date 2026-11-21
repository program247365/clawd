#!/bin/bash
# Builds, signs, notarizes, and staples dist/Deskling.dmg. Uploads nothing. Safe to rerun.
#
# One-time setup (prompts for an app-specific password from appleid.apple.com). The profile keeps
# its original clawd-notary name, so credentials saved before the rename still work:
#   xcrun notarytool store-credentials clawd-notary --apple-id <your Apple ID> --team-id 2RGYH2QYUY
set -euo pipefail

cd "$(dirname "$0")/.."
IDENTITY="${APP_IDENTITY:-Developer ID Application: Kevin Ridgway (2RGYH2QYUY)}"
PROFILE="${NOTARY_PROFILE:-clawd-notary}"
VERSION="$(tr -d '[:space:]' < VERSION)"
APP="dist/Deskling.app"
DMG="dist/Deskling.dmg"

# SKIP_NOTARIZE=1 stops after signing and packaging: a way to test everything that does not involve Apple.
if [[ -z "${SKIP_NOTARIZE:-}" ]] && ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
    echo "Notary credentials not found in keychain profile '$PROFILE'. Run once:" >&2
    echo "  xcrun notarytool store-credentials $PROFILE --apple-id <your Apple ID> --team-id 2RGYH2QYUY" >&2
    exit 1
fi

make check

echo "==> Building universal release"
swift build -c release --product Deskling --arch arm64 --arch x86_64
swift build -c release --product deskling-hook --arch arm64 --arch x86_64
swift build -c release --product deskling-cli --arch arm64 --arch x86_64
scripts/assemble.sh "$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
for binary in "$APP/Contents/MacOS/Deskling" "$APP/Contents/Helpers/deskling-hook" "$APP/Contents/Helpers/deskling"; do
    archs="$(lipo -archs "$binary")"
    if [[ "$archs" != *arm64* || "$archs" != *x86_64* ]]; then
        echo "Expected a universal binary at $binary, got: $archs" >&2
        exit 1
    fi
done

echo "==> Signing"
sign() { codesign --force --options runtime --timestamp --sign "$IDENTITY" "$@"; }
find "$APP/Contents/Resources" -maxdepth 1 -name '*.bundle' -print0 | while IFS= read -r -d '' bundle; do
    sign "$bundle"
done
# Nested code is signed before the app that contains it, Sparkle's from the inside out.
sparkle="$APP/Contents/Frameworks/Sparkle.framework"
sign "$sparkle/Versions/B/Autoupdate"
sign "$sparkle/Versions/B/Updater.app"
sign "$sparkle"
sign "$APP/Contents/Helpers/deskling-hook"
sign "$APP/Contents/Helpers/deskling"
sign "$APP"
codesign --verify --strict --deep "$APP"

echo "==> Packaging"
# The window opens on Resources/dmg/background.png (made by scripts/dmg-background.py), with the app
# on the left and the Applications link on the right, under the arrow. Finder saves that layout in
# the volume's .DS_Store, so the image is built writable, arranged by scripting Finder, then compressed.
# The first run asks to let your terminal control Finder.
if [[ -e /Volumes/Deskling ]]; then
    echo "A volume named Deskling is already mounted. Eject it first, so Finder arranges the new one." >&2
    exit 1
fi
staging="$(mktemp -d)"
writable="$staging.rw.dmg"
mount=""
cleanup() {
    if [[ -n "$mount" ]]; then hdiutil detach "$mount" -quiet -force 2>/dev/null || true; fi
    rm -rf "$staging" "$writable"
}
trap cleanup EXIT
cp -R "$APP" "$staging/"
ln -s /Applications "$staging/Applications"
mkdir "$staging/.background"
tiffutil -cathidpicheck Resources/dmg/background.png Resources/dmg/background@2x.png \
    -out "$staging/.background/background.tiff" >/dev/null
rm -f "$DMG"
hdiutil create -volname Deskling -srcfolder "$staging" -fs HFS+ -format UDRW -quiet "$writable"
mount="$(hdiutil attach "$writable" -readwrite -noverify -noautoopen | awk -F'\t' '/\/Volumes\// {print $NF}')"
# Window bounds are {left, top, right, bottom} on screen; 660 x 400 is the background's size in
# points. Positions are icon centres, matching LAYOUT in scripts/dmg-background.py.
osascript <<'APPLESCRIPT'
tell application "Finder"
    tell disk "Deskling"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 860, 520}
        set viewOptions to icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.tiff"
        set position of item "Deskling.app" of container window to {170, 268}
        set position of item "Applications" of container window to {490, 268}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT
# Finder writes .DS_Store when it gets round to it; wait for it rather than ship a plain window.
for _ in {1..20}; do [[ -f "$mount/.DS_Store" ]] && break; sleep 0.5; done
[[ -f "$mount/.DS_Store" ]] || { echo "Finder did not save the window layout to the disk image." >&2; exit 1; }
rm -rf "$mount/.fseventsd"
sync
hdiutil detach "$mount" -quiet
mount=""
hdiutil convert "$writable" -format UDZO -imagekey zlib-level=9 -quiet -o "$DMG"
rm -f "$writable"
sign "$DMG"

if [[ -n "${SKIP_NOTARIZE:-}" ]]; then
    echo "Signed but NOT notarized (SKIP_NOTARIZE): $DMG. Do not distribute this file."
    exit 0
fi

echo "==> Notarizing (this uploads the DMG to Apple and waits)"
submission="$(xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait --output-format json)"
status="$(printf '%s' "$submission" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])')"
if [[ "$status" != "Accepted" ]]; then
    id="$(printf '%s' "$submission" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"
    xcrun notarytool log "$id" --keychain-profile "$PROFILE" >&2 || true
    echo "Notarization failed: $status" >&2
    exit 1
fi
xcrun stapler staple "$DMG"

echo "==> Verifying"
spctl -a -vv "$APP"
spctl -a -t open --context context:primary-signature -v "$DMG"
cp "$DMG" "dist/Deskling-$VERSION.dmg"
echo "Done: $DMG and dist/Deskling-$VERSION.dmg"
