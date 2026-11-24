import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Procedural Mega Mendung generator (Cirebon cloud motif).
// One unit = one cloud: a long shape pointed at both ends, drawn as nested layers that
// step from a light rim to a deep core (the "gradasi" of Mega Mendung), with a spiral
// curl inside. Clouds sit in staggered, overlapping rows.
//
// Rising Layers: units are ordered bottom row first, so the sky fills upward as the day's
// steps add up, the way the clouds rise in the motif.
class PatternEngine {

    enum {
        DORMANT,
        AWAKENING,
        BLOOM
    }

    const LAYERS = 4;

    var units as Array<Number> = [] as Array<Number>; // packed cloud centre x/y, in rising order
    var cell as Number = 0;
    // Monochrome panels (Instinct) use line work instead of solid fills.
    var mono as Boolean = false;

    private var _w as Number = 0;
    private var _h as Number = 0;
    private var _round as Boolean = true;

    private var _layers as Array<Array<Float> > = [] as Array<Array<Float> >; // outer -> inner
    private var _curl as Array<Float> = [] as Array<Float>;                   // open polyline
    private var _curl2 as Array<Float> = [] as Array<Float>;                  // small second curl

    // sprite cache: one bitmap per stage, stamped per unit
    private var _sprites as Array<Graphics.BufferedBitmapReference?> = [null, null, null, null, null, null] as Array<Graphics.BufferedBitmapReference?>;
    private var _spriteKey as Number = -1;
    private var _sx as Number = 0;
    private var _sy as Number = 0;
    private var _sw as Number = 1;
    private var _sh as Number = 1;
    private var _flip as Boolean = false; // draw the mirrored variant

    function initialize() {
    }

    // Cloud outline: a flat lens pointed at both ends, with three round lobes (head, middle,
    // small) rising from its top edge, the way Mega Mendung clouds billow. The outline is
    // sampled as one polygon (top = highest of lens and lobes), then scaled by f toward the
    // cloud's core, so nested layers stay concentric.
    static function cloudOffsets(a as Float or Double, b as Float or Double, f as Float or Double) as Array<Float> {
        var lobes = [-0.52, 0.05, 0.82,   -0.08, 0.08, 0.72,   0.34, 0.20, 0.54,   0.66, 0.30, 0.32]; // cx/a, cy/b, r/b
        var ax = -0.10 * a;   // scaling anchor (core)
        var ay = 0.05 * b;
        var n = 26;
        var top = [] as Array<Float>;
        var bot = [] as Array<Float>;
        for (var i = 0; i <= n; i++) {
            var x = -a + 2 * a * i / n;
            var u = x / a;
            var lens = 1.0 - u * u;
            var yt = -0.22 * b * lens;
            for (var j = 0; j < 12; j += 3) {
                var cx = lobes[j] * a;
                var cy = lobes[j + 1] * b;
                var r = lobes[j + 2] * b;
                var dx = x - cx;
                if (dx * dx < r * r) {
                    var yy = cy - Math.sqrt(r * r - dx * dx);
                    if (yy < yt) {
                        yt = yy;
                    }
                }
            }
            top.add((ax + (x - ax) * f).toFloat());
            top.add((ay + (yt - ay) * f).toFloat());
            bot.add((ax + (x - ax) * f).toFloat());
            bot.add((ay + (0.42 * b * lens - ay) * f).toFloat());
        }
        var out = [] as Array<Float>;
        out.addAll(top);
        for (var i = bot.size() - 4; i >= 2; i -= 2) {
            out.add(bot[i]);
            out.add(bot[i + 1]);
        }
        return out;
    }

    // Spiral curl centred at (cx, cy), radius r, curling inward clockwise.
    static function curlOffsets(cx as Float or Double, cy as Float or Double, r as Float or Double) as Array<Float> {
        var out = [] as Array<Float>;
        var steps = 18;
        for (var i = 0; i <= steps; i++) {
            var t = i.toFloat() / steps;
            var ang = Math.PI * 0.9 + t * 3.2 * Math.PI;
            var rr = r * (1.0 - 0.82 * t);
            out.add((cx + rr * Math.cos(ang)).toFloat());
            out.add((cy + rr * Math.sin(ang)).toFloat());
        }
        return out;
    }

