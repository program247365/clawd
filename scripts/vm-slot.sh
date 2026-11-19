#!/bin/bash
# One session at a time on the test VM; the rest wait in line.
#   vm-slot.sh status               who has it, for what, and who's waiting
#   vm-slot.sh claim <who> <why>    take it if it's free and you're first in line
#   vm-slot.sh wait <who> <why>     join the line, then block until it's yours
#   vm-slot.sh release <who>        give it back; prints who's next, so you can message them
#   vm-slot.sh leave <who>          step out of the line
# <who> is the name other sessions message you by (ListAgents shows it).
# When you release, send the next session a message: it may be waiting on you.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/.vm/slot"; HOLDER="$DIR/holder"; LINE="$DIR/line"; MUTEX="$DIR/mutex"
mkdir -p "$DIR"; touch "$LINE"

# Every read-modify-write of the slot runs under this lock.
lock() { until mkdir "$MUTEX" 2>/dev/null; do sleep 0.2; done; trap 'rmdir "$MUTEX" 2>/dev/null' EXIT; }
unlock() { rmdir "$MUTEX"; trap - EXIT; }

holder() { [ -f "$HOLDER" ] && cut -f1 "$HOLDER" || true; }
first_in_line() { head -1 "$LINE" | cut -f1; }
drop() { grep -v "^$1	" "$LINE" > "$LINE.tmp" || true; mv "$LINE.tmp" "$LINE"; }
join_line() { grep -q "^$1	" "$LINE" || printf '%s\t%s\t%s\n' "$1" "$2" "$(date +%s)" >> "$LINE"; }
ago() { echo "$(( ($(date +%s) - $1) / 60 )) min ago"; }

try_claim() { # who why
    local current next
    current="$(holder)"; next="$(first_in_line)"
    if [ -n "$current" ] && [ "$current" != "$1" ]; then return 1; fi
    if [ -n "$next" ] && [ "$next" != "$1" ]; then return 1; fi
    [ "$current" = "$1" ] || printf '%s\t%s\t%s\n' "$1" "$2" "$(date +%s)" > "$HOLDER"
    drop "$1"
}

status() {
    if [ -f "$HOLDER" ]; then
        IFS=$'\t' read -r who why since < "$HOLDER"
        echo "in use by $who since $(ago "$since"): $why"
    else
        echo "free"
    fi
    while IFS=$'\t' read -r who why since; do
        echo "  waiting: $who (since $(ago "$since")): $why"
    done < "$LINE"
}

case "${1:-}" in
status) status ;;
claim)
    [ $# -ge 3 ] || { sed -n 3p "$0"; exit 2; }
    lock
    if try_claim "$2" "$3"; then unlock; echo "the VM is yours, $2"
    else unlock; status; exit 1; fi
    ;;
wait)
    [ $# -ge 3 ] || { sed -n 4p "$0"; exit 2; }
    lock; join_line "$2" "$3"; unlock
    until lock && try_claim "$2" "$3"; do unlock; sleep 15; done
    unlock; echo "the VM is yours, $2"
    ;;
release)
    [ $# -ge 2 ] || { sed -n 5p "$0"; exit 2; }
    lock
    current="$(holder)"
    if [ "$current" != "$2" ]; then unlock; echo "$2 doesn't hold the VM; ${current:-nobody} does"; exit 1; fi
    rm -f "$HOLDER"; next="$(first_in_line)"; unlock
    if [ -n "$next" ]; then echo "released; next is $next: message them that the VM is theirs"
    else echo "released; nobody is waiting"; fi
    ;;
leave)
    [ $# -ge 2 ] || { sed -n 6p "$0"; exit 2; }
    lock; drop "$2"; unlock; echo "$2 left the line"
    ;;
*) sed -n 2,9p "$0"; exit 2 ;;
esac
