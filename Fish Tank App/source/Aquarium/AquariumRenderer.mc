import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Low-level pixel-art drawing helpers shared by all styles.
module PixelKit {
    function lerpColor(a, b, t) {
        if (t < 0) { t = 0.0; }
        if (t > 1) { t = 1.0; }
        var ar = (a >> 16) & 0xFF;
        var ag = (a >> 8) & 0xFF;
        var ab = a & 0xFF;
        var br = (b >> 16) & 0xFF;
        var bg = (b >> 8) & 0xFF;
        var bb = b & 0xFF;
        var r = (ar + (br - ar) * t).toNumber();
        var g = (ag + (bg - ag) * t).toNumber();
        var bl = (ab + (bb - ab) * t).toNumber();
        return (r << 16) | (g << 8) | bl;
    }

    // Rotates the hue of an RGB color by `deg` degrees (used for Shiny variants).
    function hueRotate(c, deg) {
        var r = ((c >> 16) & 0xFF) / 255.0;
        var g = ((c >> 8) & 0xFF) / 255.0;
        var b = (c & 0xFF) / 255.0;
        var mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
        var mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
        var d = mx - mn;
        var h = 0.0;
        if (d > 0.0001) {
            if (mx == r) { h = 60.0 * ((g - b) / d); }
            else if (mx == g) { h = 60.0 * ((b - r) / d + 2.0); }
            else { h = 60.0 * ((r - g) / d + 4.0); }
        }
        h = h + deg;
        while (h < 0) { h += 360.0; }
        while (h >= 360.0) { h -= 360.0; }
        var s = mx <= 0 ? 0.0 : d / mx;
        var v = mx;
        var hh = h / 60.0;
        var i = hh.toNumber();
        var f = hh - i;
        var p = v * (1 - s);
        var q = v * (1 - s * f);
        var t = v * (1 - s * (1 - f));
        var rr = v;
        var gg = t;
        var bb = p;
        if (i == 1) { rr = q; gg = v; bb = p; }
        else if (i == 2) { rr = p; gg = v; bb = t; }
        else if (i == 3) { rr = p; gg = q; bb = v; }
        else if (i == 4) { rr = t; gg = p; bb = v; }
        else if (i == 5) { rr = v; gg = p; bb = q; }
        return ((rr * 255).toNumber() << 16) | ((gg * 255).toNumber() << 8) | (bb * 255).toNumber();
    }

    // A 64-color MIP screen shows each channel as 0, 55, AA or FF, so the dark water and
    // wall tones (all channels under 0x2B) would all turn black. They are lifted just enough
    // to land on the darkest blue / green / teal instead, keeping the water readable.
    function water(c) {
        if (!Scale.mip) { return c; }
        var r = (c >> 16) & 0xFF;
        var g = (c >> 8) & 0xFF;
        var b = c & 0xFF;
        var m = r > g ? (r > b ? r : b) : (g > b ? g : b);
        if (m == 0 || m >= 0x30) { return c; }
        return ((r * 0x30 / m) << 16) | ((g * 0x30 / m) << 8) | (b * 0x30 / m);
    }

    function shade(c, f) {
        return lerpColor(c, 0x000000, f);
    }

    function tint(c, f) {
        return lerpColor(c, 0xFFFFFF, f);
    }