    function build(w as Number, h as Number, cellSize as Number, round as Boolean) as Void {
        _w = w;
        _h = h;
        _round = round;
        cell = cellSize;

        var a = cellSize * 2.1;   // half length of a cloud
        var b = cellSize * 1.05;   // half height
        _layers = [] as Array<Array<Float> >;
        for (var k = 0; k < LAYERS; k++) {
            var f = 1.0 - k * 0.21;                 // each layer steps inward
            _layers.add(cloudOffsets(a, b, f));
        }
        _curl = curlOffsets(-a * 0.52, -b * 0.20, b * 0.55);
        _curl2 = curlOffsets(-a * 0.06, -b * 0.10, b * 0.42);

        // sprite bounds from the outer layer
        var o = _layers[0];
        var minX = 0.0;
        var minY = 0.0;
        var maxX = 0.0;
        var maxY = 0.0;
        for (var i = 0; i < o.size(); i += 2) {
            if (o[i] < minX) { minX = o[i]; }
            if (o[i] > maxX) { maxX = o[i]; }
            if (o[i + 1] < minY) { minY = o[i + 1]; }
            if (o[i + 1] > maxY) { maxY = o[i + 1]; }
        }
        // symmetric box so the mirrored variant fits the same sprite size
        var mx = (-minX > maxX ? -minX : maxX);
        _sx = mx.toNumber() + 3;
        _sy = (-minY).toNumber() + 3;
        _sw = (2 * mx).toNumber() + 6;
        _sh = (maxY - minY).toNumber() + 6;
        _spriteKey = -1;

        // Staggered rows; clouds overlap a little, like the cloth.
        var colStep = a * 1.50;
        var rowStep = b * 1.30;
        var cx = w / 2;
        var cy = h / 2;
        var r = (w < h ? w : h) / 2;
        var nr = ((round ? r : h / 2) / rowStep).toNumber() + 2;
        var nc = ((round ? r : w / 2) / colStep).toNumber() + 2;
        var items = [] as Array<Long>;
        for (var ri = -nr; ri <= nr; ri++) {
            var shift = (ri % 2 == 0) ? 0.0 : colStep / 2;
            for (var ci = -nc; ci <= nc; ci++) {
                // deterministic jitter breaks the grid so the sky looks hand drawn
                var h1 = ((ci * 37 + ri * 91 + 1000) % 7) - 3;
                var h2 = ((ci * 53 + ri * 29 + 1000) % 5) - 2;
                var x = cx + ci * colStep + shift + h1 * a * 0.07;
                var y = cy + ri * rowStep + h2 * b * 0.12;
                if (round) {
                    var dx = x - cx;
                    var dy = y - cy;
                    var lim = r + a * 0.6;
                    if (dx * dx + dy * dy > lim * lim) {
                        continue;
                    }
                } else if (x < -a || x > w + a || y < -b * 2 || y > h + b * 2) {
                    continue;
                }
                // Rising Layers: bottom row first, then left to right.
                var key = (nr - ri + 64) * 4096 + (ci + 2048);
                var p = Living.pack(x.toNumber(), y.toNumber());
                items.add((key.toLong() << 32) | (p.toLong() & 0xFFFFFFFFl));
            }
        }
        items.sort(null);
        var pts = new Array<Number>[items.size()];
        for (var i = 0; i < items.size(); i++) {
            pts[i] = (items[i] & 0xFFFFFFFFl).toNumber();
        }
        units = pts;
    }

    static function place(offs as Array<Float>, x as Number, y as Number) as Array<[Numeric, Numeric]> {
        var pts = [] as Array<[Numeric, Numeric]>;
        for (var i = 0; i < offs.size(); i += 2) {
            pts.add([x + offs[i], y + offs[i + 1]]);
        }
        return pts;
    }

    static function stroke(dc as Dc, pts as Array<[Numeric, Numeric]>) as Void {
        var n = pts.size();
        for (var i = 0; i < n; i++) {
            var p = pts[i];
            var q = pts[(i + 1) % n];
            dc.drawLine(p[0], p[1], q[0], q[1]);
        }
    }

    static function polyline(dc as Dc, pts as Array<[Numeric, Numeric]>) as Void {
        for (var i = 0; i + 1 < pts.size(); i++) {
            var p = pts[i];
            var q = pts[i + 1];
            dc.drawLine(p[0], p[1], q[0], q[1]);
        }
    }

    private function sprites(pal as Array<Number>, colorway as Number) as Array<Graphics.BufferedBitmap>? {
        if (!(Graphics has :createBufferedBitmap)) {
            return null;
        }
        var key = colorway * 4096 + cell;
        var fresh = key != _spriteKey;
        var out = [] as Array<Graphics.BufferedBitmap>;
        for (var s = 0; s < 6; s++) {
            var ref = _sprites[s];
            var bmp = ref != null ? ref.get() as Graphics.BufferedBitmap? : null;
            var redraw = fresh;
            if (bmp == null) {
                ref = Graphics.createBufferedBitmap({:width => _sw, :height => _sh});
                _sprites[s] = ref;
                bmp = ref.get() as Graphics.BufferedBitmap?;
                redraw = true;
            }
            if (bmp == null) {
                return null;
            }
            if (redraw) {
                var sdc = bmp.getDc();
                if (sdc has :setAntiAlias) {
                    sdc.setAntiAlias(true);
                }
                sdc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
                sdc.clear();
                _flip = s >= 3;
                drawUnit(sdc, pal, _sx, _sy, s % 3);
                _flip = false;
            }
            out.add(bmp);
        }
        _spriteKey = key;
        return out;
    }

