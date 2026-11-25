import Toybox.Lang;
import Toybox.Math;

// Fish sprites are generated once per (species, evolved) from FishDatabase parameters into a
// flat run list [x, y, width, paletteIndex, ...] on an 18x12 grid (16-bit style, auto outline).
// Decorations and icons are small hand-drawn character grids.
module SpriteData {
    const W = 18;
    const H = 12;

    // Palette slots: 0 outline, 1 body, 2 shade, 3 highlight, 4 fin, 5 white, 6 eye, 7 accent, 8+ marks
    const P_K = 0;
    const P_B = 1;
    const P_S = 2;
    const P_H = 3;
    const P_F = 4;
    const P_W = 5;
    const P_E = 6;
    const P_A = 7;
    const P_M = 8;

    const VARIANT_NAME = ["Normal", "Shiny", "Golden", "Ghost"];

    var _cache = {};
    var _pal = {};

    function key(sp, evo) {
        return sp * 2 + (evo ? 1 : 0);
    }

    function get(sp, evo) {
        var k = key(sp, evo);
        var s = _cache.get(k);
        if (s == null) {
            s = build(sp, evo);
            _cache.put(k, s);
        }
        return s;
    }

    // Cached sprite or null; drawing code never builds (too slow for a frame).
    function peek(sp, evo) {
        return _cache.get(key(sp, evo));
    }

    // Builds at most one missing sprite per call, from the engine tick, so generation is
    // spread over frames and never trips the watchdog.
    function warm(list) {
        for (var i = 0; i < list.size(); i++) {
            var f = list[i];
            if (_cache.get(key(f.sp, f.evo)) == null) {
                get(f.sp, f.evo);
                return;
            }
        }
    }

    function warmSpecies(sp) {
        if (_cache.get(key(sp, false)) == null) { get(sp, false); return false; }
        return true;
    }

    function clearPalettes() {
        _pal = {};
    }

    // Drops sprites the tank does not show. Browsing the Fishdex or the shop builds up to
    // 72 sprites; keeping them all for the rest of the session wastes memory the watch may
    // not have. Missing ones are rebuilt one per frame when needed again.
    function trim(eng) {
        var keep = {};
        for (var i = 0; i < eng.fish.size(); i++) {
            var k = key(eng.fish[i].sp, eng.fish[i].evo);
            var s = _cache.get(k);
            if (s != null) { keep.put(k, s); }
        }
        if (eng.visitor != null) {
            var kv = key(eng.visitor.sp, false);
            var sv = _cache.get(kv);
            if (sv != null) { keep.put(kv, sv); }
        }
        if (keep.size() < _cache.size()) {
            _cache = keep;
            _pal = {};
        }
    }

    // Palette for a fish: event edition (variant bits 3-6), color variant (bits 0-1), then
    // effect (0 none, 1 unwell, 2+theme dimmed).
    function palette(sp, evo, variant, effect) {
        var k = ((key(sp, evo) * 128 + (variant & 123)) * 8) + effect;
        var p = _pal.get(k);
        if (p != null) { return p; }
        var spr = _cache.get(key(sp, evo));
        if (spr == null) { return null; }
        var base = spr[:pal];
        p = new [base.size()];
        var v = variant & 3;
        var ed = (variant >> 3) & 15;
        for (var i = 0; i < base.size(); i++) {
            var c = base[i];
            if (ed > 0 && i != P_K && i != P_W && i != P_E) {
                var fin = i == P_F || i == P_A;
                c = PixelKit.lerpColor(c, fin ? EventSystem.COL_B[ed - 1] : EventSystem.COL_A[ed - 1], fin ? 0.7 : 0.65);
            }
            if (i != P_K && i != P_W && i != P_E) {
                if (v == 1) { c = PixelKit.hueRotate(c, 150); }
                else if (v == 2) { c = PixelKit.lerpColor(c, 0xFFD84A, 0.5); }
                else if (v == 3) { c = PixelKit.lerpColor(c, 0xE6EEFF, 0.6); }
            }
            if (effect == 1) { c = PixelKit.lerpColor(c, 0x8C96A8, 0.45); }
            else if (effect >= 2) {
                c = PixelKit.lerpColor(c, PixelKit.shade(ThemeDatabase.PAL[effect - 2][1], 0.45), 0.4);
            }
            p[i] = c;
        }
        _pal.put(k, p);
        return p;
    }

