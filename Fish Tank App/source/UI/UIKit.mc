import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Screen stack helpers. Every pixel screen is pushed through Nav so "back to the tank"
// can pop exactly the screens that are open.
module Nav {
    var depth = 0;

    function push(screen) {
        var v = new PixelListView(screen);
        pushView(v, new PixelListDelegate(v));
    }

    function pushGrid(screen) {
        var v = new GridView(screen);
        pushView(v, new GridDelegate(v));
    }

    function pushView(v, d) {
        WatchUi.pushView(v, d, WatchUi.SLIDE_LEFT);
        depth += 1;
    }

    function pop() {
        if (depth > 0) { depth -= 1; }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function toTank() {
        while (depth > 0) {
            depth -= 1;
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
    }
}

// Draws any icon used by lists, grids and reward cards.
module IconKit {
    const NONE = -1;
    const GRID = 0;       // arg = icon rows
    const FISH = 1;       // arg = [species, evolved, variant]
    const EGG = 2;        // arg = egg type
    const DECOR = 3;      // arg = decor id
    const SHADOW = 4;     // arg = species (undiscovered silhouette)

    // Draws centred on (cx, cy). `s` = pixel scale. Returns false if a fish sprite is still
    // being generated (the caller should redraw shortly).
    function draw(dc, kind, arg, cx, cy, s) {
        if (kind == GRID) {
            var rows = arg;
            var w = rows[0].length();
            PixelKit.drawGrid(dc, rows, SpriteData.ICON_KEYS, SpriteData.ICON_COLS, cx - w * s / 2, cy - rows.size() * s / 2, s, false);
            return true;
        }
        if (kind == EGG) {
            PixelKit.drawGrid(dc, SpriteData.ICON_EGG, "kwp", SpriteData.EGG_COLS[arg], cx - 4 * s, cy - 4 * s, s, false);
            return true;
        }
        if (kind == DECOR) {
            var id = arg;
            if (ItemDatabase.DECOR_KIND[id] == 1) {
                PlantKit.draw(dc, ItemDatabase.DECOR_ARG[id], cx, cy + 4 * s, 10 * s, s, ItemDatabase.DECOR_COLS[id], id, 0.0);
            } else {
                var g = SpriteData.DECOR[ItemDatabase.DECOR_ARG[id]];
                var b = s;
                if (g[0].length() > 12 || g.size() > 10) { b = s > 1 ? s - 1 : 1; }
                PixelKit.drawGrid(dc, g, SpriteData.DECOR_KEYS[ItemDatabase.DECOR_ARG[id]], SpriteData.DECOR_COLS[ItemDatabase.DECOR_ARG[id]],
                    cx - g[0].length() * b / 2, cy - g.size() * b / 2, b, false);
            }
            return true;
        }
        if (kind == FISH || kind == SHADOW) {
            var sp = kind == FISH ? arg[0] : arg;
            var evo = kind == FISH ? arg[1] : false;
            var spr = SpriteData.peek(sp, evo);
            if (spr == null) { return false; }
            var pal = spr[:pal];
            if (kind == SHADOW) {
                var dark = new [pal.size()];
                for (var i = 0; i < dark.size(); i++) { dark[i] = i == 0 ? 0x0E1830 : 0x23314F; }
                pal = dark;
            } else if ((arg[2] & 123) != 0) {
                var p = SpriteData.palette(sp, evo, arg[2], 0);
                if (p != null) { pal = p; }
            }
            PixelKit.drawSprite(dc, spr, pal, cx, cy, s, false, false);
            return true;
        }
        return true;
    }

    // Builds one missing sprite needed by an icon; true when everything is ready.
    function warm(kind, arg) {
        if (kind == FISH) {
            if (SpriteData.peek(arg[0], arg[1]) == null) { SpriteData.get(arg[0], arg[1]); return false; }
        } else if (kind == SHADOW) {
            if (SpriteData.peek(arg, false) == null) { SpriteData.get(arg, false); return false; }
        }
        return true;
    }
}

// Text and panel helpers in the shared pixel style.
module UIKit {
    const BG_TOP = 0x0A1A3A;
    const BG_BOT = 0x02060F;
    const PANEL = 0x0B1226;
    const PANEL_HI = 0x14244A;
    const BORDER = 0x2A4A7A;
    const ACCENT = 0x7FE7FF;
    const DIM = 0x8EA3C0;
    const GOLD = 0xFFC93C;
    const GOOD = 0x5EE36A;
    const LEFT = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
    const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

    function font(i) {
        return AquariumHUD.font(i);
    }

    // Shortens s with ".." until it fits maxW pixels.
    function fit(dc, s, f, maxW) {
        if (dc.getTextWidthInPixels(s, f) <= maxW) { return s; }
        while (s.length() > 1 && dc.getTextWidthInPixels(s + "..", f) > maxW) {
            s = s.substring(0, s.length() - 1);
        }
        return s + "..";
    }

    function background(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var n = 8;
        var bh = h / n + 1;
        for (var i = 0; i < n; i++) {
            PixelKit.rect(dc, PixelKit.lerpColor(BG_TOP, BG_BOT, i / (n - 1.0)), 0, i * (h / n), w, bh);
        }
    }

    // Centred title pill near the top edge, sized to its text.
    function titlePill(dc, title, col) {
        var f = font(0);
        var w = dc.getTextWidthInPixels(title, f) + 28;
        var top = (dc.getHeight() * 0.075).toNumber();
        var x0 = dc.getWidth() / 2 - w / 2;
        dc.setColor(PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x0, top, w, 26, 10);
        dc.setColor(BORDER, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x0, top, w, 26, 10);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, top + 12, f, title, CENTER);
    }

    function text(dc, x, y, f, s, col, just) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, f, s, just);
    }

    function bar(dc, x, y, w, h, pct, col) {
        PixelKit.rect(dc, 0x1A2238, x, y, w, h);
        var fw = (w * Util.clamp(pct, 0, 100) / 100.0).toNumber();
        if (fw > 0) { PixelKit.rect(dc, col, x, y, fw, h); }
    }
}
