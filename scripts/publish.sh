#!/bin/bash
# Publishes the notarized disk image from `make release` as a GitHub release and bumps the Homebrew cask.
# Release notes come from NOTES=<file>, or are generated from merged pull requests.
# BUBBLE=<file> holds the 1 to 3 short lines the character says about the update (40 characters at most each);
# they go into appcast.xml, the update feed the app reads at releases/latest/download/appcast.xml.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(tr -d '[:space:]' < apps/deskling/VERSION)"
DMG="apps/deskling/dist/Deskling-$VERSION.dmg"
TAP="program247365/homebrew-tap"

[ -f "$DMG" ] || { echo "No $DMG. Run 'make release' first." >&2; exit 1; }
xcrun stapler validate -q "$DMG" || { echo "$DMG is not notarized. Run 'make release'." >&2; exit 1; }
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "Check out the pushed tip of main first." >&2; exit 1; }
if gh release view "v$VERSION" >/dev/null 2>&1; then echo "v$VERSION is already released. Bump apps/deskling/VERSION." >&2; exit 1; fi
[ -f "${BUBBLE:-}" ] || { echo "Pass BUBBLE=<file>: 1 to 3 short lines for the update bubble." >&2; exit 1; }
SIGN_UPDATE="apps/deskling/.build/artifacts/sparkle/Sparkle/bin/sign_update"
[ -x "$SIGN_UPDATE" ] || { echo "No $SIGN_UPDATE. Run make check first." >&2; exit 1; }

# The update feed. Signed with the EdDSA key in the login keychain (a copy is in 1Password; see the release skill).
signature="$("$SIGN_UPDATE" "$DMG")" || { echo "Could not sign $DMG for Sparkle. Is the key in the keychain?" >&2; exit 1; }
feed="$(mktemp -d)/appcast.xml"
/usr/bin/python3 - "$VERSION" "$BUBBLE" "$signature" "$feed" <<'PY'
import email.utils, re, sys
from xml.sax.saxutils import escape
version, bubble_path, signature, out = sys.argv[1:]
lines = [l.strip() for l in open(bubble_path) if l.strip()]
problems = [f"{len(lines)} lines; the bubble takes 1 to 3"] if not 1 <= len(lines) <= 3 else []
problems += [f"too long for the bubble ({len(l)} > 40): {l}" for l in lines if len(l) > 40]
if problems:
    sys.exit("BUBBLE: " + "; ".join(problems))
attrs = dict(re.findall(r'(sparkle:edSignature|length)="([^"]+)"', signature))
if set(attrs) != {"sparkle:edSignature", "length"}:
    sys.exit(f"Unexpected sign_update output: {signature}")
url = f"https://github.com/program247365/deskling/releases/download/v{version}/Deskling-{version}.dmg"
open(out, "w").write(f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Deskling</title>
    <item>
      <title>Deskling {version}</title>
      <pubDate>{email.utils.formatdate()}</pubDate>
      <sparkle:version>{version}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description sparkle:descriptionFormat="plain-text">{escape(chr(10).join(lines))}</description>
      <enclosure url="{url}" type="application/octet-stream" sparkle:edSignature="{attrs['sparkle:edSignature']}" length="{attrs['length']}"/>
    </item>
  </channel>
</rss>
""")
PY

if [ -n "${NOTES:-}" ]; then notes=(--notes-file "$NOTES"); else notes=(--generate-notes); fi
# Also as Clawd.dmg: links to releases/latest/download/Clawd.dmg from before the rename keep working.
legacy="$(mktemp -d)"
cp apps/deskling/dist/Deskling.dmg "$legacy/Clawd.dmg"
gh release create "v$VERSION" "$DMG" apps/deskling/dist/Deskling.dmg "$legacy/Clawd.dmg" "$feed" --target main --title "Deskling $VERSION" "${notes[@]}"
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
