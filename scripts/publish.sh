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

# The Homebrew cask is still named clawd and downloads Clawd.dmg. Publishing Deskling.dmg before the
# cask is renamed would leave `brew install` pointing at a file that no longer exists.
if [ -z "${CASK_RENAMED:-}" ]; then
    echo "The cask still points at Clawd.dmg. Rename it to deskling in $TAP first, then rerun with CASK_RENAMED=1." >&2
    exit 1
fi

if [ -n "${NOTES:-}" ]; then notes=(--notes-file "$NOTES"); else notes=(--generate-notes); fi
gh release create "v$VERSION" "$DMG" apps/deskling/dist/Deskling.dmg --target main --title "Deskling $VERSION" "${notes[@]}"

sha="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
blob="$(gh api "repos/$TAP/contents/Casks/clawd.rb" -q .sha)"
cask="$(gh api "repos/$TAP/contents/Casks/clawd.rb" -q .content | base64 -d \
    | sed -e "s/version \"[^\"]*\"/version \"$VERSION\"/" -e "s/sha256 \"[0-9a-f]*\"/sha256 \"$sha\"/" | base64 | tr -d '\n')"
gh api -X PUT "repos/$TAP/contents/Casks/clawd.rb" -f message="clawd $VERSION" -f sha="$blob" -f content="$cask" -q .commit.html_url
echo "Published v$VERSION."