    function build(sp, evo) {
        var shape = FishDatabase.SHAPE[sp];
        var tail = FishDatabase.TAIL[sp];
        var cols = FishDatabase.COLORS[sp];
        var marks = FishDatabase.MARKS[sp];
        var jelly = shape == FishDatabase.SH_JELLY;
        var ray = shape == FishDatabase.SH_RAY;
        var eel = shape == FishDatabase.SH_EEL;
        if (evo && !jelly && !ray && !eel) { tail = FishDatabase.T_FLOW; }

        var g = new [W * H];
        for (var i = 0; i < W * H; i++) { g[i] = -1; }

        var cx = 10.5;
        var cy = 6.0;
        var rx = 5.6;
        var ry = 3.3;
        if (shape == FishDatabase.SH_DISC) { rx = 5.0; ry = 4.6; }
        else if (shape == FishDatabase.SH_LONG) { cx = 10.0; rx = 7.2; ry = 2.8; }
        else if (shape == FishDatabase.SH_SMALL) { cx = 11.0; rx = 4.6; ry = 2.6; }
        else if (ray) { cx = 10.0; rx = 7.5; ry = 4.6; }
        else if (jelly) { cx = 9.0; cy = 5.5; rx = 6.5; ry = 4.6; }
        else if (shape == FishDatabase.SH_ROUND) { rx = 4.8; ry = 4.3; }
        else if (eel) { cx = 9.5; rx = 8.6; ry = 1.8; }
        else if (shape == FishDatabase.SH_ANGLER) { cx = 10.0; cy = 6.5; rx = 5.8; ry = 3.8; }

        for (var y = 0; y < H; y++) {
            for (var x = 0; x < W; x++) {
                var px = x + 0.5 - cx;
                var py = y + 0.5 - cy;
                var inside = false;
                if (ray) {
                    inside = px.abs() / rx + py.abs() / ry <= 1.0;
                } else if (jelly) {
                    inside = py <= 0.6 && (px * px) / (rx * rx) + (py * py) / (ry * ry) <= 1.0;
                } else {
                    inside = (px * px) / (rx * rx) + (py * py) / (ry * ry) <= 1.0;
                }
                if (inside) {
                    var c = P_B;
                    if (py < -ry * 0.5) { c = P_H; }
                    else if (!jelly && py > ry * 0.35) { c = P_S; }
                    g[y * W + x] = c;
                }
            }
        }

        var skirt = (cy + 1.0).toNumber();
        if (jelly) {
            for (var x = (cx - rx + 1).toNumber(); x <= (cx + rx - 1).toNumber(); x++) {
                if (x % 2 == 0) { g[skirt * W + x] = P_S; }
            }
        }

        for (var m = 0; m < marks.size(); m++) {
            var mk = marks[m];
            for (var y = mk[1]; y <= mk[3] && y < H; y++) {
                for (var x = mk[0]; x <= mk[2] && x < W; x++) {
                    var v = g[y * W + x];
                    if (v != null && v >= P_B && v <= P_H) {
                        g[y * W + x] = P_M + m;
                    }
                }
            }
        }

        var left = W;
        var right = -1;
        var top = new [W];
        var bot = new [W];
        for (var x = 0; x < W; x++) {
            top[x] = -1;
            bot[x] = -1;
            for (var y = 0; y < H; y++) {
                if (g[y * W + x] >= 0) {
                    if (top[x] < 0) { top[x] = y; }
                    bot[x] = y;
                    if (x < left) { left = x; }
                    if (x > right) { right = x; }
                }
            }
        }

        if (!jelly && !ray && tail != FishDatabase.T_NONE) {
            var maxK = tail == FishDatabase.T_FLOW ? 6 : 4;
            for (var k = 1; k <= maxK; k++) {
                var x = left - k;
                if (x < 0) { break; }
                var half = tail == FishDatabase.T_FLOW ? 1.0 + k * 0.85 : 0.8 + k * 0.7;
                for (var y = 0; y < H; y++) {
                    var dy = (y + 0.5 - cy).abs();
                    if (dy > half) { continue; }
                    if (tail == FishDatabase.T_FORK && k >= 3 && dy < 1.0) { continue; }
                    if (g[y * W + x] < 0) { g[y * W + x] = P_F; }
                }
            }
        }
        if (ray) {
            var ty = cy.toNumber();
            for (var k = 1; k <= 5; k++) {
                if (left - k >= 0) { g[ty * W + left - k] = P_S; }
            }
        }

        if (eel) {
            // ribbon fin along the back and a pointed tail
            for (var x = left + 2; x <= right - 3; x++) {
                if (top[x] > 0) { g[(top[x] - 1) * W + x] = P_F; }
                if (x < left + 8 && bot[x] >= 0 && bot[x] < H - 1) { g[(bot[x] + 1) * W + x] = P_F; }
            }
        } else if (!jelly && !ray) {
            var c0 = (cx - 2).toNumber();
            var c1 = (cx + 1).toNumber();
            var fh = 1;
            if (tail == FishDatabase.T_FLOW) { fh = 3; }
            if (shape == FishDatabase.SH_LION || shape == FishDatabase.SH_ANGLER) { fh = 0; }
            for (var x = c0; x <= c1; x++) {
                if (top[x] < 0) { continue; }
                for (var j = 1; j <= fh; j++) {
                    var y = top[x] - j;
                    if (y >= 0 && g[y * W + x] < 0) { g[y * W + x] = P_F; }
                }
            }
            if (tail == FishDatabase.T_FLOW) {
                for (var x = c0 - 1; x <= c1; x++) {
                    if (bot[x] < 0) { continue; }
                    for (var j = 1; j <= 2; j++) {
                        var y = bot[x] + j;
                        if (y < H && g[y * W + x] < 0) { g[y * W + x] = P_F; }
                    }
                }
            }
            if (shape == FishDatabase.SH_LION) {
                var spikes = [6, 8, 10, 12, 14];
                for (var s = 0; s < spikes.size(); s++) {
                    var x = spikes[s];
                    for (var j = 1; j <= 3; j++) {
                        var y = top[x] - j;
                        if (y >= 0) { g[y * W + x] = P_F; }
                    }
                }
                for (var x = 8; x <= 11; x++) {
                    for (var j = 1; j <= 2; j++) {
                        var y = bot[x] + j;
                        if ((x + j) % 2 == 0 && y < H) { g[y * W + x] = P_F; }
                    }
                }
            }
            if (shape == FishDatabase.SH_ROUND) {
                // puffer spines on the outline ring
                for (var y = 0; y < H; y++) {
                    for (var x = 0; x < W; x++) {
                        if (g[y * W + x] >= 0 || (x * 7 + y * 3) % 4 != 0) { continue; }
                        var n = (x > 0 && g[y * W + x - 1] == P_B) || (x < W - 1 && g[y * W + x + 1] == P_B) ||
                                (y > 0 && g[(y - 1) * W + x] >= P_B && g[(y - 1) * W + x] <= P_S) ||
                                (y < H - 1 && g[(y + 1) * W + x] >= P_B && g[(y + 1) * W + x] <= P_S);
                        if (n && x >= left) { g[y * W + x] = P_F; }
                    }
                }
            }
            if (shape == FishDatabase.SH_ANGLER) {
                // lure stalk + glowing bulb in front of the head, wide dark mouth
                var y0 = top[12] < 0 ? 3 : top[12];
                if (y0 - 1 >= 0) { g[(y0 - 1) * W + 12] = P_K; }
                if (y0 - 2 >= 0) { g[(y0 - 2) * W + 13] = P_K; }
                if (y0 - 2 >= 0 && right + 1 < W) { g[(y0 - 2) * W + 14] = P_K; }
                if (y0 - 1 >= 0 && right + 1 < W) { g[(y0 - 1) * W + 15] = P_A; }
                var my = (cy + 1).toNumber();
                g[my * W + right] = P_K;
                g[my * W + right - 1] = P_K;
            }
        }

        if (jelly) {
            var tx = [4, 7, 10, 13];
            var tl = [4, 5, 5, 4];
            for (var k = 0; k < tx.size(); k++) {
                for (var y = skirt + 1; y <= skirt + tl[k] && y < H - 1; y++) {
                    g[y * W + tx[k]] = P_F;
                }
            }
            g[4 * W + 7] = P_E;
            g[4 * W + 11] = P_E;
        } else {
            var ex = right - 2;
            var ey = (cy - 1.0).toNumber();
            if (ray) { ex = right - 3; }
            if (eel) { ey = cy.toNumber() - 1; ex = right - 1; }
            g[ey * W + ex] = P_W;
            if (ex + 1 < W) { g[ey * W + ex + 1] = P_E; }
        }

        // Auto outline: every empty cell touching a filled one.
        var out = new [W * H];
        for (var i = 0; i < W * H; i++) { out[i] = g[i]; }
        for (var y = 0; y < H; y++) {
            for (var x = 0; x < W; x++) {
                if (g[y * W + x] >= 0) { continue; }
                var n = (x > 0 && g[y * W + x - 1] >= 0) ||
                        (x < W - 1 && g[y * W + x + 1] >= 0) ||
                        (y > 0 && g[(y - 1) * W + x] >= 0) ||
                        (y < H - 1 && g[(y + 1) * W + x] >= 0);
                if (n) { out[y * W + x] = P_K; }
            }
        }

        // Horizontal runs, split at the tail boundary so the tail can wiggle separately.
        // Non-jelly runs are also merged vertically (same x, width and color) so a frame
        // draws fewer rectangles; the covered pixels are identical.
        var split = left - 1;
        var runs = [];
        var prev = [];
        for (var y = 0; y < H; y++) {
            var cur = [];
            var x = 0;
            while (x < W) {
                var c = out[y * W + x];
                if (c < 0) { x++; continue; }
                var j = x + 1;
                while (j < W && j != split && out[y * W + j] == c) { j++; }
                var m = null;
                if (!jelly) {
                    for (var k = 0; k < prev.size(); k++) {
                        var p = prev[k];
                        if (p[0] == x && p[2] == j - x && p[3] == c && p[1] + p[4] == y) { m = p; break; }
                    }
                }
                if (m != null) {
                    m[4] = m[4] + 1;
                    cur.add(m);
                } else {
                    var nr = [x, y, j - x, c, 1];
                    runs.add(nr);
                    cur.add(nr);
                }
                x = j;
            }
            prev = cur;
        }
        var flat = [];
        for (var i = 0; i < runs.size(); i++) {
            var r = runs[i];
            flat.add(r[0]); flat.add(r[1]); flat.add(r[2]); flat.add(r[3]); flat.add(r[4]);
        }

        var hi = evo ? PixelKit.tint(cols[2], 0.35) : cols[2];
        var pal = [cols[4], cols[0], cols[1], hi, cols[3], 0xFFFFFF, 0x0B0B14, FishDatabase.ACCENT[sp]];
        for (var m = 0; m < marks.size(); m++) { pal.add(marks[m][4]); }

        return {:runs => flat, :pal => pal, :tail => split, :jelly => jelly, :wig => skirt + 1};
    }

