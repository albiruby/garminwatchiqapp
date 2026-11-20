import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Procedural Kawung generator.
// A Kawung "unit" is a lattice point with four lens-shaped petals pointing diagonally.
// Units are ordered centre-outwards (then by angle) so lighting the first N reads as
// the motif growing from the heart of the dial.
class PatternEngine {

    var units as Array<Number> = [] as Array<Number>; // packed x/y, in lighting order
    var cell as Number = 0;
    // Monochrome panels (Instinct) use line work instead of solid gold fills.
    var mono as Boolean = false;

    // Per direction: flat [x0,y0,x1,y1,...] offsets from the unit centre.
    private var _outer as Array<Array<Float> > = [] as Array<Array<Float> >;
    private var _inner as Array<Array<Float> > = [] as Array<Array<Float> >;
    private var _w as Number = 0;
    private var _h as Number = 0;
    private var _round as Boolean = true;

    function initialize() {
    }

    function build(w as Number, h as Number, cellSize as Number, round as Boolean) as Void {
        _w = w;
        _round = round;
        _h = h;
        cell = cellSize;

        var len = cellSize * 0.64;
        var start = cellSize * 0.07;
        var width = len * 0.50;
        _outer = [] as Array<Array<Float> >;
        _inner = [] as Array<Array<Float> >;
        for (var d = 0; d < 4; d++) {
            var a = Math.PI / 4 + d * Math.PI / 2;
            _outer.add(lensOffsets(a, start, len, width));
            _inner.add(lensOffsets(a, start + len * 0.30, len * 0.42, width * 0.40));
        }

        var cx = w / 2;
        var cy = h / 2;
        var r = (w < h ? w : h) / 2;
        // Round screens keep units inside the circle; other shapes fill every corner.
        var nx = (round ? r : w / 2) / cellSize + 1;
        var ny = (round ? r : h / 2) / cellSize + 1;
        var limit = (r + cellSize * 0.4) / cellSize;
        var limit2 = limit * limit;

        // Each unit is one Long: sort key in the high 32 bits, packed x/y in the low 32.
        // A single native sort keeps build() far below the watchdog limit on slow devices.
        var items = [] as Array<Long>;
        var twoPi = 2 * Math.PI;
        for (var i = -nx; i <= nx; i++) {
            for (var j = -ny; j <= ny; j++) {
                var d2 = i * i + j * j;
                if (round && d2 > limit2) {
                    continue;
                }
                // Clockwise sweep from 12 o'clock, inner units first within a direction,
                // so progress reads like a dial and is not hidden under the medallion.
                var ang = Math.atan2(i, -j); // 0 at 12 o'clock, clockwise positive
                if (ang < 0) {
                    ang += twoPi;
                }
                var key = (ang / twoPi * 359).toNumber() * 1024 + d2;
                var p = Living.pack(cx + i * cellSize, cy + j * cellSize);
                items.add((key.toLong() << 32) | (p.toLong() & 0xFFFFFFFFl));
            }
        }
        items.sort(null);
        var pts = new Array<Number>[items.size()];
        for (var k = 0; k < items.size(); k++) {
            pts[k] = (items[k] & 0xFFFFFFFFl).toNumber();
        }
        units = pts;
    }

