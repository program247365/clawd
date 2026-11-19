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
