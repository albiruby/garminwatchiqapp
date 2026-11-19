#!/usr/bin/env python3
"""Generate Connect IQ bitmap fonts (BMFont text .fnt + PNG atlas) from Roboto Mono.

Connect IQ cannot load .ttf files, so each size is pre-rendered. Glyphs are white with
an alpha channel, which Connect IQ uses for anti-aliasing (antialias="true" in fonts.xml).

Usage:  python3 tools/make_fonts.py
Output: resources/fonts/*.fnt + *.png

Roboto Mono is (c) The Roboto Mono Project Authors, SIL Open Font License 1.1
(tools/fonts/OFL.txt).
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "fonts")
OUT = os.path.join(ROOT, "resources", "fonts")

ASCII = "".join(chr(c) for c in range(32, 127))
DIGITS = "0123456789:-/%. "
HERO = "0123456789:"

# id, file stem, weight, pixel size, character set.
# Sizes are tuned for 390 x 390 displays (Forerunner 165 / 165 Music).
FONTS = [
    ("MonoLabel", "mono_label", "Medium", 17, ASCII),   # uppercase labels, hints
    ("MonoBody", "mono_body", "Regular", 21, ASCII),    # list rows, notes
    ("MonoTitle", "mono_title", "Bold", 27, ASCII),     # titles, phase words
    ("MonoNum", "mono_num", "Bold", 44, DIGITS),        # headline numbers
    ("MonoHero", "mono_hero", "Bold", 80, HERO),        # main timer (~62% of diameter)
]

ATLAS_W = 512
PAD = 2


def build(font_id, stem, weight, size, chars):
    font = ImageFont.truetype(os.path.join(SRC, "RobotoMono-%s.ttf" % weight), size)
    ascent, descent = font.getmetrics()
    line_h = ascent + descent

    # Render each glyph on its own canvas and measure the real ink box, so nothing
    # is clipped by font-metric rounding. Origin = top-left of the line box.
    margin = size
    glyphs = []
    for ch in chars:
        canvas = Image.new("L", (size * 3, line_h + 2 * margin), 0)
        ImageDraw.Draw(canvas).text((margin, margin), ch, font=font, fill=255, anchor="la")
        box = canvas.getbbox()
        adv = round(font.getlength(ch))
        if box is None:
            glyphs.append((ch, 0, 0, 0, 0, adv, None))
        else:
            l, t, r, b = box
            glyphs.append((ch, l - margin, t - margin, r - l, b - t, adv, canvas.crop(box)))

    # Shelf packing.
    x = y = 0
    row_h = 0
    places = []
    for g in glyphs:
        w, h = g[3], g[4]
        if x + w + PAD > ATLAS_W:
            x = 0
            y += row_h + PAD
            row_h = 0
        places.append((x, y))
        x += w + PAD
        row_h = max(row_h, h)
    atlas_h = 1
    while atlas_h < y + row_h + PAD:
        atlas_h *= 2

    img = Image.new("RGBA", (ATLAS_W, atlas_h), (255, 255, 255, 0))
    mask = Image.new("L", (ATLAS_W, atlas_h), 0)
    lines = []
    for (ch, xo, yo, w, h, adv, crop), (px, py) in zip(glyphs, places):
        if crop is not None:
            mask.paste(crop, (px, py))
        lines.append(
            "char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15"
            % (ord(ch), px, py, w, h, xo, yo, adv))
    img.putalpha(mask)
    img.save(os.path.join(OUT, stem + ".png"))

    with open(os.path.join(OUT, stem + ".fnt"), "w") as f:
        f.write('info face="Roboto Mono %s" size=%d bold=%d italic=0 charset="" unicode=1 '
                'stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=%d,%d\n'
                % (weight, size, 1 if weight == "Bold" else 0, PAD, PAD))
        f.write("common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0\n"
                % (line_h, ascent, ATLAS_W, atlas_h))
        f.write('page id=0 file="%s.png"\n' % stem)
        f.write("chars count=%d\n" % len(lines))
        f.write("\n".join(lines) + "\n")
    print("%-10s %-7s %3dpx  %3d glyphs  atlas %dx%d" % (font_id, weight, size, len(lines), ATLAS_W, atlas_h))


def main():
    os.makedirs(OUT, exist_ok=True)
    xml = ["<fonts>"]
    for font_id, stem, weight, size, chars in FONTS:
        build(font_id, stem, weight, size, chars)
        filt = chars.replace("&", "&amp;").replace('"', "&quot;").replace("<", "&lt;").replace(">", "&gt;")
        # Full-ASCII fonts need no filter; digit fonts keep only the glyphs they use.
        attr = '' if chars == ASCII else ' filter="%s"' % filt
        xml.append('    <font id="%s" filename="%s.fnt" antialias="true"%s/>' % (font_id, stem, attr))
    xml.append("</fonts>")
    with open(os.path.join(OUT, "fonts.xml"), "w") as f:
        f.write("\n".join(xml) + "\n")


if __name__ == "__main__":
    main()
