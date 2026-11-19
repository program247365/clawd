# Agent notes for this repo

## Character art belongs to Kevin

`apps/deskling/characters/<id>/<id>.aseprite` is the source of truth for each drawn character, and Kevin edits it by hand in Aseprite.

- Never overwrite, regenerate, or redraw an existing `.aseprite` file: not with a draft script, not with `new-character.lua`, not with `saveAs`. A redraw throws away his hand edits without warning, and Aseprite keeps no history once the file is saved over.
- What you may do with one: read it, export it (`make -C apps/deskling export-characters`), and render the exports to look at (`IconTool --frames`).
- If a change needs new pixels, describe it or draw it into a copy outside `characters/`, then ask Kevin before anything replaces his file.
- `make -C apps/deskling new-character ID=<id>` refuses to overwrite an existing file; keep it that way.
- Commit the exported `animations/` folder and `meta.json` with the `.aseprite` file, so building the app never needs Aseprite.

## Checks

Run `make check` from the repo root before calling a change done.

## The test VM is shared: take a turn

Other Claude sessions, including ones working in other repos, use the clawd-test VM too, so only one session at a time may use it. Before running any `scripts/vm.sh` command or SSHing into the guest, take the slot:

- `scripts/vm-slot.sh status` shows who has the VM and who's waiting.
- `scripts/vm-slot.sh wait <your session name> "<what you're testing>"` joins the line and blocks until the VM is yours. Run it in the background. `claim` takes the VM only if it's free.
- When you're done, `scripts/vm-slot.sh release <your session name>`. It prints who's next: message that session (SendMessage) to say the VM is theirs, and mention anything you left running.
- To ask the current holder for a turn, message them as well as joining the line. Don't reboot, push or stop the VM while someone else holds it.

Your session name is the one `ListAgents` reports for you. The slot only marks whose turn it is and nothing enforces it, so it works only if every session follows these steps.
