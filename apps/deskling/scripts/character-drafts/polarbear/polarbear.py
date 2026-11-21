#!/usr/bin/env python3
"""Draft polar bear for Deskling: frames as string art, rendered to PNGs (stdlib only).

    python3 -I apps/deskling/scripts/character-drafts/polarbear/polarbear.py            # PNGs into apps/deskling/scripts/character-drafts/polarbear/out/
    python3 -I apps/deskling/scripts/character-drafts/polarbear/polarbear.py --aseprite # also builds polarbear.aseprite

Every frame is 27 x 18 (the Deskling canvas); the last row is the floor. Grids shorter than 18
rows sit on the floor. Edit the grids below and rerun. One character is one pixel:
"." is transparent, every other character is a PALETTE key.
"""
import json
import os
import shutil
import struct
import subprocess
import sys
import zlib

W, H = 27, 18
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
ASEPRITE = shutil.which("aseprite") or "/Applications/Aseprite.app/Contents/MacOS/aseprite"

PALETTE = {
    "o": "#5b6578",  # outline: slate, dark enough for white desktops, soft on dark ones
    "w": "#f7f5ef",  # fur: warm white
    "s": "#d3d8e0",  # fur shade: cool grey
    "k": "#141413",  # eyes and nose: the same near-black as the other characters (icon holes)
    "r": "#d8434b",  # scarf: Bear-ish red
    "d": "#9e2a33",  # scarf shade
    "p": "#e9b8cc",  # blush: Luna's pink
    "z": "#8fa2c2",  # sleep z's
    "h": "#e2556b",  # heart (pet)
}

# ---------------------------------------------------------------- poses
def parse(art):
    """String art -> 18 rows of 27, sitting on the floor."""
    rows = art.strip("\n").split("\n")
    for r in rows:
        assert len(r) == W, f"row is {len(r)} wide, not {W}: {r!r}"
        for ch in r:
            assert ch == "." or ch in PALETTE, f"unknown pixel {ch!r} in {r!r}"
    assert len(rows) <= H
    return ["." * W] * (H - len(rows)) + rows

def patch(grid, *edits):
    """Small edits: (row, col, text), rows counted in the full 18-row frame; spaces leave pixels alone."""
    rows = [list(r) for r in grid]
    for y, x, text in edits:
        for i, ch in enumerate(text):
            if ch != " ":
                rows[y][x + i] = ch
    return ["".join(r) for r in rows]

def lift(grid, n=1):
    """Moves everything up n rows (the walk bob)."""
    return grid[n:] + ["." * W] * n

# The standing bear, on all fours and facing right (the app mirrors him to walk left): a heavy body with a
# shoulder hump, a long low head with a small ear, and a red scarf around his neck. Rows 4-17 of the frame.
STAND = """
......ooooooo..............
....oowwwwwwwoo......oo....
...owwwwwwwwwwwoooooowso...
..owwwwwwwwwwwwwrrwwwwwwoo.
..owwwwwwwwwwwwwrrwwwkwwwwo
.owwwwwwwwwwwwwwrrwwpwwwwkk
.owwwwwwwwwwwwwwrrwwwssooo.
.owwwwwwwwwwwwwwrdoooo.....
.oswwwwwwwwwwwwwrdwwo......
.osswwwwwwwwwwwwwwwwo......
..osswwwwwwwwwwwwwwso......
..owwwossooossowwwwo.......
..owwwosso..ossowwwwo......
..oooooooo..ooooooooo......
"""
stand = parse(STAND)
EYE = (8, 21)
# The legs, back to front, as (first column, width): near rear, far rear, far front, near front.
# Each near leg overlaps its shaded far leg, so a pair reads as one chunky set of legs.
LEGS = [(2, 5), (7, 3), (12, 3), (15, 6)]

def lift_legs(grid, *which):
    """Lifts the given legs (indexes into LEGS) off the floor: the paw line moves up a row."""
    rows = [list(r) for r in grid]
    for i in which:
        x, n = LEGS[i]
        rows[16][x:x + n] = list("o" * n)
        rows[17][x:x + n] = list("." * n)
    return ["".join(r) for r in rows]

# Walk: 8 frames, like Sol and Octo. Diagonal pairs lift in turn: near rear with far front, then the other two.
step_a, step_b = lift_legs(stand, 0, 2), lift_legs(stand, 1, 3)
walk = [stand, step_a, step_a, stand, stand, step_b, step_b, stand]

# Look-up: the eye one row higher.
look_up = patch(stand, (EYE[0] - 1, EYE[1], "k"), (EYE[0], EYE[1], "w"))

def happy(grid):
    """The eye squeezes shut into a short dash."""
    return patch(grid, (EYE[0], EYE[1] - 1, "kk"))

# Wave: the near front paw comes off the floor and paddles forward, low, then curled up under his chest.
def paw_up(grid, edits):
    rows = [list(r) for r in grid]
    rows[15][15:21] = list("oooooo")
    for y in (16, 17):
        rows[y][15:21] = list("......")
    return patch(["".join(r) for r in rows], *edits)
