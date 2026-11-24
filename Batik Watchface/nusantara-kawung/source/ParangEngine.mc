import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Procedural Parang generator.
// Parang runs in diagonal bands ("\"). Inside a band, slender S-bars stand side by side;
// each long bar ends in a round ball at the top and a shorter curved bar beside it ends in
// a ball at the bottom, so balls alternate along both band edges.
// One unit = one long bar + its short companion.
//
// Directional Flow: units are ordered along the band direction, so progress sweeps
// from top-left to bottom-right through every band at once, following the way the
// motif repeats.
class ParangEngine extends MotifEngine {

    enum {
        DORMANT,
        AWAKENING,
        BLOOM
    }


    private var _w as Number = 0;
    private var _h as Number = 0;
    private var _round as Boolean = true;

    // Offsets from a unit centre, already rotated into screen space.
    private var _long as Array<Float> = [] as Array<Float>;   // long bar outline
    private var _short as Array<Float> = [] as Array<Float>;  // short bar outline
    private var _balls as Array<Float> = [] as Array<Float>;  // x0,y0,x1,y1 (top, bottom)
    private var _ballR as Number = 2;

    function initialize() {
        MotifEngine.initialize();
    }

    function ornament(dc as Dc, x as Number, y as Number, size as Number) as Void {
        var s = barShape(size * 0.5, size * 0.6);
        stroke(dc, place(s[0], x, y));
        var b = s[1];
        dc.drawCircle(x + b[0], y + b[1], size / 9 + 1);
    }

    // Band frame -> screen. u = along the band (down-right), v = across it (up-right).
    static function toScreen(u as Float or Double, v as Float or Double, out as Array<Float>) as Void {
        var k = 0.70710678;
        out.add(((u + v) * k).toFloat());
        out.add(((u - v) * k).toFloat());
    }

    // A tapered bar from (u0,v0) to (u1,v1) in the band frame with a gentle S bend.
    // thick = half width at the middle. Returns a closed outline in screen space.
    static function barOffsets(u0 as Float or Double, v0 as Float or Double, u1 as Float or Double, v1 as Float or Double,
                               bend as Float or Double, thick as Float or Double) as Array<Float> {
        // Capsule-like bar: near-constant width, gentle S bend, round caps at both ends.
        var steps = 8;
        var du = u1 - u0;
        var dv = v1 - v0;
        var len = Math.sqrt(du * du + dv * dv);
        if (len < 0.001) {
            len = 1.0;
        }
        var tu = du / len;
        var tv = dv / len;
        var nu = -tv;
        var nv = tu;
        var cu = [] as Array<Float>;
        var cv = [] as Array<Float>;
        for (var i = 0; i <= steps; i++) {
            var t = i.toFloat() / steps;
            var off = bend * Math.sin(2 * Math.PI * t);
            cu.add((u0 + du * t + nu * off).toFloat());
            cv.add((v0 + dv * t + nv * off).toFloat());
        }
        var out = [] as Array<Float>;
        for (var i = 0; i <= steps; i++) {
            var t = i.toFloat() / steps;
            var w = thick * (0.88 + 0.12 * Math.sin(Math.PI * t));
            toScreen(cu[i] + nu * w, cv[i] + nv * w, out);
        }
        // end cap: from +n round the tip to -n
        var we = thick * 0.88;
        for (var k = 1; k < 4; k++) {
            var a = Math.PI / 2 - k * Math.PI / 4;
            toScreen(cu[steps] + (tu * Math.cos(a) + nu * Math.sin(a)) * we,
                     cv[steps] + (tv * Math.cos(a) + nv * Math.sin(a)) * we, out);
        }
        for (var i = steps; i >= 0; i--) {
            var t = i.toFloat() / steps;
            var w = thick * (0.88 + 0.12 * Math.sin(Math.PI * t));
            toScreen(cu[i] - nu * w, cv[i] - nv * w, out);
        }
        // start cap: from -n round the tail to +n
        for (var k = 1; k < 4; k++) {
            var a = -Math.PI / 2 - k * Math.PI / 4;
            toScreen(cu[0] + (tu * Math.cos(a) + nu * Math.sin(a)) * we,
                     cv[0] + (tv * Math.cos(a) + nv * Math.sin(a)) * we, out);
        }
        return out;
    }

    // Long bar + the ball above it, for one Parang unit of step `l` in a band of half width hb
    // (also used by the AOD ornament).
    static function barShape(l as Float or Double, hb as Float or Double) as [Array<Float>, Array<Float>] {
        var lean = hb * 0.72;   // tilts the bars from 45 deg toward vertical
        var bar = barOffsets(lean * 0.8, -hb * 0.78, -lean * 0.8, hb * 0.58, l * 0.06, l * 0.19);
        var ball = [] as Array<Float>;
        toScreen(-lean * 1.0, hb * 0.90, ball);
        return [bar, ball];
    }