    // bloom: units fully in bloom; awake: units at least awakening (awake >= bloom).
    function draw(dc as Dc, pal as Array<Number>, colorway as Number, bloom as Number, awake as Number, complete as Boolean) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        dc.setColor(pal[Palette.BG], pal[Palette.BG]);
        dc.clear();
        var count = units.size();
        var sp = sprites(pal, colorway);
        for (var i = 0; i < count; i++) {
            var p = units[i];
            var stage = i < bloom ? BLOOM : (i < awake ? AWAKENING : DORMANT);
            var ux = Living.unpackX(p);
            var uy = Living.unpackY(p);
            var v = ((ux / 7 + uy / 5) % 3 == 0) ? 3 : 0;   // about a third face the other way
            if (sp != null) {
                dc.drawBitmap(ux - _sx, uy - _sy, sp[stage + v]);
            } else {
                _flip = v == 3;
                drawUnit(dc, pal, ux, uy, stage);
                _flip = false;
            }
        }

        if (complete) {
            var cx = _w / 2;
            var cy = _h / 2;
            var r = (_w < _h ? _w : _h) / 2;
            dc.setColor(pal[Palette.LIGHT], Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            if (_round) {
                dc.drawCircle(cx, cy, r - 3);
                dc.setPenWidth(1);
                dc.drawCircle(cx, cy, r - 9);
            } else {
                dc.drawRoundedRectangle(3, 3, _w - 6, _h - 6, r / 4);
                dc.setPenWidth(1);
                dc.drawRoundedRectangle(9, 9, _w - 18, _h - 18, r / 4);
            }
        }
        dc.setPenWidth(1);
    }

    // place() honouring the mirrored variant
    private function pv(offs as Array<Float>, x as Number, y as Number) as Array<[Numeric, Numeric]> {
        if (!_flip) {
            return place(offs, x, y);
        }
        var pts = [] as Array<[Numeric, Numeric]>;
        for (var i = 0; i < offs.size(); i += 2) {
            pts.add([x - offs[i], y + offs[i + 1]]);
        }
        return pts;
    }

    private function drawUnit(dc as Dc, pal as Array<Number>, x as Number, y as Number, stage as Number) as Void {
        if (stage == DORMANT) {
            // Dormant still reads as finished batik: outer contour and curl as fine lines.
            // The cloud is filled with the background so overlapping clouds stay clean.
            var outer = pv(_layers[0], x, y);
            dc.setColor(pal[Palette.BG], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(outer);
            dc.setPenWidth(1);
            dc.setColor(pal[Palette.SKELETON], Graphics.COLOR_TRANSPARENT);
            stroke(dc, outer);
            stroke(dc, pv(_layers[2], x, y));
            dc.setColor(pal[Palette.DARK], Graphics.COLOR_TRANSPARENT);
            polyline(dc, pv(_curl, x, y));
            return;
        }
        if (stage == AWAKENING || mono) {
            // Awakening: every layer traced in light lines.
            dc.setColor(pal[Palette.BG], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(pv(_layers[0], x, y));
            for (var k = 0; k < LAYERS; k++) {
                dc.setPenWidth(k == 0 && !mono ? 2 : 1);
                dc.setColor(k == 0 ? pal[Palette.LIGHT] : pal[Palette.ACCENT], Graphics.COLOR_TRANSPARENT);
                stroke(dc, pv(_layers[k], x, y));
            }
            dc.setPenWidth(mono ? 1 : 2);
            dc.setColor(pal[Palette.LIGHT], Graphics.COLOR_TRANSPARENT);
            polyline(dc, pv(_curl, x, y));
            if (mono && stage == BLOOM) {
                polyline(dc, pv(_curl2, x, y));
            }
            dc.setPenWidth(1);
            return;
        }
        // Bloom: filled gradation, light rim to deep core, white curls on top.
        var tones = [pal[Palette.LIGHT], pal[Palette.ACCENT], pal[Palette.MID], pal[Palette.DARK]];
        for (var k = 0; k < LAYERS; k++) {
            dc.setColor(tones[k], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(pv(_layers[k], x, y));
        }
        dc.setPenWidth(3);
        dc.setColor(pal[Palette.LIGHT], Graphics.COLOR_TRANSPARENT);
        polyline(dc, pv(_curl, x, y));
        dc.setPenWidth(2);
        polyline(dc, pv(_curl2, x, y));
        dc.setPenWidth(1);
    }
}
