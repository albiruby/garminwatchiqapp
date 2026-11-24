# Draws the 54x54 launcher icon: a pixel clownfish in a navy bubble.
# Usage: python -I tools/make-icon.py resources/drawables/launcher_icon.png
import sys
from PIL import Image, ImageDraw

S = 54
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.ellipse([0, 0, S - 1, S - 1], fill=(10, 30, 70, 255))
d.ellipse([3, 3, S - 4, S - 4], fill=(18, 62, 128, 255))
for i, y in enumerate(range(36, 52, 3)):  # pebble floor
    d.rectangle([8 + i * 2, y, S - 9 - i * 2, y + 2], fill=(90, 74, 138, 255))

K, O, D, W = (26, 14, 8), (255, 122, 26), (217, 82, 11), (255, 255, 255)
fish = [
    "....kkkkk.....",
    "kk.kOOWOOkk...",
    "kOkOOkWkOOOk..",
    "kOOOOkWkOOWEk.",
    "kOOOOkWkOOOOk.",
    "kOkDDkWkDDDk..",
    "kk.kDDWDDkk...",
    "....kkkkk.....",
]
pal = {"k": K, "O": O, "D": D, "W": W, "E": (10, 10, 20)}
px = 3
ox, oy = (S - len(fish[0]) * px) // 2, 12
for y, row in enumerate(fish):
    for x, ch in enumerate(row):
        if ch in pal:
            d.rectangle([ox + x * px, oy + y * px, ox + x * px + px - 1, oy + y * px + px - 1], fill=pal[ch] + (255,))
for bx, by in ((40, 8), (44, 14)):
    d.rectangle([bx, by, bx + 2, by + 2], outline=(160, 230, 255, 255))
img.save(sys.argv[1])