    // Lens (pointed oval) from the centre outwards along angle a.
    static function lensOffsets(a as Float or Double, start as Float or Double, len as Float or Double, width as Float or Double) as Array<Float> {
        var c = Math.cos(a);
        var s = Math.sin(a);
        var out = [] as Array<Float>;
        var steps = 6;
        // upper edge k = 0..steps, lower edge k = steps-1..1
        for (var k = 0; k <= steps; k++) {
            var t = k.toFloat() / steps;
            var x = start + len * t;
            var y = width / 2 * Math.sin(Math.PI * t);
            out.add((x * c - y * s).toFloat());
            out.add((x * s + y * c).toFloat());
        }
        for (var k = steps - 1; k >= 1; k--) {
            var t = k.toFloat() / steps;
            var x = start + len * t;
            var y = -width / 2 * Math.sin(Math.PI * t);
            out.add((x * c - y * s).toFloat());
            out.add((x * s + y * c).toFloat());
        }
        return out;
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

    // One Kawung unit centred at (x, y), drawn as vectors. Used to render the two tiles.
    // Stage of a unit: DORMANT outline, AWAKENING gilded outline, BLOOM filled petals.
    enum {
        DORMANT,
        AWAKENING,
        BLOOM
    }

    function drawUnit(dc as Dc, pal as Array<Number>, x as Number, y as Number, stage as Number) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        dc.setColor(pal[Palette.BG], pal[Palette.BG]);
        dc.clear();
        var seed = (cell * 0.09).toNumber();
        if (seed < 2) {
            seed = 2;
        }
        var isen = (cell * 0.05).toNumber();
        if (isen < 1) {
            isen = 1;
        }
        var half = cell / 2;
        dc.setPenWidth(1);
        if (mono) {
            // Dormant: seed dots only. Awakening: petal outlines. Bloom: outlines + solid inner lens.
            dc.setColor(pal[Palette.SKELETON], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, seed > 2 ? seed - 1 : seed);
            if (stage == DORMANT) {
                return;
            }
            for (var d = 0; d < 4; d++) {
                stroke(dc, place(_outer[d], x, y));
                if (stage == BLOOM) {
                    dc.fillPolygon(place(_inner[d], x, y));
                }
            }
            return;
        }
        if (stage != BLOOM) {
            // Dormant must already read as finished batik: petal, vein and seed lines.
            var awake = stage == AWAKENING;
            for (var d = 0; d < 4; d++) {
                dc.setColor(awake ? pal[Palette.MID] : pal[Palette.SKELETON], Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(awake ? 2 : 1);
                stroke(dc, place(_outer[d], x, y));
                dc.setPenWidth(1);
                dc.setColor(awake ? pal[Palette.LIGHT] : pal[Palette.DARK], Graphics.COLOR_TRANSPARENT);
                stroke(dc, place(_inner[d], x, y));
            }
            dc.setColor(awake ? pal[Palette.ACCENT] : pal[Palette.DARK], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, seed);
            return;
        }
        for (var d = 0; d < 4; d++) {
            dc.setColor(pal[Palette.MID], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(place(_outer[d], x, y));
            dc.setColor(pal[Palette.LIGHT], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(place(_inner[d], x, y));
        }
        dc.setColor(pal[Palette.DARK], Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, seed);
        // isen-isen: half dots on each tile edge; two lit neighbours complete a dot
        dc.setColor(pal[Palette.ACCENT], Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + half, y, isen);
        dc.fillCircle(x - half, y, isen);
        dc.fillCircle(x, y + half, isen);
        dc.fillCircle(x, y - half, isen);
    }

    // Kawung is a periodic tiling, so one lit and one unlit tile are rendered once per
    // colorway/density and then stamped per unit. Keeps redraws under the watchdog limit.
    private var _tiles as Array<Graphics.BufferedBitmapReference?> = [null, null, null] as Array<Graphics.BufferedBitmapReference?>;
    private var _tileKey as Number = -1;

    private function tile(ref as Graphics.BufferedBitmapReference?, pal as Array<Number>, stage as Number, fresh as Boolean) as Graphics.BufferedBitmapReference {
        var r = ref;
        var bmp = r != null ? r.get() as Graphics.BufferedBitmap? : null;
        if (r == null || bmp == null) {
            r = Graphics.createBufferedBitmap({:width => cell, :height => cell});
            bmp = r.get() as Graphics.BufferedBitmap?;
            fresh = true;
        }
        if (fresh && bmp != null) {
            drawUnit(bmp.getDc(), pal, cell / 2, cell / 2, stage);
        }
        return r;
    }

    // Full render of the pattern layer. Called only when the lit count, colorway or
    // density changes; the result is cached in a BufferedBitmap by the view.
    // bloom: units fully in bloom; awake: units at least awakening (awake >= bloom).
    function draw(dc as Dc, pal as Array<Number>, colorway as Number, bloom as Number, awake as Number, complete as Boolean) as Void {
        var key = colorway * 4096 + cell;
        var fresh = key != _tileKey;
        var bmps = [] as Array<Graphics.BufferedBitmap>;
        for (var s = 0; s < 3; s++) {
            var ref = tile(_tiles[s], pal, s, fresh);
            _tiles[s] = ref;
            var b = ref.get() as Graphics.BufferedBitmap?;
            if (b != null) {
                bmps.add(b);
            }
        }
        _tileKey = key;

        dc.setColor(pal[Palette.BG], pal[Palette.BG]);
        dc.clear();
        if (bmps.size() < 3) {
            _tileKey = -1;
            return;
        }
        var half = cell / 2;
        var count = units.size();
        for (var u = 0; u < count; u++) {
            var p = units[u];
            var stage = u < bloom ? BLOOM : (u < awake ? AWAKENING : DORMANT);
            dc.drawBitmap(Living.unpackX(p) - half, Living.unpackY(p) - half, bmps[stage]);
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
                // rectangle and semi-octagon screens: a gold frame instead of a ring
                dc.drawRoundedRectangle(3, 3, _w - 6, _h - 6, r / 4);
                dc.setPenWidth(1);
                dc.drawRoundedRectangle(9, 9, _w - 18, _h - 18, r / 4);
            }
        }
    }
}
