#!/bin/bash
# Drives the Tart test VM. Usage: vm.sh up | ssh <cmd> | gui <cmd> | push | record <seconds> <out.mov> | restart | stop
# Needs TART_HOME set if the VMs are not in tart's default place. State (ssh key, shared folder) is in .vm/.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
STATE="$ROOT/.vm"; SHARE="$STATE/share"; KEY="$STATE/key"
VM="${CLAWD_VM:-clawd-test}"; BASE="${CLAWD_VM_BASE:-tahoe-base}"
TART="${TART:-$HOME/.local/bin/tart}"
mkdir -p "$SHARE"

ip() { "$TART" ip "$VM"; }
guest() { ssh -q -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 "admin@$(ip)" "$@"; }
# The guest stalls for minutes at a time on a slow disk, so every call is retried.
retry() { for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do guest "$@" && return 0; sleep 10; done; return 1; }

case "${1:-}" in
up)
    "$TART" list | grep -q " $VM " || { "$TART" clone "$BASE" "$VM"; "$TART" set "$VM" --cpu 4 --memory 6144; }
    if ! "$TART" list | grep " $VM " | grep -q running; then
        # screen keeps it alive after this shell returns; launchd jobs and `open -a` hang on a removable volume.
        screen -dmS clawdvm "$TART" run "$VM" --no-audio --dir="share:$SHARE"
        sleep 20
        # The window only appears once the app is asked to come forward.
        osascript -e 'tell application id "com.github.cirruslabs.tart" to reopen' -e 'tell application id "com.github.cirruslabs.tart" to activate' || true
    fi
    until "$TART" ip "$VM" >/dev/null 2>&1; do sleep 5; done
    if [ ! -f "$KEY" ]; then
        ssh-keygen -q -t ed25519 -N "" -f "$KEY"
        printf '#!/bin/sh\necho admin\n' > "$STATE/askpass"; chmod +x "$STATE/askpass"
        until SSH_ASKPASS="$STATE/askpass" SSH_ASKPASS_REQUIRE=force ssh-copy-id -i "$KEY.pub" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "admin@$(ip)" >/dev/null 2>&1; do sleep 10; done
    fi
    until guest 'who | grep -q console && pgrep -q Finder' 2>/dev/null; do sleep 10; done
    echo "guest desktop is up at $(ip)"
    ;;
ssh) shift; retry "$@" ;;
gui) shift; retry "echo admin | sudo -S -p '' launchctl asuser 501 sudo -u admin $*" ;;
push)
    # Builds the app and the probes on the host and copies them to ~/s in the guest.
    make -C "$ROOT/apps/clawd" app
    rm -rf "$SHARE/Clawd.app"; cp -R "$ROOT/apps/clawd/dist/Clawd.app" "$SHARE/"
    for probe in lock watch; do swiftc -O "$HERE/vm/probes/$probe.swift" -o "$SHARE/$probe"; done
    (cd "$HERE/vm/soak" && swift build -c release && cp "$(swift build -c release --show-bin-path)/soak" "$SHARE/soak")
    cp "$HERE"/vm/guest/*.sh "$SHARE/"
    retry 'pkill -x Clawd; rm -rf ~/s && mkdir ~/s && cp -R "/Volumes/My Shared Files/share/"* ~/s/ && ls ~/s'
    ;;
record)
    # Films the VM window alone, even when other windows cover it. Needs screen recording permission.
    [ -x "$STATE/record" ] || swiftc -O -suppress-warnings -o "$STATE/record" "$HERE/vm/record/main.swift"
    "$STATE/record" "$(pgrep -x tart | head -1)" "$2" "$3"
    ;;
restart) guest 'echo admin | sudo -S -p "" shutdown -r now' || true ;;
stop) guest 'echo admin | sudo -S -p "" shutdown -h now' || "$TART" stop "$VM" ;;
*) sed -n 2,3p "$0"; exit 1 ;;
esac
