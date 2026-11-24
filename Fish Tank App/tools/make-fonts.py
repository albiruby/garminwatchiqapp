# Bakes fonts/src/PixelifySans.ttf into Connect IQ BMFont resources (.fnt + .png),
# rendered without antialiasing so glyph edges stay pixel-sharp like the sprites.
# Usage: python -I tools/make-fonts.py
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "fonts", "src", "PixelifySans.ttf")
OUT = os.path.join(ROOT, "resources", "fonts")
CHARS = "".join(chr(c) for c in range(32, 127))

# id, pixel size, weight (variable axis)
SETS = [("PixS", 20, 500), ("PixM", 26, 500), ("PixL", 34, 600)]


def bake(fid, px, weight):
    font = ImageFont.truetype(SRC, px)
    try:
        font.set_variation_by_axes([weight])
    except Exception:
        pass
    ascent, descent = font.getmetrics()
    line_h = ascent + descent
    glyphs = []
    for ch in CHARS:
        adv = round(font.getlength(ch))
        box = font.getbbox(ch, anchor="la")
        if ch == " " or box[2] <= box[0]:
            glyphs.append((ch, None, 0, 0, 0, 0, adv))
            continue
        w, h = box[2] - box[0], box[3] - box[1]
        img = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(img)
        d.fontmode = "1"
        d.text((-box[0], -box[1]), ch, font=font, fill=255, anchor="la")
        glyphs.append((ch, img, w, h, box[0], box[1], adv))

    atlas_w = sum(g[2] + 1 for g in glyphs) + 1
    atlas = Image.new("RGBA", (atlas_w, line_h), (0, 0, 0, 0))
    lines = []
    x = 0
    for ch, img, w, h, xo, yo, adv in glyphs:
        if img is not None:
            white = Image.new("RGBA", (w, h), (255, 255, 255, 255))
            atlas.paste(white, (x, yo), img.point(lambda v: 255 if v > 127 else 0))
        lines.append(f"char id={ord(ch)} x={x} y={yo if img else 0} width={w} height={h} "
                     f"xoffset={xo} yoffset={yo if img else 0} xadvance={adv} page=0 chnl=15")
        x += w + 1
    name = fid.lower()
    atlas.save(os.path.join(OUT, name + ".png"))
    head = [
        f'info face="Pixelify Sans" size={px} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=1,1',
        f"common lineHeight={line_h} base={ascent} scaleW={atlas_w} scaleH={line_h} pages=1 packed=0",
        f'page id=0 file="{name}.png"',
        f"chars count={len(glyphs)}",
    ]
    with open(os.path.join(OUT, name + ".fnt"), "w", newline="\n") as f:
        f.write("\n".join(head + lines) + "\n")
    print(f"{fid}: {px}px, line height {line_h}")


os.makedirs(OUT, exist_ok=True)
for s in SETS:
    bake(*s)
with open(os.path.join(OUT, "fonts.xml"), "w", newline="\n") as f:
    f.write("<fonts>\n")
    for fid, _, _ in SETS:
        f.write(f'    <font id="{fid}" filename="{fid.lower()}.fnt" antialias="false"/>\n')
    f.write("</fonts>\n")