    // ---- Decorations -------------------------------------------------------
    const DECOR = [
        ["....kkkkkkkk....",
         "..kkgGGGGGggkk..",
         ".kgGGggggggggdk.",
         "kgGgkkkkkkkkgddk",
         "kggk........kgdk",
         "kggk........kgdk",
         "kgdk........kgdk",
         "kgdk........kddk",
         "kkkk........kkkk"],
        ["..kkkkkkkk..",
         ".kBBBBBBBBk.",
         "kBbbbbbbbbBk",
         "kkkkkyykkkkk",
         "kbbbbyybbbbk",
         "kBbbbbbbbbBk",
         "kbbbbbbbbbbk",
         "kBbbbbbbbbBk",
         "kkkkkkkkkkkk"],
        ["....kkkk....",
         "..kkYYYYkk..",
         ".kyYYYYYYyk.",
         ".kyykkkkyyk.",
         "kyykwccckyyk",
         "kyykcccckyyk",
         "kyykcccckyyk",
         ".kyykkkkyyk.",
         ".kyyyyyyyyk.",
         "kkkkkkkkkkkk",
         "kYYYYYYYYYYk",
         "kkkkkkkkkkkk"],
        ["k.k.k..k.k.k",
         "kkkkk..kkkkk",
         "kGggk..kGggk",
         "kGdgkkkkGdgk",
         "kGggGGggGggk",
         "kGggggggGggk",
         "kGggkkkkGggk",
         "kGggkddkGggk",
         "kGggkddkGggk",
         "kkkkkkkkkkkk"],
        ["......kk........",
         "......kbk.......",
         "......kbk..kk...",
         "....kkkbkkkbk...",
         "..kkBBBBBBBBBkk.",
         ".kbbbdbbbbdbbbbk",
         "kbbbbbbbbbbbbbk.",
         "kbyybbdbbbbbyyk.",
         ".kkkkkkkkkkkkk.."],
        ["..kkkkkkkk..",
         ".kPPpPPpPPk.",
         "kPpPPpPPpPPk",
         "kppppwwppppk",
         "kpppwwwwpppk",
         "kkkkkkkkkkkk",
         "kPpPPpPPpPPk",
         ".kkkkkkkkkk."],
        ["...kk...",
         "..kssk..",
         ".kkkkkk.",
         ".kyYYyk.",
         ".kYYYYk.",
         ".kYYYYk.",
         ".kyYYyk.",
         ".kkkkkk.",
         "...ks...",
         "...ks...",
         "..kssk..",
         ".kkkkkk."]
    ];
    const DECOR_KEYS = ["kgGd", "kbBy", "kyYcw", "kgGd", "kbBdy", "kpPw", "ksyY"];
    const DECOR_COLS = [
        [0x1E1A2A, 0x6E6A80, 0x9A96AE, 0x4A4660],
        [0x2A1608, 0x7E4E22, 0xB07A3E, 0xFFC93C],
        [0x2A1A10, 0xB8733A, 0xE8A25C, 0x173F4F, 0x9FE8FF],
        [0x1C1A28, 0x8C8AA0, 0xB8B6CC, 0x0B0B14],
        [0x1A0E06, 0x6A4220, 0x8E5E30, 0x2A1A0C, 0x4F7A3A],
        [0x2A1430, 0x7A4A9A, 0xB27FD6, 0xF4F0FF],
        [0x14141F, 0x5A5A70, 0xFFB84A, 0xFFF1A0]
    ];

