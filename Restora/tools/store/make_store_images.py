#!/usr/bin/env python3
"""Store / marketing images for RESTORA, built from the real simulator
screenshots (docs/store/screenshots) and the logo.

Output: docs/store/marketing/
  hero-1920x1080.png, cover-1440x720.png, feature-1024x500.png,
  square-1080.png, screen-01..07-1080x1080.png (captioned, framed)

The watch frame is a generic round bezel drawn here (no Garmin device art).
Usage: python tools/store/make_store_images.py
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHOTS = os.path.join(ROOT, "docs", "store", "screenshots")
ICON = os.path.join(ROOT, "docs", "store", "icons", "icon-512-transparent.png")
FONT = os.path.join(ROOT, "tools", "fonts", "Oswald-VF.ttf")
OUT = os.path.join(ROOT, "docs", "store", "marketing")

BG_TOP, BG_BOTTOM = (6, 12, 10), (0, 0, 0)
GREEN, WHITE, GREY, SOFT = (79, 201, 122), (242, 243, 239), (138, 145, 140), (201, 206, 201)

SCREENS = [
    ("01-home.png", "Six recovery modules", "Breathe, Mind, Circulate, Mobility, Sleep, Recover"),
    ("02-module.png", "33 guided sessions", "From 3 to 20 minutes"),
    ("03-detail.png", "Know before you start", "Every step, its time and a safety note"),
    ("07-figure.png", "Animated movement guide", "Anatomical figures for 36 exercises"),
    ("09-figure-front.png", "Neck, shoulders, chest", "3/4 view for upper-body work"),
    ("04-breathing.png", "Breathing pacer", "Follow the ring, or build your own pattern"),
    ("05-summary.png", "Clear results", "Measured by Garmin, or calculated by RESTORA"),
    ("06-end-session.png", "Button-first control", "START, UP, DOWN and BACK, no touch needed"),
]


def font(size, weight):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def background(w, h):
    img = Image.new("RGB", (w, h), BG_BOTTOM)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(BG_TOP[i] * (1 - t) + BG_BOTTOM[i] * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=c)
    # soft green glow
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse([w * 0.45, -h * 0.4, w * 1.25, h * 0.9], fill=60)
    glow = glow.filter(ImageFilter.GaussianBlur(max(w, h) // 10))
    tint = Image.new("RGB", (w, h), (20, 70, 45))
    return Image.composite(tint, img, glow)


def watch(shot_name, size):
    """Round watch: dark bezel ring, thin rim highlight, screen inside."""
    s = size
    w = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(w)
    d.ellipse([0, 0, s - 1, s - 1], fill=(26, 28, 30, 255))
    d.ellipse([s * 0.02, s * 0.02, s * 0.98, s * 0.98], outline=(70, 74, 78, 255), width=max(2, s // 160))
    d.ellipse([s * 0.06, s * 0.06, s * 0.94, s * 0.94], fill=(0, 0, 0, 255))
    shot = Image.open(os.path.join(SHOTS, shot_name)).convert("RGB")
    inner = int(s * 0.84)
    shot = shot.resize((inner, inner), Image.LANCZOS)
    mask = Image.new("L", (inner, inner), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, inner - 1, inner - 1], fill=255)
    off = (s - inner) // 2
    w.paste(shot, (off, off), mask)
    # START button nub on the right
    d.rounded_rectangle([s * 0.975, s * 0.30, s * 1.0, s * 0.40], radius=s // 60, fill=(40, 42, 45, 255))
    return w


def shadow(img, blur, opacity=170):
    a = img.split()[-1].point(lambda v: opacity if v > 0 else 0)
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sh.putalpha(a.filter(ImageFilter.GaussianBlur(blur)))
    return sh


def place(canvas, item, x, y, blur=None):
    if blur:
        sh = shadow(item, blur)
        canvas.paste(sh, (x + blur // 3, y + blur // 2), sh)
    canvas.paste(item, (x, y), item)


def brand(canvas, x, y, scale, align="left"):
    d = ImageDraw.Draw(canvas)
    icon = Image.open(ICON).convert("RGBA").resize((int(120 * scale), int(120 * scale)), Image.LANCZOS)
    title = font(int(118 * scale), 600)
    tag = font(int(44 * scale), 400)
    sub = font(int(30 * scale), 400)
    lines = [("RESTORA", title, WHITE, int(140 * scale)), ("Breathe. Move. Restore.", tag, GREEN, int(64 * scale)),
             ("Guided recovery for Forerunner 165", sub, GREY, int(40 * scale))]

    def lx(text, f):
        return int(x - d.textlength(text, font=f) / 2) if align == "center" else x
    canvas.paste(icon, ((x - icon.width // 2) if align == "center" else x, y), icon)
    ty = y + icon.height + int(18 * scale)
    for text, f, col, step in lines:
        d.text((lx(text, f), ty), text, font=f, fill=col)
        ty += step
    return ty


def hero(w, h, name):
    img = background(w, h).convert("RGBA")
    sc = h / 1080
    brand(img, int(140 * sc * (w / h) / (1920 / 1080)), int(250 * sc), sc)
    big = int(520 * sc)
    small = int(360 * sc)
    margin = int(70 * sc)
    cx = w - margin - small - big // 2 + int(80 * sc)     # right watch ends at the margin
    cy = int(h * 0.52)
    place(img, watch("04-breathing.png", small), cx - big // 2 - small + int(80 * sc), cy - small // 2 + int(40 * sc),
          int(30 * sc))
    place(img, watch("05-summary.png", small), cx + big // 2 - int(80 * sc), cy - small // 2 + int(40 * sc), int(30 * sc))
    place(img, watch("07-figure.png", big), cx - big // 2, cy - big // 2, int(40 * sc))
    img.convert("RGB").save(os.path.join(OUT, name))


def feature(w, h, name):
    img = background(w, h).convert("RGBA")
    sc = h / 500
    d = ImageDraw.Draw(img)
    icon = Image.open(ICON).convert("RGBA").resize((int(90 * sc), int(90 * sc)), Image.LANCZOS)
    img.paste(icon, (int(60 * sc), int(70 * sc)), icon)
    d.text((int(60 * sc), int(175 * sc)), "RESTORA", font=font(int(84 * sc), 600), fill=WHITE)
    d.text((int(62 * sc), int(285 * sc)), "Breathe. Move. Restore.", font=font(int(32 * sc), 400), fill=GREEN)
    d.text((int(62 * sc), int(335 * sc)), "Offline recovery coach for your wrist", font=font(int(22 * sc), 400), fill=GREY)
    size = int(380 * sc)
    place(img, watch("07-figure.png", size), w - size - int(70 * sc), (h - size) // 2, int(24 * sc))
    img.convert("RGB").save(os.path.join(OUT, name))


def square(name):
    s = 1080
    img = background(s, s).convert("RGBA")
    brand(img, s // 2, 70, 0.78, align="center")
    size = 560
    place(img, watch("01-home.png", size), (s - size) // 2, 470, 34)
    img.convert("RGB").save(os.path.join(OUT, name))


def framed(i, shot, title, caption):
    s = 1080
    img = background(s, s).convert("RGBA")
    d = ImageDraw.Draw(img)
    t = font(64, 600)
    c = font(32, 400)
    d.text(((s - d.textlength(title, font=t)) / 2, 70), title, font=t, fill=WHITE)
    d.text(((s - d.textlength(caption, font=c)) / 2, 160), caption, font=c, fill=GREY)
    size = 760
    place(img, watch(shot, size), (s - size) // 2, 250, 36)
    img.convert("RGB").save(os.path.join(OUT, "screen-%02d-1080x1080.png" % i))


def main():
    os.makedirs(OUT, exist_ok=True)
    hero(1920, 1080, "hero-1920x1080.png")
    hero(1440, 720, "cover-1440x720.png")
    feature(1024, 500, "feature-1024x500.png")
    square("square-1080.png")
    for i, (shot, title, cap) in enumerate(SCREENS, 1):
        framed(i, shot, title, cap)
    print("images ->", OUT)


if __name__ == "__main__":
    main()
