# Writes assets/cast-pattern.svg, the desktop's background: a faint tile of the whole cast, each one
# cut from their own standing pose (assets/characters/<id>/stand.png), one square per art pixel, with
# their eyes cut out the way their menubar icons are. Run by `make -C apps/deskling site-characters`.
import json
import os
import struct
import zlib

SITE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHARACTERS = os.path.join(SITE, "assets", "characters")
SOURCE = os.path.join(os.path.dirname(SITE), "deskling", "characters")

# stand.png is 220 x 148 for a 2750 x 1850 canvas: an art pixel (100 units) is 8 px, starting 36 units in.
ART_PX, OFFSET_X, OFFSET_Y, COLUMNS, ROWS = 8, 2.88, 4.0, 27, 18
UNIT = 2                      # pattern units per art pixel, as in the old Clawd-only pattern
TILE = (250, 128)
# Where each one sits in the tile (top-left, in pattern units): three evenly across the top row and two,
# offset, across the bottom, so the repeat has no gaps.
PLACES = {"clawd": (12, 10), "minx": (112, 12), "luna": (212, 10), "octo": (40, 66), "sol": (167, 68)}
NEAR_BLACK = [(0x14, 0x14, 0x13)]


def read_png(path):
    """RGBA rows from an 8-bit RGBA, non-interlaced PNG, which is what sips writes here."""
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    pos, chunks, width = 8, b"", 0
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", body)
            assert depth == 8 and color == 6 and interlace == 0, f"{path}: not 8-bit RGBA"
        elif kind == b"IDAT":
            chunks += body
        pos += 12 + length
    raw = zlib.decompress(chunks)
    stride, rows, previous = width * 4, [], bytearray(width * 4)
    for y in range(height):
        kind, line = raw[y * (stride + 1)], bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            left = line[i - 4] if i >= 4 else 0
            up = previous[i]
            corner = previous[i - 4] if i >= 4 else 0
            if kind == 1: line[i] = (line[i] + left) & 255
            elif kind == 2: line[i] = (line[i] + up) & 255
            elif kind == 3: line[i] = (line[i] + (left + up) // 2) & 255
            elif kind == 4:
                p = left + up - corner
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - corner)
                line[i] = (line[i] + (left if pa <= pb and pa <= pc else up if pb <= pc else corner)) & 255
        rows.append(line)
        previous = line
    return rows


def holes_for(id):
    info_path = os.path.join(SOURCE, id, "character.json")
    if not os.path.exists(info_path):
        return NEAR_BLACK
    hexes = json.load(open(info_path)).get("iconHoles")
    return [tuple(int(h.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) for h in hexes] if hexes else NEAR_BLACK


def silhouette(id):
    """Filled art pixels, cropped to the figure, as a set of (column, row)."""
    rows, holes = read_png(os.path.join(CHARACTERS, id, "stand.png")), holes_for(id)
    cells = set()
    for r in range(ROWS):
        for c in range(COLUMNS):
            x, y = int(OFFSET_X + c * ART_PX + ART_PX / 2), int(OFFSET_Y + r * ART_PX + ART_PX / 2)
            if y >= len(rows) or x * 4 + 3 >= len(rows[y]):
                continue
            red, green, blue, alpha = rows[y][x * 4:x * 4 + 4]
            hole = any(abs(red - h[0]) <= 40 and abs(green - h[1]) <= 40 and abs(blue - h[2]) <= 40 for h in holes)
            if alpha > 127 and not hole:
                cells.add((c, r))
    left, top = min(c for c, _ in cells), min(r for _, r in cells)
    return {(c - left, r - top) for c, r in cells}


def path(cells, at):
    """One subpath per horizontal run of filled pixels."""
    ox, oy, parts = at[0], at[1], []
    for r in sorted({r for _, r in cells}):
        columns = sorted(c for c, row in cells if row == r)
        start = previous = columns[0]
        for c in columns[1:] + [None]:
            if c is not None and c == previous + 1:
                previous = c
                continue
            parts.append(f"M{ox + start * UNIT} {oy + r * UNIT}h{(previous - start + 1) * UNIT}v{UNIT}h-{(previous - start + 1) * UNIT}z")
            if c is not None:
                start = previous = c
    return "".join(parts)


manifest = json.load(open(os.path.join(CHARACTERS, "index.json")))["characters"]
paths = [path(silhouette(entry["id"]), PLACES[entry["id"]]) for entry in manifest if entry["id"] in PLACES]
svg = (f"<svg xmlns='http://www.w3.org/2000/svg' width='{TILE[0]}' height='{TILE[1]}' shape-rendering='crispEdges'>"
       f"<path fill='#ffffff' fill-opacity='.055' d='{''.join(paths)}'/></svg>\n")
open(os.path.join(SITE, "assets", "cast-pattern.svg"), "w").write(svg)
print(f"wrote assets/cast-pattern.svg with {len(paths)} characters")
