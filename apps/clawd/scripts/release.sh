#!/bin/bash
# Builds, signs, notarizes, and staples dist/Clawd.dmg. Uploads nothing. Safe to rerun.
#
# One-time setup (prompts for an app-specific password from appleid.apple.com):
#   xcrun notarytool store-credentials clawd-notary --apple-id <your Apple ID> --team-id 2RGYH2QYUY
set -euo pipefail

cd "$(dirname "$0")/.."
IDENTITY="${APP_IDENTITY:-Developer ID Application: Kevin Ridgway (2RGYH2QYUY)}"
PROFILE="${NOTARY_PROFILE:-clawd-notary}"
VERSION="$(tr -d '[:space:]' < VERSION)"
APP="dist/Clawd.app"
DMG="dist/Clawd.dmg"

if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
    echo "Notary credentials not found in keychain profile '$PROFILE'. Run once:" >&2
    echo "  xcrun notarytool store-credentials $PROFILE --apple-id <your Apple ID> --team-id 2RGYH2QYUY" >&2
    exit 1
fi

make check

echo "==> Building universal release"
swift build -c release --product Clawd --arch arm64 --arch x86_64
scripts/assemble.sh "$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
archs="$(lipo -archs "$APP/Contents/MacOS/Clawd")"
if [[ "$archs" != *arm64* || "$archs" != *x86_64* ]]; then
    echo "Expected a universal binary, got: $archs" >&2
    exit 1
fi

echo "==> Signing"
sign() { codesign --force --options runtime --timestamp --sign "$IDENTITY" "$@"; }
find "$APP/Contents/Resources" -maxdepth 1 -name '*.bundle' -print0 | while IFS= read -r -d '' bundle; do
    sign "$bundle"
done
sign "$APP"
codesign --verify --strict --deep "$APP"

echo "==> Packaging"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp -R "$APP" "$staging/"
ln -s /Applications "$staging/Applications"
rm -f "$DMG"
hdiutil create -volname Clawd -srcfolder "$staging" -fs HFS+ -format UDZO -quiet "$DMG"
sign "$DMG"

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
cp "$DMG" "dist/Clawd-$VERSION.dmg"
echo "Done: $DMG and dist/Clawd-$VERSION.dmg"