PAW_FORWARD = [(14, 20, "w"), (15, 15, "owwwwwwo"), (16, 16, "ooooooo")]
PAW_CURLED = [(14, 19, "ww"), (13, 20, "w"), (14, 21, "wo"), (15, 17, "owwso"), (16, 18, "ooo")]
arm_up, arm_out = paw_up(stand, PAW_CURLED), paw_up(stand, PAW_FORWARD)
wave = [arm_up, happy(arm_out), happy(arm_out), happy(arm_up), happy(arm_up),
        happy(arm_out), happy(arm_out), happy(arm_up), happy(arm_up), happy(arm_out), happy(arm_out), arm_up]

# Pet: the eye squeezes shut and a heart floats up over his head.
pet_base = happy(stand)
heart = lambda g, y: patch(g, (y, 22, "h h"), (y + 1, 22, "hhh"), (y + 2, 23, "h"))
pet = [pet_base, pet_base, heart(pet_base, 2), heart(pet_base, 2), heart(pet_base, 1), heart(pet_base, 1),
       heart(pet_base, 0), heart(pet_base, 0), pet_base, pet_base]

# Nap: flat on his belly, legs tucked, chin on the floor, eye shut. The scarf is the red stripe at his neck.
NAP = """
....ooooooooo..............
..oowwwwwwwwwoo.....oo.....
.owwwwwwwwwwwwwrroooowso...
.owwwwwwwwwwwwwrrwwwwwwwoo.
.owwwwwwwwwwwwwrrwwkkwwwwkk
.oswwwwwwwwwwwwrdwwwwwssoo.
..ossssssssssssssooooooo...
"""
# Breathing in: his back rises a pixel.
NAP_BREATH = """
.....ooooooo...............
...oowwwwwwwoo.............
..owwwwwwwwwwwoo....oo.....
.owwwwwwwwwwwwwrroooowso...
.owwwwwwwwwwwwwrrwwwwwwwoo.
.owwwwwwwwwwwwwrrwwkkwwwwkk
.oswwwwwwwwwwwwrdwwwwwssoo.
..ossssssssssssssooooooo...
"""
nap_down, nap_up = parse(NAP), parse(NAP_BREATH)
z_small = lambda g, y, x: patch(g, (y, x, "zz"), (y + 1, x, "zz"))
z_big = lambda g, y, x: patch(g, (y, x, "zzz"), (y + 1, x + 1, "z"), (y + 2, x, "zzz"))
# 12fps, one frame per tick, so a hold is a repeated frame: a slow ~2s breath with z's drifting up.
nap = ([nap_down] * 6 + [nap_up] * 6
       + [z_small(nap_down, 8, 22)] * 6 + [z_big(z_small(nap_up, 7, 23), 3, 24)] * 6)

# Wake: the eye opens and blinks, then up on his feet with a paw in the air.
nap_awake = patch(nap_down, (15, 19, "wk"))
stretch = happy(arm_up)
wake = [nap_awake] * 4 + [nap_down] * 2 + [nap_awake] * 4 + [stretch] * 8 + [stand] * 2

ANIMATIONS = {  # tag name -> frames, in the order the .aseprite gets them
    "walk": walk,
    "stand": [stand],
    "wave": wave,
    "look-up": [look_up],
    "pet": pet,
    "nap": nap,
    "wake": wake,
}

# ---------------------------------------------------------------- rendering
def rgb(hexcolor):
    return tuple(int(hexcolor[i:i + 2], 16) for i in (1, 3, 5))

COLORS = {k: rgb(v) for k, v in PALETTE.items()}

def write_png(path, width, height, pixels):
    """pixels: list of rows of (r, g, b, a)."""
    raw = b"".join(b"\0" + bytes(c for px in row for c in px) for row in pixels)
    chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))

class Canvas:
    def __init__(self, width, height, bg=(0, 0, 0, 0)):
        self.w, self.h = width, height
        self.px = [[bg] * width for _ in range(height)]

    def rect(self, x, y, w, h, color):
        for yy in range(max(0, y), min(self.h, y + h)):
            for xx in range(max(0, x), min(self.w, x + w)):
                self.px[yy][xx] = color

    def sprite(self, grid, x, y, scale):
        for gy, row in enumerate(grid):
            for gx, ch in enumerate(row):
                if ch != ".":
                    self.rect(x + gx * scale, y + gy * scale, scale, scale, COLORS[ch] + (255,))

    def text(self, s, x, y, scale, color):
        for ch in s.upper():
            glyph = FONT.get(ch, FONT[" "])
            for gy, row in enumerate(glyph):
                for gx, bit in enumerate(row):
                    if bit == "#":
                        self.rect(x + gx * scale, y + gy * scale, scale, scale, color)
            x += 4 * scale

    def save(self, path):
        write_png(path, self.w, self.h, self.px)