    function build(w as Number, h as Number, cellSize as Number, round as Boolean) as Void {
        _w = w;
        _h = h;
        _round = round;
        cell = cellSize;

        var band = cellSize * 3.2;       // band + gap, across the band
        var hb = band * 0.43;            // half width of the bars' band; the rest is a narrow channel
        var l = band * 0.25;             // unit repeat along the band: bars stand close together

        var main = barShape(l, hb);
        _long = main[0];
        _balls = [] as Array<Float>;
        _balls.addAll(main[1]);
        // short companion half a step further along, hanging from the lower edge
        var lean = hb * 0.72;
        var su = l * 0.5;
        _short = barOffsets(su + lean * 0.45, -hb * 0.50, su - lean * 0.75, hb * 0.82, -l * 0.05, l * 0.15);
        toScreen(su + lean * 0.75, -hb * 0.80, _balls);
        _ballR = (l * 0.34).toNumber();
        if (_ballR < 2) {
            _ballR = 2;
        }
        spriteBounds();
        _spriteKey = -1;

        var cx = w / 2;
        var cy = h / 2;
        var r = (w < h ? w : h) / 2;
        var reach = (round ? r : (w > h ? w : h) / 2) + band;
        var nk = (reach / band).toNumber() + 1;
        var nm = (reach / l).toNumber() + 1;
        var k = 0.70710678;

        // Each unit is one Long: flow key in the high 32 bits, packed x/y in the low 32.
        var items = [] as Array<Long>;
        for (var bi = -nk; bi <= nk; bi++) {
            for (var mi = -nm; mi <= nm; mi++) {
                var u = mi * l;
                var v = bi * band;
                var x = cx + ((u + v) * k);
                var y = cy + ((u - v) * k);
                if (round) {
                    var dx = x - cx;
                    var dy = y - cy;
                    if (dx * dx + dy * dy > (r + band * 0.5) * (r + band * 0.5)) {
                        continue;
                    }
                } else if (x < -band || x > w + band || y < -band || y > h + band) {
                    continue;
                }
                // Directional Flow: along the band first, then across it (top band first).
                var key = ((u + 4000) * 16).toNumber() * 64 + (32 - bi);
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
            var a = pts[i];
            var b = pts[(i + 1) % n];
            dc.drawLine(a[0], a[1], b[0], b[1]);
        }
    }

    // Every unit has the same shape, so each stage is rendered once into a small sprite with
    // a transparent background and stamped per unit. Keeps redraws far under the watchdog.
    private var _sprites as Array<Graphics.BufferedBitmapReference?> = [null, null, null] as Array<Graphics.BufferedBitmapReference?>;
    private var _spriteKey as Number = -1;
    private var _sx as Number = 0;   // sprite anchor: unit centre inside the sprite
    private var _sy as Number = 0;
    private var _sw as Number = 1;
    private var _sh as Number = 1;

    private function spriteBounds() as Void {
        var minX = 0.0;
        var minY = 0.0;
        var maxX = 0.0;
        var maxY = 0.0;
        var all = [] as Array<Float>;
        all.addAll(_long);
        all.addAll(_short);
        all.addAll(_balls);
        for (var i = 0; i < all.size(); i += 2) {
            var px = all[i];
            var py = all[i + 1];
            if (px < minX) { minX = px; }
            if (px > maxX) { maxX = px; }
            if (py < minY) { minY = py; }
            if (py > maxY) { maxY = py; }
        }
        var pad = _ballR + 3;
        _sx = (-minX).toNumber() + pad;
        _sy = (-minY).toNumber() + pad;
        _sw = (maxX - minX).toNumber() + 2 * pad;
        _sh = (maxY - minY).toNumber() + 2 * pad;
    }

    private function sprites(pal as Array<Number>, colorway as Number) as Array<Graphics.BufferedBitmap>? {
        if (!(Graphics has :createBufferedBitmap)) {
            return null;
        }
        var key = colorway * 4096 + cell;
        var fresh = key != _spriteKey;
        var out = [] as Array<Graphics.BufferedBitmap>;
        for (var s = 0; s < 3; s++) {
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
                drawUnit(sdc, pal, _sx, _sy, s);
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
            if (sp != null) {
                dc.drawBitmap(Living.unpackX(p) - _sx, Living.unpackY(p) - _sy, sp[stage]);
            } else {
                drawUnit(dc, pal, Living.unpackX(p), Living.unpackY(p), stage);
            }
        }

        if (complete) {
            var cx = _w / 2;
            var cy = _h / 2;
            var r = (_w < _h ? _w : _h) / 2;
            dc.setColor(pal[Palette.ACCENT], Graphics.COLOR_TRANSPARENT);
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

    private function drawUnit(dc as Dc, pal as Array<Number>, x as Number, y as Number, stage as Number) as Void {
        var bars = [place(_long, x, y), place(_short, x, y)];
        var bx0 = x + _balls[0];
        var by0 = y + _balls[1];
        var bx1 = x + _balls[2];
        var by1 = y + _balls[3];
        if (stage == DORMANT) {
            // Dormant still reads as finished batik: thin bar and ball outlines.
            dc.setPenWidth(1);
            dc.setColor(pal[Palette.SKELETON], Graphics.COLOR_TRANSPARENT);
            stroke(dc, bars[0]);
            stroke(dc, bars[1]);
            dc.setColor(pal[Palette.DARK], Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(bx0, by0, _ballR);
            dc.drawCircle(bx1, by1, _ballR);
            return;
        }
        if (stage == AWAKENING || mono) {
            // Awakening: gilded outlines, the balls already solid.
            dc.setPenWidth(mono ? 1 : 2);
            dc.setColor(pal[Palette.MID], Graphics.COLOR_TRANSPARENT);
            stroke(dc, bars[0]);
            stroke(dc, bars[1]);
            dc.setPenWidth(1);
            dc.setColor(pal[Palette.ACCENT], Graphics.COLOR_TRANSPARENT);
            if (mono && stage == BLOOM) {
                dc.fillPolygon(bars[1]);
            }
            dc.fillCircle(bx0, by0, _ballR);
            dc.fillCircle(bx1, by1, _ballR);
            return;
        }
        // Bloom: solid gold bars and balls.
        dc.setColor(pal[Palette.MID], Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(bars[0]);
        dc.fillPolygon(bars[1]);
        dc.setColor(pal[Palette.LIGHT], Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx0, by0, _ballR);
        dc.fillCircle(bx1, by1, _ballR);
    }
}
