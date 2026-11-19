#!/bin/sh
# Passes the hook's JSON to the Deskling app's helper. Does nothing if no Deskling with the helper is found.
# DESKLING_APP points it at a particular copy, such as a local build.
try() {
    if [ -n "$1" ] && [ -x "$1/Contents/Helpers/deskling-hook" ]; then
        exec "$1/Contents/Helpers/deskling-hook" --agent claude
    fi
}
try "${DESKLING_APP:-}"
try "/Applications/Deskling.app"
try "$HOME/Applications/Deskling.app"
# Anywhere else: ask Spotlight. The hooks run in the background, so this never slows Claude Code down.
try "$(mdfind 'kMDItemCFBundleIdentifier == "sh.kbr.deskling"' 2>/dev/null | while IFS= read -r app; do
    if [ -x "$app/Contents/Helpers/deskling-hook" ]; then printf '%s' "$app"; break; fi
done)"
cat >/dev/null
exit 0
