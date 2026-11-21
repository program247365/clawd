# Polar bear (archived draft)

The script that first drew Floe, kept for reference. Floe now lives in `apps/deskling/characters/polarbear/`, and its `.aseprite` file there is the source of truth: edit that by hand, not this script. Nothing here writes into `characters/`, and its outputs (`out/`, `polarbear.aseprite`) are git-ignored.

## Regenerate

```sh
python3 -I apps/deskling/scripts/character-drafts/polarbear/polarbear.py              # PNGs into out/
python3 -I apps/deskling/scripts/character-drafts/polarbear/polarbear.py --aseprite   # also rebuilds polarbear.aseprite
```

Stdlib Python only. The frames are string art in `polarbear.py`: one character is one pixel, `.` is transparent, and the other letters are keys into `PALETTE`. `STAND` is the base pose (on all fours, facing right); walk, look-up, pet and wave are small edits on top of it, so a change to the head carries through to all of them. `NAP` and `NAP_BREATH` are the lying poses. Holds are repeated frames, because the exporter plays one Aseprite frame per 12fps tick.

Outputs in `out/`:

- `contact-sheet-light.png` and `contact-sheet-dark.png`: every animation, with repeated frames collapsed (`12x6` means frame 12, held for 6 ticks)
- `actual-size-1x.png` and `actual-size-4x.png`: each distinct frame on light and dark. At the Small setting (120pt wide), one sprite pixel is about 4pt on screen
- `frames/<tag>-NN.png`: each frame at 12x
- `1x/` and `manifest.json`: inputs for `build-aseprite.lua`

## Tags

| Tag | Frames | Notes |
| --- | --- | --- |
| `walk` | 8 | Same length as Sol and Octo. On all fours; diagonal leg pairs lift in turn |
| `stand` | 1 | |
| `wave` | 12 | The near front paw lifts and paddles, forward then curled. Eye squeezes shut |
| `look-up` | 1 | Eye one row up |
| `pet` | 10 | Eye shut and a heart floats up |
| `nap` | 24 | Flat on his belly, chin on the floor. Slow breathing and z's |
| `wake` | 20 | Eye opens and blinks, then a paw lift, then stand |

## History

Promoted to `characters/polarbear/` as Floe in 357f468: the draft `.aseprite` was copied in, then `make -C apps/deskling export-characters` and `site-characters` were run.
