---
name: vm-testing
description: Use when a change to the Mac app needs testing on a real macOS desktop you can lock, relaunch, and leave running without touching the user's own session - lock screen behaviour, memory over time, launch and entrance, or a different macOS version. Covers starting the Tart VM with a visible window, getting a build into it, running the app, locking the screen, and reading where his window is.
---

# Testing Clawd in a macOS VM

The VM is a [Tart](https://tart.run) macOS guest. Everything goes through one script, `scripts/vm.sh`,
run from the repo root. The common steps are also make tasks: `make vm`, `make vm-push`, `make vm-record`,
`make vm-restart`, `make vm-stop`. What it copies into the guest lives beside it in `scripts/vm/`:

- `scripts/vm/guest/`: the run scripts (`soak-run.sh`, `app-run.sh`). Add new guest scenarios here.
- `scripts/vm/probes/`: `lock.swift` locks the screen; `watch.swift` logs where his window is.
- `scripts/vm/record/`: films the VM window from the host (`vm.sh record`).
- `scripts/vm/soak/`: a harness that plays every act back to back and prints memory per round.

Its own state (ssh key, shared folder) goes in `.vm/`, which is git-ignored.

## Before you start

- Tart must be installed (`~/.local/bin/tart`, or set `TART`) and a base image named `tahoe-base` must
  exist (`tart list`). Guest login is `admin` / `admin`.
- If the VMs are not in Tart's default folder, `TART_HOME` must be exported in every command. Check
  your memory notes for where they live on this machine; ask if you don't know.
- The VM takes 4 CPU cores and 6 GB of memory and has a window on the user's screen. Say so before
  starting it, and stop it when you are done.

## The loop

```sh
V=scripts/vm.sh
$V up                     # clone if needed, boot with a visible window, wait for the desktop
$V push                   # build the app and probes, copy them to ~/s in the guest
$V gui open /Users/admin/s/Clawd.app      # run the app the way a user does
$V gui /Users/admin/s/lock                # lock the guest screen now
$V ssh 'tail -5 ~/s/watch.log'            # read results
$V stop
```

- `vm.sh ssh <cmd>` runs a command in the guest. `vm.sh gui <cmd>` runs it inside the logged-in
  user's desktop session; anything that opens a window or talks to the window server needs `gui`.
- Open the app with `open`, never by running the binary. `Info.plist` settings such as
  `MallocSpaceEfficient` only apply when macOS launches it.
- Settings are plain defaults: `vm.sh gui defaults write sh.kbr.clawd visitsLockScreen -bool true`
  (also `roams`, and `size` = `small` | `medium` | `large`). Set them before `open`.

## What to run

| Question | Run in the guest | Read |
|---|---|---|
| Does memory grow or rest high? Fast. | `vm.sh gui 'sh -c "nohup /Users/admin/s/soak-run.sh >/dev/null 2>&1 &"'` | `~/s/soak-efficient.txt`, `~/s/soak-default.txt`, done when `~/s/soak-done.txt` exists |
| Does the real app hold up, and does he reach the lock screen? | `vm.sh ssh 'echo admin \| sudo -S -p "" sh -c "nohup /Users/admin/s/app-run.sh >/dev/null 2>&1 </dev/null &"'` | `~/s/app.log` (memory every 30 s), `~/s/watch.log` (where his window is) |
| Where is his window right now? | `vm.sh gui 'sh -c "cd /Users/admin/s && ./watch /Users/admin/s 60"'` | `~/s/watch.log` |

Reading `watch.log`: `spaces7=[1]` means his window is on the desktop; `spaces7=[]` means it is in the
lock screen's layer, which is where he is drawn over the lock screen. `locked=` is what macOS reports,
and `EVENT com.apple.screenIsLocked` is the announcement the app reacts to.

Start long runs with `nohup ... &` and poll for a marker file. A command that waits on the guest
will outlive your tool timeout.

## What goes wrong

- **The guest is slow, and slower when you watch it.** On a USB disk, boot takes 6 to 9 minutes, a
  small file copy from the shared folder can take 4, and ssh often times out while the guest is busy
  (`vm.sh` retries). Each ssh call slows whatever is running. Poll rarely.
- **Guest time runs slow once its display sleeps.** A "25 minute" run took well over an hour. Trust
  the guest's own timestamps for durations, not your wall clock.
- **Nothing can unlock the guest from a script.** Typing the password with System Events times out
  on the lock screen. After the first lock the guest stays locked until someone types `admin` in the
  VM window or it reboots. Order scenarios so everything that needs an unlocked desktop comes first.
- **The lock announcement can lag the lock.** On a slow guest `locked=true` appeared 145 seconds
  before `com.apple.screenIsLocked`. He joins on the announcement, so wait for the `EVENT` line
  before judging.
- **Pictures come from the host, not the guest.** `screencapture` in the guest fails ("could not
  create image from display"), and Tart's `--vnc-experimental` crashes Tart (exit 133). Film the VM
  window instead: `vm.sh record 60 out.mov` captures that window alone, whatever covers it. Pull a
  frame with `ffmpeg -ss 5 -i out.mov -frames:v 1 frame.png` and look at it before trusting it.
- **The guest shows its lock screen right after boot,** even with automatic login and the screen
  lock turned off. That is the place to film or test the lock screen visit; a desktop recording
  needs someone to type `admin` in the VM window.
- **Never reboot through `vm.sh ssh`.** It retries when the connection drops and reboots the guest
  a second time. Use `vm.sh restart`, then `vm.sh up` to wait for the desktop.
- **Starting the VM any other way hangs or dies.** A plain background job is killed when the tool
  call returns; a launchd job or `open -a tart.app` hangs on a removable volume. `vm.sh up` uses
  `screen`, then asks the app to come forward, because the window does not appear until it is asked.
- **`tart exec` does not work** with this image; use ssh.
- **A busy host skews memory numbers on the host too.** With the VM running, footprint in host test
  runs swung by 80 MB. Measure the app in the guest, or stop the VM first.

## Reporting

Say what the guest was (macOS version from `vm.sh ssh sw_vers`), what you ran, and the numbers from
the logs. The soak tool is a harness, not the app: it plays every act back to back in a bare window,
so its resting number is lower than the real app's. Don't quote one as the other.