    function rect(dc, c, x, y, w, h) {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, h);
    }

    // Character-grid sprite: `keys` maps each char to `cols`; '.' is transparent.
    function drawGrid(dc, rows, keys, cols, x, y, b, flip) {
        for (var r = 0; r < rows.size(); r++) {
            var cs = rows[r].toCharArray();
            var n = cs.size();
            var i = 0;
            while (i < n) {
                var ch = cs[i];
                if (ch == '.') { i++; continue; }
                var j = i + 1;
                while (j < n && cs[j] == ch) { j++; }
                var idx = keys.find(ch.toString());
                if (idx != null) {
                    var px = flip ? (n - j) : i;
                    dc.setColor(cols[idx], Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x + px * b, y + r * b, (j - i) * b, b);
                }
                i = j;
            }
        }
    }

    // Generated fish sprite centred on (cx, cy) at integer scale s.
    function drawSprite(dc, spr, pal, cx, cy, s, flip, wig) {
        // on a scaled screen draw straight to the real Dc (see Scale): fish are the
        // bulk of every frame's blocks
        var k = 1.0;
        var scaled = dc instanceof ScaledDc;
        if (scaled) {
            k = dc.k;
            dc = dc.dc;
        }
        var runs = spr[:runs];
        var tail = spr[:tail];
        var jelly = spr[:jelly];
        var wrow = spr[:wig];
        var W = SpriteData.W;
        var ox = cx - W * s / 2;
        var oy = cy - SpriteData.H * s / 2;
        var last = -1;
        var n = runs.size();
        for (var i = 0; i < n; i += 4) {
            var x = runs[i];
            var y = runs[i + 1];
            var w = runs[i + 2];
            var c = runs[i + 3];
            var dx = 0;
            var dy = 0;
            if (wig) {
                if (jelly) {
                    if (y >= wrow) { dx = (y % 2 == 0) ? 1 : -1; }
                } else if (x < tail) {
                    dy = 1;
                }
            }
            var px = (flip && !jelly) ? (W - x - w) : x;
            if (c != last) {
                dc.setColor(pal[c], Graphics.COLOR_TRANSPARENT);
                last = c;
            }
            var bx = ox + (px + dx) * s;
            var by = oy + (y + dy) * s;
            if (scaled) {
                var x0 = (bx * k + 0.5).toNumber();
                var y0 = (by * k + 0.5).toNumber();
                dc.fillRectangle(x0, y0, ((bx + w * s) * k + 0.5).toNumber() - x0, ((by + s) * k + 0.5).toNumber() - y0);
            } else {
                dc.fillRectangle(bx, by, w * s, s);
            }
        }
    }

    // Banded vertical gradient with checker dither at each seam (16-bit look).
    function gradientPixel(dc, top, bot, x0, y0, x1, y1, b) {
        var bands = 10;
        var bh = (y1 - y0) / bands;
        if (bh < b) { bh = b; }
        bh = bh / b * b;
        var w = x1 - x0;
        for (var i = 0; i < bands; i++) {
            var yy = y0 + i * bh;
            if (yy >= y1) { break; }
            var hh = (i == bands - 1) ? (y1 - yy) : bh;
            rect(dc, water(lerpColor(top, bot, i / (bands - 1.0))), x0, yy, w, hh);
        }
        for (var i = 1; i < bands; i++) {
            var yy = y0 + i * bh;
            if (yy >= y1) { break; }
            dc.setColor(water(lerpColor(top, bot, (i - 1) / (bands - 1.0))), Graphics.COLOR_TRANSPARENT);
            for (var x = x0; x < x1; x += 2 * b) { dc.fillRectangle(x, yy, b, b); }
            for (var x = x0 + b; x < x1; x += 4 * b) { dc.fillRectangle(x, yy + b, b, b); }
        }
    }

    // Smooth gradient in 2px rows (Minimalist).
    function gradientSmooth(dc, top, bot, y0, y1, w) {
        var n = (y1 - y0) / 2;
        for (var i = 0; i < n; i++) {
            rect(dc, water(lerpColor(top, bot, i / (n - 1.0))), 0, y0 + i * 2, w, 2);
        }
    }

    // Diagonal dithered light shafts from the surface.
    function lightRays(dc, top, bot, depth, b) {
        var xs = [40, 150, 255];
        for (var k = 0; k < xs.size(); k++) {
            for (var y = 0; y < depth; y += b) {
                var fade = 1.0 - y / (depth * 1.0);
                var c = tint(lerpColor(top, bot, y / 300.0), 0.12 * fade);
                dc.setColor(c, Graphics.COLOR_TRANSPARENT);
                var x0 = xs[k] + (y * 0.45).toNumber() / b * b;
                var row = y / b;
                for (var bx = 0; bx < 6; bx++) {
                    if ((bx + row) % 2 == 0) { dc.fillRectangle(x0 + bx * b, y, b, b); }
                }
            }
        }
    }
}

// Base renderer: one implementation per art style. Scene drawing goes into a cached
// bitmap; fish, food, bubbles and foreground are drawn every frame.
class AquariumRenderer {
    var floorY = 300;
    var layered = false;     // Pseudo-3D draws back-layer fish first
    var speedMul = 1.0;
    var airX = 330;

    function initialize() {
    }

    // The static scene is built in stages, one per frame, so no single update trips the
    // Connect IQ watchdog. Subclasses split their scenery into stageCount() pieces.
    function stageCount(eng) {
        return 1;
    }

    function drawStage(dc, eng, i) {
    }

    function drawFish(dc, f, eng) {
    }

    function drawFront(dc, eng) {
    }

    function drawFood(dc, p) {
        var x = p[0].toNumber();
        var y = p[1].toNumber();
        var c = ItemDatabase.FOOD_COLOR[p[2]];
        PixelKit.rect(dc, c, x - 2, y - 2, 4, 4);
        PixelKit.rect(dc, PixelKit.shade(c, 0.4), x, y, 2, 2);
    }

