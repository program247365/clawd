#!/bin/bash
# Writes the deskling cask for a release into a local copy of the Homebrew tap. Touches nothing else
# and nothing over the network; publish.sh commits and pushes the result.
#
# The first Deskling release also renames the cask from clawd: it removes Casks/clawd.rb and maps
# clawd to deskling in cask_renames.json, so `brew upgrade` moves existing users to the new cask.
# Usage: scripts/update-cask.sh <tap checkout> <version> <sha256 of the versioned DMG>
set -euo pipefail
cd "$(dirname "$0")/.."
tap="$1"; version="$2"; sha="$3"
[[ -d "$tap/Casks" ]] || { echo "$tap has no Casks folder" >&2; exit 1; }
[[ "$sha" =~ ^[0-9a-f]{64}$ ]] || { echo "Not a sha256: $sha" >&2; exit 1; }

sed -e "s/@VERSION@/$version/" -e "s/@SHA256@/$sha/" scripts/deskling.rb.in > "$tap/Casks/deskling.rb"

if [[ -f "$tap/Casks/clawd.rb" ]]; then
    rm "$tap/Casks/clawd.rb"
    # Keeps any renames already in the file and collapses chains that ended at clawd.
    /usr/bin/python3 - "$tap/cask_renames.json" <<'PY'
import json, os, sys
path = sys.argv[1]
renames = json.load(open(path)) if os.path.exists(path) else {}
renames = {old: ("deskling" if new == "clawd" else new) for old, new in renames.items()}
renames["clawd"] = "deskling"
with open(path, "w") as f:
    json.dump(dict(sorted(renames.items())), f, indent=2)
    f.write("\n")
PY
    echo "renamed"
else
    echo "bumped"
fi
