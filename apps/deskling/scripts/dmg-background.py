#!/usr/bin/env python3
"""Draws the disk image window's background: the app icon and wordmark at the top, and a pixel
arrow from where Finder shows Deskling.app to where it shows the Applications link.

    python3 scripts/dmg-background.py      (from apps/deskling; needs Pillow and fonttools)

Writes Resources/dmg/background.png and background@2x.png, which are committed, so a release never
needs this script. scripts/release.sh places the icons to match the LAYOUT numbers below; change
them in both places together.
"""
import io
import math
import os

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
SITE = os.path.join(APP, "..", "website")
OUT = os.path.join(APP, "Resources", "dmg")

# LAYOUT, in points. Keep in step with scripts/release.sh.
WIDTH, HEIGHT = 660, 400
ICON_Y = 268           # centre of both icons
APP_X, APPS_X = 170, 490
ICON_SIZE = 128

CREAM = (250, 249, 245)
INK = (20, 20, 19)
INK_SOFT = (74, 80, 79)
CLAWD = (217, 119, 87)


def font(size):
    woff = TTFont(os.path.join(SITE, "assets", "fonts", "jersey-15.woff2"))
    woff.flavor = None
    data = io.BytesIO()
    woff.save(data)
    data.seek(0)
    return ImageFont.truetype(data, size)


def arrow(scale):
    """The arrow's mask: a shallow arc that rises out of the app and drops into the folder, with an
    open head like a pen stroke's. It is drawn smooth, then snapped to a grid of 4-point squares, so
    it is stepped like the art."""
    cell, fine = 4, 8  # points per square; fine pixels per point while drawing smooth
    canvas = Image.new("L", (WIDTH * fine, HEIGHT * fine), 0)
    d = ImageDraw.Draw(canvas)
    x0, x1 = APP_X + 84, APPS_X - 88
    y = ICON_Y - 2
    points = []
    for i in range(81):
        t = i / 80
        # A quadratic curve whose control point sits above the middle.
        px = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * (x0 + x1) / 2 + t ** 2 * x1
        py = (1 - t) ** 2 * (y + 8) + 2 * (1 - t) * t * (y - 48) + t ** 2 * y
        points.append((px, py))
    stroke = 11
    strokes = [points]
    tip = points[-1]
    back = math.atan2(tip[1] - points[-8][1], tip[0] - points[-8][0]) + math.pi
    for turn in (-0.7, 0.7):
        strokes.append([tip, (tip[0] + 34 * math.cos(back + turn), tip[1] + 34 * math.sin(back + turn))])
    for line in strokes:
        line = [(px * fine, py * fine) for px, py in line]
        d.line(line, fill=255, width=stroke * fine, joint="curve")
        r = stroke * fine / 2
        for px, py in (line[0], line[-1]):
            d.ellipse([px - r, py - r, px + r, py + r], fill=255)
    grid = canvas.resize((WIDTH // cell, HEIGHT // cell), Image.BOX).point(lambda v: 255 if v >= 110 else 0)
    return grid.resize((WIDTH * scale, HEIGHT * scale), Image.NEAREST)


def draw(scale):
    img = Image.new("RGB", (WIDTH * scale, HEIGHT * scale), CREAM)
    d = ImageDraw.Draw(img)

    # The wordmark: app icon, then the name in the site's pixel font.
    icon_pt = 76
    icon = Image.open(os.path.join(APP, "Resources", "AppIcon.icns"))
    icon.size = (512, 512)
    icon.load()
    icon = icon.convert("RGBA").resize((icon_pt * scale, icon_pt * scale), Image.LANCZOS)
    title = font(92 * scale)
    text = "Deskling"
    box = d.textbbox((0, 0), text, font=title)
    text_w, text_h = box[2] - box[0], box[3] - box[1]
    gap = 18 * scale
    total = icon.width + gap + text_w
    left = (img.width - total) // 2
    top = 44 * scale
    img.paste(icon, (left, top), icon)
    d.text((left + icon.width + gap - box[0], top + (icon.height - text_h) // 2 - box[1]),
           text, font=title, fill=INK)

    tagline = font(26 * scale)
    line = "Drag Deskling into Applications"
    lb = d.textbbox((0, 0), line, font=tagline)
    d.text(((img.width - (lb[2] - lb[0])) // 2 - lb[0], top + icon.height + 16 * scale - lb[1]),
           line, font=tagline, fill=INK_SOFT)

    img.paste(CLAWD, (0, 0), arrow(scale))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    draw(1).save(os.path.join(OUT, "background.png"), optimize=True)
    draw(2).save(os.path.join(OUT, "background@2x.png"), optimize=True)
    print("Wrote", os.path.relpath(OUT))


if __name__ == "__main__":
    main()
