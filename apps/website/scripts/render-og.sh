#!/bin/sh
# Renders scripts/og.html into assets/og.png, the 1200x630 card link previews show.
set -eu
cd "$(dirname "$0")/.."
chrome="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
"$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --allow-file-access-from-files --window-size=1200,630 \
  --screenshot="$PWD/assets/og.png" "file://$PWD/scripts/og.html" 2>/dev/null
echo "wrote assets/og.png"
