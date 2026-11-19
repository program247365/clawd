#!/bin/bash
# Plays a short, made-up agent session at a running Deskling, so the reactions can be watched without
# a real agent: thinking, typing, editing, a "needs you" alert, the answer, and a finish.
# Usage: scripts/demo-agents.sh [path to deskling-hook]   (default: the local build in dist/)
set -euo pipefail
cd "$(dirname "$0")/.."
hook="${1:-dist/Deskling.app/Contents/Helpers/deskling-hook}"
[[ -x "$hook" ]] || { echo "No deskling-hook at $hook. Run make app first." >&2; exit 1; }

send() { "$hook" --agent claude --session demo --project demo-project "$@"; }
step() { echo "$1"; shift; send "$@"; sleep "${PAUSE:-6}"; }

# The app plays at most one ambient act every 45 seconds, so the first one shows straight away
# and the rest of this run is about the alert and the finish.
step "prompt: he thinks"             --event promptSubmitted
step "tool: Bash (throttled, likely no act)" --event toolStarted --tool Bash
step "needs you: he comes and waves" --event needsInput
step "still waiting..."              --event needsInput
step "answered: the alert clears"    --event toolFinished --tool Bash
step "finished: he celebrates"       --event finished
echo "done"
