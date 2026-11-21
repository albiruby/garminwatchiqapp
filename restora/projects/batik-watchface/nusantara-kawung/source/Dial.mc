import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Hands and the small single-flower ornament shared by active and AOD modes.
module Dial {

    // Tapered hand: angle in radians clockwise from 12 o'clock.
    function handPoints(cx as Number, cy as Number, angle as Float or Double, len as Float or Double, w as Float or Double, tail as Float or Double) as Array<[Numeric, Numeric]> {
        var shape = [
            -w, tail,
            -w * 0.7, -len * 0.82,
            0, -len,
            w * 0.7, -len * 0.82,
            w, tail
        ];
        var c = Math.cos(angle);
        var s = Math.sin(angle);
        var pts = [] as Array<[Numeric, Numeric]>;
        for (var i = 0; i < shape.size(); i += 2) {
            var x = shape[i];
            var y = shape[i + 1];
            pts.add([cx + x * c - y * s, cy + x * s + y * c]);
        }
        return pts;
    }

    function drawHands(dc as Dc, pal as Array<Number>, cx as Number, cy as Number, r as Number, hour as Number, min as Number) as Void {
        var hAng = ((hour % 12) + min / 60.0) * Math.PI / 6;
        var mAng = min * Math.PI / 30;
        var hw = r * 0.050;
        var mw = r * 0.026;
        var hl = r * 0.42;   // hour: short and broad
        var ml = r * 0.58;   // minute: stops short of the top and bottom plaques

        // dark halo keeps hands legible over lit petals
        dc.setColor(pal[Palette.BG], Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(handPoints(cx, cy, hAng, hl + 3, hw + 3, r * 0.10));
        dc.fillPolygon(handPoints(cx, cy, mAng, ml + 3, mw + 3, r * 0.12));

        dc.setColor(pal[Palette.MID], Graphics.COLOR_TRANSPARENT);   // hour darker than minute
        dc.fillPolygon(handPoints(cx, cy, hAng, hl, hw, r * 0.08));
        dc.setColor(pal[Palette.LIGHT], Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(handPoints(cx, cy, mAng, ml, mw, r * 0.10));

        dc.setColor(pal[Palette.DARK], Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (r * 0.045).toNumber());
        dc.setColor(pal[Palette.LIGHT], Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (r * 0.018).toNumber());
    }

    // One Kawung flower as outlines only (cheap in lit pixels, used in AOD).
    function flowerOutline(dc as Dc, x as Number, y as Number, size as Number) as Void {
        for (var d = 0; d < 4; d++) {
            var a = Math.PI / 4 + d * Math.PI / 2;
            var offs = PatternEngine.lensOffsets(a, size * 0.07, size * 0.64, size * 0.32);
            PatternEngine.stroke(dc, PatternEngine.place(offs, x, y));
        }
    }
}
