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
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp -R "$APP" "$staging/"
ln -s /Applications "$staging/Applications"
rm -f "$DMG"
hdiutil create -volname Deskling -srcfolder "$staging" -fs HFS+ -format UDZO -quiet "$DMG"
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