    function drawBubble(dc, b) {
        var x = b[0].toNumber();
        var y = b[1].toNumber();
        dc.setColor(0x9FE3FF, Graphics.COLOR_TRANSPARENT);
        if (b[2] >= 2) {
            dc.fillRectangle(x - 2, y - 4, 4, 2);
            dc.fillRectangle(x - 2, y + 2, 4, 2);
            dc.fillRectangle(x - 4, y - 2, 2, 4);
            dc.fillRectangle(x + 2, y - 2, 2, 4);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - 2, y - 2, 2, 2);
        } else {
            dc.fillRectangle(x - 1, y - 3, 2, 2);
            dc.fillRectangle(x - 1, y + 1, 2, 2);
            dc.fillRectangle(x - 3, y - 1, 2, 2);
            dc.fillRectangle(x + 1, y - 1, 2, 2);
        }
    }

    // Swim area; a bigger aquarium level gives a little more room.
    function bounds(f, eng) {
        var r = HabitatSystem.room(eng);
        return [70 - r, 92 - r, 320 + r, floorY - 16];
    }

    function restY() {
        return floorY + 4;
    }

    function fishScale(f) {
        var s = f.stage() == 0 ? 2 : 3;
        if (f.giant() && f.stage() == 2) { s += 1; }
        return s;
    }

    function hitHalf(f) {
        var s = fishScale(f);
        return [SpriteData.W * s * 0.4, SpriteData.H * s * 0.45];
    }

    // Shared sprite fish: bob, tail wiggle, variant colors, pale palette when unwell.
    // `effect` 0 normal, 2+theme = dimmed back layer (Pseudo-3D).
    function drawSpriteFish(dc, f, s, effect) {
        var spr = SpriteData.peek(f.sp, f.evo);
        if (spr == null) { return; }   // still being generated by the tick
        if (effect == 0 && f.hp < 50) { effect = 1; }
        var pal = spr[:pal];
        if (effect != 0 || (f.variant & 123) != 0) {
            var p = SpriteData.palette(f.sp, f.evo, f.variant, effect);
            if (p != null) { pal = p; }
        }
        var jelly = spr[:jelly];
        var bob = Math.sin(f.phase * (jelly ? 1.5 : 2.2)) * (jelly ? 6 : 2);
        var wig = ((f.phase * 5).toNumber() % 2) == 1;
        PixelKit.drawSprite(dc, spr, pal, f.x.toNumber(), (f.y + bob).toNumber(), s, f.face < 0, wig);
    }

    // Algae specks on the glass that grow as cleanliness drops (baked into the scene cache).
    function drawDirt(dc, eng, b) {
        if (eng.clean >= 80) { return; }
        var n = ((80 - eng.clean) * 1.6).toNumber();
        var rng = new Rng(99);
        for (var i = 0; i < n; i++) {
            var x = (25 + rng.next(340)) / b * b;
            var y = (50 + rng.next(floorY - 40)) / b * b;
            var c = (i % 3 == 0) ? 0x6E9B45 : 0x3F6B2A;
            PixelKit.rect(dc, c, x, y, b * (1 + rng.next(2)), b);
        }
        if (eng.clean < 40) {
            dc.setColor(0x2F4A22, Graphics.COLOR_TRANSPARENT);
            for (var y = 60; y < floorY; y += 4 * b) {
                for (var x = ((y / b) % 2) * 2 * b; x < 390; x += 4 * b) {
                    dc.fillRectangle(x, y, b, b);
                }
            }
        }
    }

    // [[slot, decorId], ...] for every filled slot the aquarium level allows.
    function decorList(eng) {
        var out = [];
        var n = HabitatSystem.slotCount(eng);
        for (var i = 0; i < n; i++) {
            if (eng.placed[i] >= 0) { out.add([i, eng.placed[i]]); }
        }
        return out;
    }

    function decorCount(eng) {
        return decorList(eng).size();
    }

    // Pixel decoration with its base centred at x on bottomY.
    function drawDecorAt(dc, id, x, bottomY, b) {
        var arg = ItemDatabase.DECOR_ARG[id];
        if (ItemDatabase.DECOR_KIND[id] == 1) {
            PlantKit.draw(dc, arg, x, bottomY, 54, b, ItemDatabase.DECOR_COLS[id], id, 0.0);
            return;
        }
        var g = SpriteData.DECOR[arg];
        var gw = g[0].length();
        var gh = g.size();
        PixelKit.drawGrid(dc, g, SpriteData.DECOR_KEYS[arg], SpriteData.DECOR_COLS[arg],
            x - gw * b / 2, bottomY - gh * b, b, false);
    }

    function drawDecorItem(dc, eng, i, b, bottomY) {
        var e = decorList(eng)[i];
        drawDecorAt(dc, e[1], ItemDatabase.SLOT_X[e[0]], bottomY, b);
    }

    // Base line of decoration slot `slot` (Build mode markers).
    function slotBottom(eng, slot) {
        return floorY + 16;
    }
}
