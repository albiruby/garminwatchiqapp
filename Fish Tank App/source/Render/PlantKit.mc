import Toybox.Lang;
import Toybox.Math;

// Procedural pixel plants. `b` is the block size, `cols` = [main, dark, light],
// `sway` shifts the wave phase so foreground plants can move.
module PlantKit {
    const KELP = 0;
    const GRASS = 1;
    const SWORD = 2;
    const CORAL = 3;
    const TUBE = 4;
    const ANEMONE = 5;
    const CRYSTAL = 6;
    const MUSHROOM = 7;
    const ROCK = 8;

    function draw(dc, kind, x, baseY, h, b, cols, seed, sway) {
        if (kind == KELP) { kelp(dc, x, baseY, h, b, cols, seed, sway); }
        else if (kind == GRASS) { grass(dc, x, baseY, h, b, cols, seed, sway); }
        else if (kind == SWORD) { sword(dc, x, baseY, h, b, cols, seed, sway); }
        else if (kind == CORAL) { coral(dc, x, baseY, h, b, cols); }
        else if (kind == TUBE) { tube(dc, x, baseY, h, b, cols, seed); }
        else if (kind == ANEMONE) { anemone(dc, x, baseY, h, b, cols, seed, sway); }
        else if (kind == CRYSTAL) { crystal(dc, x, baseY, h, b, cols); }
        else if (kind == MUSHROOM) { mushroom(dc, x, baseY, h, b, cols); }
        else { rock(dc, x, baseY, h, b, cols); }
    }

    function kelp(dc, x, baseY, h, b, cols, seed, sway) {
        var rows = h / b;
        for (var s = 0; s < 2; s++) {
            var ox = x + (s == 0 ? -2 * b : 2 * b);
            var rr = s == 0 ? rows : rows * 3 / 4;
            for (var i = 0; i < rr; i++) {
                var yy = baseY - (i + 1) * b;
                var amp = 1.0 + i * 0.04;
                var xx = ox + (Math.sin(i * 0.3 + seed + s * 1.7 + sway) * 2.0 * amp).toNumber() * b;
                PixelKit.rect(dc, cols[1], xx - b, yy, b, b);
                PixelKit.rect(dc, cols[0], xx, yy, 2 * b, b);
                var m = (i + s) % 4;
                if (i > 2 && m == 1) { PixelKit.rect(dc, cols[2], xx + 2 * b, yy, 2 * b, b); }
                else if (i > 2 && m == 3) { PixelKit.rect(dc, cols[0], xx - 3 * b, yy, 2 * b, b); }
            }
        }
    }

    function grass(dc, x, baseY, h, b, cols, seed, sway) {
        for (var j = 0; j < 6; j++) {
            var bh = (h * (55 + ((j * 37 + seed * 11) % 45)) / 100) / b;
            var lean = (j - 2.5) * 0.18;
            var bx = x + (j - 3) * b * 2;
            for (var i = 0; i < bh; i++) {
                var xx = bx + ((i * lean) + Math.sin(i * 0.35 + j + sway) * 1.2).toNumber() * b;
                var c = (i >= bh - 2) ? cols[2] : ((j % 2 == 0) ? cols[0] : cols[1]);
                PixelKit.rect(dc, c, xx, baseY - (i + 1) * b, b, b);
            }
        }
    }

    function sword(dc, x, baseY, h, b, cols, seed, sway) {
        var angs = [-0.95, -0.55, -0.2, 0.15, 0.5, 0.9];
        for (var k = 0; k < angs.size(); k++) {
            var a = angs[k] + Math.sin(sway + k) * 0.05;
            var len = h * (0.6 + ((k * 29 + seed) % 40) / 100.0);
            var steps = (len / b).toNumber();
            var main = (k % 2 == 0) ? cols[0] : cols[1];
            for (var i = 0; i < steps; i++) {
                var tt = i * b;
                var bend = a * (1.0 + tt / len * 0.8);
                var gx = (x + (Math.sin(bend) * tt).toNumber()) / b * b;
                var gy = (baseY - (Math.cos(bend) * tt).toNumber()) / b * b;
                if (i > 1 && i < steps - 2) {
                    PixelKit.rect(dc, main, gx - b, gy, 3 * b, b);
                    PixelKit.rect(dc, cols[2], gx, gy, b, b);
                } else {
                    PixelKit.rect(dc, main, gx, gy, b, b);
                }
            }
        }
    }

