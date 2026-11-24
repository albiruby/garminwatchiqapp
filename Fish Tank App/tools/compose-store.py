# Builds the Connect IQ Store images from the simulator captures in docs/screens:
#   docs/store/master/N-name.png   1600x1000 screen images (source)
#   docs/store/SCREEN_N_name.jpg   1440x900, < 120 KB (portal limit 150 KB)
#   docs/store/HERO_1440x720.jpg   hero banner
#   docs/store/COVER_500x500.jpg   cover, < 250 KB
# Usage (from the project folder): python -I tools/compose-store.py
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(ROOT, "docs", "screens")
OUT = os.path.join(ROOT, "docs", "store")
MASTER = os.path.join(OUT, "master")
FONT = os.path.join(ROOT, "fonts", "src", "PixelifySans.ttf")

TOP, BOT = (12, 32, 72), (2, 6, 18)
CYAN = (127, 231, 255)
GOLD = (255, 201, 60)
LIGHT = (226, 234, 246)
MUTED = (142, 163, 192)


def font(px, weight=500):
    f = ImageFont.truetype(FONT, px)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def canvas(w, h):
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(TOP[i] + (BOT[i] - TOP[i]) * t) for i in range(3)))
    # a few pixel bubbles rising on the sides
    b = max(3, w // 400)
    for (fx, fy, r) in [(0.04, 0.82, 3), (0.06, 0.62, 2), (0.05, 0.42, 4), (0.95, 0.76, 3), (0.93, 0.5, 2), (0.96, 0.3, 3)]:
        cx, cy = int(fx * w), int(fy * h)
        s = r * b
        col = (90, 160, 210)
        d.rectangle([cx - s, cy - s - b, cx + s, cy - s], fill=col)
        d.rectangle([cx - s, cy + s, cx + s, cy + s + b], fill=col)
        d.rectangle([cx - s - b, cy - s, cx - s, cy + s], fill=col)
        d.rectangle([cx + s, cy - s, cx + s + b, cy + s], fill=col)
    return im, d


def shot(name):
    im = Image.open(os.path.join(SHOTS, name + ".png")).convert("RGBA")
    return im.crop(im.getbbox())


def paste_h(im, src, cx, top, h):
    w = int(src.width * h / src.height)
    r = src.resize((w, h), Image.LANCZOS)
    im.paste(r, (int(cx - w / 2), int(top)), r)


def text_c(d, s, f, col, cx, y):
    w = d.textlength(s, font=f)
    d.text((cx - w / 2, y), s, font=f, fill=col)


def save_jpg(im, path, max_bytes):
    for q in range(94, 40, -2):
        im.save(path, "JPEG", quality=q, optimize=True, progressive=True)
        if os.path.getsize(path) <= max_bytes:
            print("saved %-36s %dx%d  %7d bytes  q%d" % (os.path.basename(path), im.width, im.height, os.path.getsize(path), q))
            return
    raise SystemExit("%s still too large" % path)


SCREENS = [
    ("1-pocket-aquarium", "POCKET AQUARIUM", "Your tank, on your wrist",
     "3 art styles x 6 themes - switch any time, progress kept",
     [("tank-modern", "Modern Pixel"), ("tank-minimal", "Minimalist"), ("tank-tropical-depth", "Pseudo-3D")]),
    ("2-run-to-earn", "RUN TO EARN", "Every run feeds your tank",
     "Run with your watch's Run app: 100 m = 1 coin, plus streaks and milestones",
     [("card-run", "Run rewards"), ("screen-activity", "Activity journal"), ("screen-quests", "Daily & weekly quests")]),
    ("3-collect", "COLLECT", "36 fish to discover",
     "Hatch eggs, find rare variants, evolve and breed your fish",
     [("screen-fishdex", "Fishdex"), ("screen-fish-profile", "Fish profile"), ("screen-shop-fish", "Shop")]),
    ("4-build-explore", "BUILD & EXPLORE", "Grow your aquarium",
     "Decorate, expand the tank, unlock ocean regions with your kilometres",
     [("build", "Build mode"), ("screen-expedition", "Ocean expedition"), ("tank-depth-frozen", "Frozen Ocean theme")]),
    ("5-events-games", "EVENTS & GAMES", "Something new every week",
     "Yearly events, weekly currents, a personal league and three mini-games",
     [("screen-events", "Events"), ("card-event", "Event quests"), ("screen-game-race", "Fish Racing")]),
]


def screen_master(key, kicker, title, sub, items):
    W, H = 1600, 1000
    im, d = canvas(W, H)
    text_c(d, kicker, font(24, 500), MUTED, W / 2, 44)
    text_c(d, title, font(64, 600), CYAN, W / 2, 78)
    text_c(d, sub, font(28, 400), LIGHT, W / 2, 162)
    cell, gap, top, h = 470, 30, 226, 620
    x0 = (W - (3 * cell + 2 * gap)) / 2
    for i, (name, cap) in enumerate(items):
        cx = x0 + i * (cell + gap) + cell / 2
        paste_h(im, shot(name), cx, top, h)
        text_c(d, cap, font(30, 600), GOLD, cx, top + h + 16)
    path = os.path.join(MASTER, key + ".png")
    im.save(path)
    return im


def hero():
    W, H = 1440, 720
    im, d = canvas(W, H)
    for name, cx in [("tank-fantasy", 170), ("tank-depth-frozen", 650), ("tank-modern", 410)]:
        paste_h(im, shot(name), cx, 50, 620)
    x = 960
    d.text((x, 190), "PIXEL AQUARIUM FOR RUNNERS", font=font(22, 500), fill=MUTED)
    d.text((x - 4, 222), "FISH TANK", font=font(84, 700), fill=CYAN)
    d.text((x, 330), "Run to feed, collect", font=font(34, 400), fill=LIGHT)
    d.text((x, 372), "and grow your aquarium", font=font(34, 400), fill=LIGHT)
    d.text((x, 446), "36 fish  -  3 art styles  -  6 themes", font=font(22, 600), fill=GOLD)
    d.text((x, 480), "Yearly events  -  quests  -  mini-games", font=font(22, 500), fill=MUTED)
    save_jpg(im, os.path.join(OUT, "HERO_1440x720.jpg"), 1900000)


def cover():
    W, H = 500, 500
    im, d = canvas(W, H)
    paste_h(im, shot("tank-modern"), W / 2, 12, 372)
    text_c(d, "FISH TANK", font(52, 700), CYAN, W / 2, 384)
    text_c(d, "POCKET AQUARIUM  -  RUN TO EARN", font(16, 600), LIGHT, W / 2, 448)
    save_jpg(im, os.path.join(OUT, "COVER_500x500.jpg"), 250000)


os.makedirs(MASTER, exist_ok=True)
for n, s in enumerate(SCREENS, 1):
    m = screen_master(*s)
    save_jpg(m.resize((1440, 900), Image.LANCZOS), os.path.join(OUT, "SCREEN_%d_%s.jpg" % (n, s[0][2:])), 120000)
hero()
cover()