    // ---- Icons (8x8 unless noted) ------------------------------------------
    const ICON_KEYS = "kwoyYdrbcgpsn";
    const ICON_COLS = [0x1A1424, 0xE0E6F0, 0xFF8C2E, 0xFFC93C, 0xFFF1A0, 0xC98A10, 0xFF5A7A,
                       0x4FA3FF, 0x7FE7FF, 0x5EE36A, 0xC77DFF, 0xB0BEC5, 0x8B5A2B];

    const ICON_FEED = ["..kkkk..", ".kwwwwk.", ".kkkkkk.", ".kooook.", ".koyyok.", ".kooook.", ".kooook.", "..kkkk.."];
    // Kitchen sponge: green scrub layer on yellow foam with pores, under soap bubbles (10x9).
    const ICON_CLEAN = [".......c..", "......c.c.", "..c....c..", ".kkkkkkkk.", "kggggggggk",
                        "kkkkkkkkkk", "kyydyyyydk", "kyyyydyyyk", ".kkkkkkkk."];
    const ICON_MENU = ["........", "wwwwwwww", "........", "........", "wwwwwwww", "........", "........", "wwwwwwww"];
    const ICON_COIN = ["..kkkk..", ".kYYyyk.", "kYyyyydk", "kYyddydk", "kYyddydk", "kyyyyydk", ".kyyddk.", "..kkkk.."];
    const ICON_HEART = [".rr.rr.", "rrrrrrr", "rrrrrrr", ".rrrrr.", "..rrr..", "...r..."];
    const ICON_PEARL = ["..kkkk..", ".kwwssk.", "kwwwsssk", "kwwssssk", "kssssssk", "kssssssk", ".kssssk.", "..kkkk.."];
    const ICON_KEY = [".kkk....", "kyyyk...", "kykyk...", "kyyykkkk", ".kkkyyyy", "....kykk", "....ky..", "........"];
    const ICON_EGG = ["..kkkk..", ".kwwwwk.", "kwwpwwwk", "kwwwwpwk", "kwpwwwwk", "kwwwwwwk", ".kwwwwk.", "..kkkk.."];
    const ICON_TROPHY = ["kkkkkkkk", "kyYyyyyk", "kyYyyyyk", ".kyyyyk.", "..kyyk..", "...kk...", "..kyyk..", ".kkkkkk."];
    const ICON_STAR = ["...yy...", "...yy...", "yyyyyyyy", ".yyyyyy.", "..yyyy..", ".yyyyyy.", ".yy..yy.", "y......y"];
    const ICON_SHOE = ["........", "..kkk...", "..kook..", "..koookk", "kkoooook", "kooooook", "kwwwwwwk", "kkkkkkkk"];
    const ICON_STEPS = [".ww.....", "www.....", "www..ww.", ".w..www.", "....www.", ".....w..", "........", "........"];
    const ICON_MAP = ["kkkkkkkk", "kYYYYYYk", "kYbbYrYk", "kYbYYYYk", "kYYYrrYk", "kYgYYrYk", "kYggYYYk", "kkkkkkkk"];
    const ICON_GAME = ["........", ".kkkkkk.", "kssssssk", "kswssrsk", "kwwwsrsk", "kswssssk", "kssssssk", ".kk..kk."];
    const ICON_BAG = ["..kkkk..", ".k....k.", "kkkkkkkk", "knnnnnnk", "knnyynnk", "knnnnnnk", "knnnnnnk", "kkkkkkkk"];
    const ICON_SHOP = ["kkkkkkkk", "krwrwrwk", "krwrwrwk", "kkkkkkkk", "kssssssk", "ksnnsssk", "ksnnsssk", "kkkkkkkk"];
    const ICON_GEAR = ["...ss...", ".s.ss.s.", "..ssss..", "sss..sss", "sss..sss", "..ssss..", ".s.ss.s.", "...ss..."];
    const ICON_PROFILE = ["..cccc..", ".cccccc.", ".cccccc.", "..cccc..", "........", ".cccccc.", "cccccccc", "cccccccc"];
    const ICON_QUEST = [".kkkkkk.", "kYYYYYYk", "kYkkkkYk", "kYYYYYYk", "kYkkkYYk", "kYYYYYYk", "kYkkkkYk", ".kkkkkk."];
    const ICON_DEX = ["kkkkkkkk", "kbbbbbbk", "kbwwwwbk", "kbwbbwbk", "kbwwwwbk", "kbbbbbbk", "kbbbbbbk", "kkkkkkkk"];
    const ICON_BUILD = [".kkkkk..", "ksssssk.", ".kkskk..", "...nk...", "...nk...", "...nk...", "...nk...", "...kk..."];
    const ICON_SHIELD = ["kkkkkkkk", "kcccccck", "kccyycck", "kcyyyyck", "kccyycck", ".kcccck.", "..kcck..", "...kk..."];
    const ICON_FISH = ["........", "...ooo..", "o.ooooo.", "oooooook", "oooooooo", "o.ooooo.", "...ooo..", "........"];
    const ICON_LOCK = ["..kkkk..", ".k....k.", ".k....k.", "kkkkkkkk", "kssssssk", "ksskkssk", "kssssssk", "kkkkkkkk"];
    const ICON_CHECK = ["........", "......gg", ".....gg.", "gg..gg..", ".gggg...", "..gg....", "........", "........"];
    const ICON_CHEST = ["..kkkk..", ".knnnnk.", "knnnnnnk", "kkkyykkk", "knnyynnk", "knnnnnnk", "knnnnnnk", "kkkkkkkk"];
    const ICON_WAVE = ["........", ".bb.....", "b..b..bb", "....bb..", "........", ".cc.....", "c..c..cc", "....cc.."];

    // Egg shell/spot colors per egg type (CollectionSystem.EGG_NAME order).
    const EGG_COLS = [
        [0x1A1424, 0xF4EEDC, 0xB0A890],
        [0x1A1424, 0x9FD8FF, 0x4F7BFF],
        [0x1A1424, 0xD9B0FF, 0x7A3AB0],
        [0x1A1424, 0xE8C0FF, 0xC77DFF],
        [0x1A1424, 0xFFE9A0, 0xFFC93C],
        [0x1A1424, 0xFFD0E0, 0xFF6B9A]
    ];
}
