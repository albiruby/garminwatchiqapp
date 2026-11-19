import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! Minimal line icons for the six modules, drawn with primitives (no bitmaps).
//! Each fits a box of size s centred on (x, y).
//!   BREATHE   circular waves  - flow
//!   MIND      concentric rings - stillness
//!   CIRCULATE flowing lines   - circulation
//!   MOBILITY  dynamic lines   - movement
//!   SLEEP     soft crescent   - rest
//!   RECOVER   organic leaf    - restoration
module Icons {

    function draw(dc as Graphics.Dc, cat as Number, x as Number, y as Number, s as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var h = s / 2;
        if (cat == Models.CAT_BREATHE) {
            // Three wind lines, each ending in a curl.
            for (var i = 0; i < 3; i++) {
                var ly = y - h / 2 + i * h / 2;
                var len = (i == 1) ? h : h * 2 / 3;
                dc.drawLine(x - h, ly, x - h + len + h / 3, ly);
                dc.drawArc(x - h + len + h / 3, ly - h / 6, h / 6, Graphics.ARC_COUNTER_CLOCKWISE, 270, 180);
            }
        } else if (cat == Models.CAT_MIND) {
            dc.drawCircle(x, y, h);
            dc.drawCircle(x, y, h * 3 / 5);
            dc.fillCircle(x, y, h / 4);
        } else if (cat == Models.CAT_CIRCULATE) {
            // Two flowing sine lines.
            for (var k = 0; k < 2; k++) {
                var oy = y - h / 3 + k * h * 2 / 3;
                var px = x - h;
                var py = oy;
                for (var j = 1; j <= 12; j++) {
                    var nx = x - h + j * s / 12;
                    var ny = oy + (Math.sin(j * Math.PI / 6 + k) * h / 4).toNumber();
                    dc.drawLine(px, py, nx, ny);
                    px = nx;
                    py = ny;
                }
            }
        } else if (cat == Models.CAT_MOBILITY) {
            // Three diagonal strokes of rising length, plus a dot (a figure in motion).
            for (var m = 0; m < 3; m++) {
                var bx = x - h + m * h * 2 / 3;
                var len2 = h / 2 + m * h / 3;
                dc.drawLine(bx, y + h / 2, bx + len2 / 2, y + h / 2 - len2);
            }
            dc.fillCircle(x + h * 2 / 3, y - h * 2 / 3, s / 10 + 1);
        } else if (cat == Models.CAT_SLEEP) {
            // Crescent: a filled disc with an offset disc cut out.
            dc.fillCircle(x, y, h * 4 / 5);
            dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + h * 2 / 5, y - h / 4, h * 2 / 3);
        } else if (cat == Models.CAT_RECOVER) {
            // Leaf from bottom-left tip to top-right tip: the lens between two
            // circles centred on the other diagonal, plus the midrib.
            var a = h * 3 / 4;
            var c = h * 2 / 5;
            var r = Math.sqrt(2 * a * a + 2 * c * c).toNumber();
            var t = Math.toDegrees(Math.atan2(a + c, a - c)).toNumber();
            dc.drawArc(x + c, y + c, r, Graphics.ARC_COUNTER_CLOCKWISE, t, 270 - t);
            dc.drawArc(x - c, y - c, r, Graphics.ARC_COUNTER_CLOCKWISE, t + 180, (450 - t) % 360);
            dc.drawLine(x - a, y + a, x + a, y - a);
        }
        dc.setPenWidth(1);
    }
}
