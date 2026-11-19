#!/bin/bash
# Publishes the notarized disk image from `make release` as a GitHub release and bumps the Homebrew cask.
# Release notes come from NOTES=<file>, or are generated from merged pull requests.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(tr -d '[:space:]' < apps/deskling/VERSION)"
DMG="apps/deskling/dist/Deskling-$VERSION.dmg"
TAP="program247365/homebrew-tap"

[ -f "$DMG" ] || { echo "No $DMG. Run 'make release' first." >&2; exit 1; }
xcrun stapler validate -q "$DMG" || { echo "$DMG is not notarized. Run 'make release'." >&2; exit 1; }
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "Check out the pushed tip of main first." >&2; exit 1; }
if gh release view "v$VERSION" >/dev/null 2>&1; then echo "v$VERSION is already released. Bump apps/deskling/VERSION." >&2; exit 1; fi

if [ -n "${NOTES:-}" ]; then notes=(--notes-file "$NOTES"); else notes=(--generate-notes); fi
# Also as Clawd.dmg: links to releases/latest/download/Clawd.dmg from before the rename keep working.
legacy="$(mktemp -d)"
cp apps/deskling/dist/Deskling.dmg "$legacy/Clawd.dmg"
gh release create "v$VERSION" "$DMG" apps/deskling/dist/Deskling.dmg "$legacy/Clawd.dmg" --target main --title "Deskling $VERSION" "${notes[@]}"
rm -rf "$legacy"

sha="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"

# The cask, in one tap commit. The first Deskling release renames it from clawd (see update-cask.sh).
tap_dir="$(mktemp -d)"
trap 'rm -rf "$tap_dir"' EXIT
gh repo clone "$TAP" "$tap_dir" -- --quiet --depth 1
git -C "$tap_dir" config user.name "Kevin B. Ridgway"
git -C "$tap_dir" config user.email k@kbr.sh
if [ "$(scripts/update-cask.sh "$tap_dir" "$VERSION" "$sha")" = renamed ]; then
    message="deskling $VERSION: renamed from clawd"
else
    message="deskling $VERSION"
fi
git -C "$tap_dir" add -A Casks cask_renames.json
git -C "$tap_dir" commit -q -m "$message"
git -C "$tap_dir" push -q
echo "Published v$VERSION ($message)."
