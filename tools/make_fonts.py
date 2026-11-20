#!/usr/bin/env python3
"""Generate Connect IQ bitmap fonts (BMFont text .fnt + PNG atlas) from Oswald.

Connect IQ cannot load .ttf files, so each size is pre-rendered. Glyphs are white with
an alpha channel, which Connect IQ uses for anti-aliasing (antialias="true" in fonts.xml).

Usage:  python3 tools/make_fonts.py
Output: resources/fonts/*.fnt + *.png

Oswald (variable, wght 200-700) is (c) The Oswald Project Authors,
SIL Open Font License 1.1 (tools/fonts/OFL-Oswald.txt).
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "fonts")
OUT = os.path.join(ROOT, "resources", "fonts")

TEXT = "".join(chr(c) for c in range(32, 127)) + "\u00b7\u2191\u2193\u2026"  # ASCII + middot, arrows, ellipsis
DIGITS = "0123456789:-/%. "
HERO = "0123456789:"
FACE = "Oswald-VF.ttf"
FACE_NAME = "Oswald"
WEIGHTS = {"Regular": 400, "Medium": 500, "SemiBold": 600, "Bold": 700}

# id, file stem, weight, pixel size, character set.
# Sizes are tuned for 390 x 390 displays (Forerunner 165 / 165 Music).
# Oswald digits are proportional; build() gives 0-9 one common advance (glyph
# centred in the cell) so timers do not jitter. Oswald runs taller than Roboto
# Condensed at the same pixel size, hence the slightly smaller sizes.
FONTS = [
    ("Label", "rc_label", "Medium", 14, TEXT),    # small uppercase labels
    ("Small", "rc_small", "Regular", 16, TEXT),   # subtitles, cues, table rows
    ("Body", "rc_body", "Medium", 18, TEXT),      # list names, clock
    ("Title", "rc_title", "SemiBold", 22, TEXT),  # titles, phase word, values
    ("Num", "rc_num", "SemiBold", 36, DIGITS),    # headline numbers
    ("Hero", "rc_hero", "SemiBold", 54, HERO),    # main timer inside the ring
]

ATLAS_W = 512
PAD = 2


def build(font_id, stem, weight, size, chars):
    font = ImageFont.truetype(os.path.join(SRC, FACE), size)
    font.set_variation_by_axes([WEIGHTS[weight]])
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

    # Tabular digits: same advance for 0-9, glyph centred in the cell.
    dig = [g for g in glyphs if g[0].isdigit()]
    if dig:
        cell = max(g[5] for g in dig)
        glyphs = [(g[0], g[1] + (cell - g[5]) // 2, g[2], g[3], g[4], cell, g[6]) if g[0].isdigit() else g
                  for g in glyphs]

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
        f.write('info face="%s %s" size=%d bold=%d italic=0 charset="" unicode=1 '
                'stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=%d,%d\n'
                % (FACE_NAME, weight, size, 1 if weight == "Bold" else 0, PAD, PAD))
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
        attr = '' if chars == TEXT else ' filter="%s"' % filt
        xml.append('    <font id="%s" filename="%s.fnt" antialias="true"%s/>' % (font_id, stem, attr))
    xml.append("</fonts>")
    with open(os.path.join(OUT, "fonts.xml"), "w") as f:
        f.write("\n".join(xml) + "\n")


if __name__ == "__main__":
    main()