    function coral(dc, x, baseY, h, b, cols) {
        var rows = h / b;
        var trunk = rows * 3 / 10;
        for (var i = 0; i < trunk; i++) {
            PixelKit.rect(dc, cols[0], x - b, baseY - (i + 1) * b, 2 * b, b);
            PixelKit.rect(dc, cols[1], x, baseY - (i + 1) * b, b, b);
        }
        var topY = baseY - trunk * b;
        for (var k = -1; k <= 1; k++) {
            var bx = x;
            var by = topY;
            var len = rows - trunk - (k == 0 ? 0 : rows / 6);
            for (var i = 0; i < len; i++) {
                if (k != 0 && i % 2 == 0) { bx += k * b; }
                else if (k == 0 && i % 4 == 2) { bx += ((i / 4) % 2 == 0) ? b : -b; }
                by -= b;
                PixelKit.rect(dc, cols[0], bx - b, by, 2 * b, b);
                PixelKit.rect(dc, cols[1], bx, by, b, b);
                if (i == len / 2) {
                    var d = (k == 0) ? 1 : -k;
                    var tx = bx;
                    var ty = by;
                    for (var j = 0; j < 3; j++) {
                        tx += d * b;
                        ty -= b;
                        PixelKit.rect(dc, cols[0], tx, ty, b, b);
                    }
                    PixelKit.rect(dc, cols[2], tx, ty - b, b, b);
                }
            }
            PixelKit.rect(dc, cols[2], bx - b, by - b, 2 * b, b);
        }
    }

    function tube(dc, x, baseY, h, b, cols, seed) {
        for (var j = 0; j < 4; j++) {
            var w = (3 + (j + seed) % 2) * b;
            var th = (h * (45 + ((j * 23 + seed * 7) % 55)) / 100) / b * b;
            var tx = x - 7 * b + j * 4 * b - (j % 2) * b;
            var top = baseY - th;
            PixelKit.rect(dc, cols[0], tx, top, w, th);
            PixelKit.rect(dc, cols[2], tx, top, b, th);
            PixelKit.rect(dc, cols[1], tx + w - b, top, b, th);
            PixelKit.rect(dc, cols[2], tx, top - b, w, b);
            PixelKit.rect(dc, PixelKit.shade(cols[1], 0.5), tx + b, top, w - 2 * b, b);
        }
    }

    function anemone(dc, x, baseY, h, b, cols, seed, sway) {
        PixelKit.rect(dc, cols[1], x - 5 * b, baseY - 2 * b, 10 * b, 2 * b);
        PixelKit.rect(dc, cols[0], x - 4 * b, baseY - 3 * b, 8 * b, b);
        for (var j = 0; j < 9; j++) {
            var tx = x - 8 * b + j * 2 * b;
            var th = 4 + ((j * 5 + seed) % 4) + (h / b) / 6;
            for (var i = 0; i < th; i++) {
                var xx = tx + (Math.sin(i * 0.7 + j + sway) * 1.3).toNumber() * b;
                var c = (i >= th - 1) ? cols[2] : cols[0];
                PixelKit.rect(dc, c, xx, baseY - 3 * b - (i + 1) * b, b, b);
            }
        }
    }

    function crystal(dc, x, baseY, h, b, cols) {
        var specs = [[-5, 60, 3], [0, 100, 4], [5, 45, 3]];
        for (var k = 0; k < specs.size(); k++) {
            var sp = specs[k];
            var hh = (h * sp[1] / 100) / b;
            if (hh < 2) { hh = 2; }
            var cx = x + sp[0] * b;
            for (var r = 0; r < hh; r++) {
                var hw = (sp[2] * (hh - r) + hh - 1) / hh;
                var yy = baseY - (r + 1) * b;
                PixelKit.rect(dc, cols[2], cx - hw * b, yy, hw * b, b);
                PixelKit.rect(dc, cols[0], cx, yy, hw * b, b);
                PixelKit.rect(dc, cols[1], cx + (hw - 1) * b, yy, b, b);
            }
            PixelKit.rect(dc, 0xFFFFFF, cx - b, baseY - (hh + 1) * b, b, b);
        }
    }

    function mushroom(dc, x, baseY, h, b, cols) {
        var specs = [[-5, 45], [1, 75], [6, 35]];
        for (var k = 0; k < specs.size(); k++) {
            var sh = (h * specs[k][1] / 100) / b;
            var cx = x + specs[k][0] * b;
            var top = baseY - sh * b;
            PixelKit.rect(dc, PixelKit.tint(cols[2], 0.5), cx - b, top, 2 * b, sh * b);
            PixelKit.rect(dc, cols[1], cx - 4 * b, top, 8 * b, b);
            PixelKit.rect(dc, cols[0], cx - 4 * b, top - b, 8 * b, b);
            PixelKit.rect(dc, cols[0], cx - 3 * b, top - 2 * b, 6 * b, b);
            PixelKit.rect(dc, cols[0], cx - 2 * b, top - 3 * b, 4 * b, b);
            PixelKit.rect(dc, cols[2], cx - 2 * b, top - 2 * b, b, b);
            PixelKit.rect(dc, cols[2], cx + b, top - b, b, b);
        }
    }

    function rock(dc, x, baseY, h, b, cols) {
        var rr = (h / 3) / b;
        if (rr < 4) { rr = 4; }
        for (var r = 0; r < rr; r++) {
            var d = rr - r - 1;
            var hw = (Math.sqrt((rr * rr - d * d).toFloat()) * 1.5).toNumber();
            var yy = baseY - (rr - r) * b;
            var c = (r == 0) ? cols[2] : ((r > rr * 2 / 3) ? cols[1] : cols[0]);
            PixelKit.rect(dc, c, x - hw * b, yy, hw * 2 * b, b);
            if (r > 0) { PixelKit.rect(dc, cols[2], x - hw * b, yy, b, b); }
        }
    }
}