FONT = {  # 3 x 5
    " ": ["...", "...", "...", "...", "..."], "-": ["...", "...", "###", "...", "..."],
    "A": [".#.", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
    "C": [".##", "#..", "#..", "#..", ".##"], "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"], "F": ["###", "#..", "##.", "#..", "#.."],
    "G": [".##", "#..", "#.#", "#.#", ".##"], "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"], "K": ["#.#", "#.#", "##.", "#.#", "#.#"],
    "L": ["#..", "#..", "#..", "#..", "###"], "N": ["#.#", "###", "###", "#.#", "#.#"],
    "O": [".#.", "#.#", "#.#", "#.#", ".#."], "P": ["##.", "#.#", "##.", "#..", "#.."],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"], "S": [".##", "#..", ".#.", "..#", "##."],
    "T": ["###", ".#.", ".#.", ".#.", ".#."], "U": ["#.#", "#.#", "#.#", "#.#", "###"],
    "V": ["#.#", "#.#", "#.#", "#.#", ".#."], "W": ["#.#", "#.#", "###", "###", "#.#"],
    "X": ["...", "#.#", ".#.", "#.#", "..."], "Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
    "Z": ["###", "..#", ".#.", "#..", "###"], "M": ["#.#", "###", "###", "#.#", "#.#"],
    "0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["##.", "..#", ".#.", "#..", "###"], "3": ["##.", "..#", ".#.", "..#", "##."],
    "4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "##.", "..#", "##."],
    "6": [".##", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "##."],
}

LIGHT, DARK = (236, 236, 238, 255), (30, 31, 34, 255)

def runs(frames):
    """Collapses consecutive repeats: [(grid, hold count, first index)]."""
    out = []
    for i, f in enumerate(frames):
        if out and out[-1][0] == f:
            out[-1][1] += 1
        else:
            out.append([f, 1, i])
    return out

def contact_sheet(path, bg, ink, scale=6):
    cell_w, cell_h, pad, label_w = W * scale, H * scale, 10, 150
    rows = [(name, runs(frames)) for name, frames in ANIMATIONS.items()]
    cols = max(len(r) for _, r in rows)
    c = Canvas(label_w + cols * (cell_w + pad) + pad, len(rows) * (cell_h + 30) + pad, bg)
    floor = tuple(max(0, min(255, v + (-24 if bg == LIGHT else 24))) for v in bg[:3]) + (255,)
    for ri, (name, items) in enumerate(rows):
        y = pad + ri * (cell_h + 30)
        c.text(name, pad, y + cell_h // 2 - 6, 3, ink)
        for ci, (grid, hold, first) in enumerate(items):
            x = label_w + ci * (cell_w + pad)
            c.rect(x, y + cell_h, cell_w, 2, floor)
            c.sprite(grid, x, y, scale)
            c.text(str(first) + (f"x{hold}" if hold > 1 else ""), x, y + cell_h + 6, 2, ink)
    c.save(path)

def actual_size(path, scale):
    """Every distinct frame at the given scale, on light over dark, like a desktop."""
    distinct = [g for frames in ANIMATIONS.values() for g, _, _ in runs(frames)]
    gap = 4 * scale
    w = len(distinct) * (W * scale + gap) + gap
    c = Canvas(w, 2 * (H * scale + 2 * gap), LIGHT)
    c.rect(0, H * scale + 2 * gap, w, H * scale + 2 * gap, DARK)
    for band in range(2):
        y = gap + band * (H * scale + 2 * gap)
        for i, g in enumerate(distinct):
            c.sprite(g, gap + i * (W * scale + gap), y, scale)
    c.save(path)

def main():
    frames_dir = os.path.join(OUT, "frames")
    onex_dir = os.path.join(OUT, "1x")
    for d in (frames_dir, onex_dir):
        os.makedirs(d, exist_ok=True)
        for f in os.listdir(d):
            if f.endswith(".png"):
                os.remove(os.path.join(d, f))
    manifest = {"tags": [], "frames": []}
    for name, frames in ANIMATIONS.items():
        start = len(manifest["frames"])
        for i, grid in enumerate(frames):
            big = Canvas(W * 12, H * 12)
            big.sprite(grid, 0, 0, 12)
            big.save(os.path.join(frames_dir, f"{name}-{i:02d}.png"))
            one = Canvas(W, H)
            one.sprite(grid, 0, 0, 1)
            p = os.path.join(onex_dir, f"{len(manifest['frames']):03d}.png")
            one.save(p)
            manifest["frames"].append(p)
        manifest["tags"].append({"name": name, "from": start, "to": len(manifest["frames"]) - 1})
    contact_sheet(os.path.join(OUT, "contact-sheet-light.png"), LIGHT, (40, 40, 44, 255))
    contact_sheet(os.path.join(OUT, "contact-sheet-dark.png"), DARK, (220, 220, 225, 255))
    actual_size(os.path.join(OUT, "actual-size-1x.png"), 1)
    actual_size(os.path.join(OUT, "actual-size-4x.png"), 4)
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=1)
    print(f"{len(manifest['frames'])} frames in {len(manifest['tags'])} tags -> {OUT}")

    if "--aseprite" in sys.argv:
        target = os.path.join(HERE, "polarbear.aseprite")
        subprocess.run([ASEPRITE, "-b", "--script-param", f"manifest={os.path.join(OUT, 'manifest.json')}",
                        "--script-param", f"out={target}", "--script", os.path.join(HERE, "build-aseprite.lua")],
                       check=True)

if __name__ == "__main__":
    main()
