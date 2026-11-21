import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! Minimal line icons drawn with primitives (no bitmaps). Each fits a box of
//! size s centred on (x, y). Module ids 0..5 match Models.CAT_*.
module Icons {

    const PLAY = 10;
    const HISTORY = 11;
    const SETTINGS = 12;
    const LUNGS = 20;
    const CLOCK = 21;
    const HEART = 22;
    const CHECK = 23;
    const CHEVRON = 24;
    const UP = 25;
    const DOWN = 26;

    function draw(dc as Graphics.Dc, id as Number, x as Number, y as Number, s as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var h = s / 2.0;
        if (id == Models.CAT_BREATHE) {
            // Wind lines ending in curls.
            for (var i = 0; i < 3; i++) {
                var ly = y - h / 2 + i * h / 2;
                var len = (i == 1) ? h : h * 2 / 3;
                line(dc, x - h, ly, x - h + len + h / 3, ly);
                dc.drawArc(n(x - h + len + h / 3), n(ly - h / 6), n(h / 6), Graphics.ARC_COUNTER_CLOCKWISE, 270, 180);
            }
        } else if (id == Models.CAT_MIND) {
            dc.drawCircle(x, y, n(h));
            dc.drawCircle(x, y, n(h * 3 / 5));
            dc.fillCircle(x, y, n(h / 4));
        } else if (id == Models.CAT_CIRCULATE) {
            // Three flowing waves.
            for (var k = 0; k < 3; k++) {
                var oy = y - h / 2 + k * h / 2;
                var px = x - h;
                var py = oy;
                for (var j = 1; j <= 12; j++) {
                    var nx = x - h + j * s / 12.0;
                    var ny = oy + Math.sin(j * Math.PI / 6) * h / 5;
                    line(dc, px, py, nx, ny);
                    px = nx;
                    py = ny;
                }
            }
        } else if (id == Models.CAT_MOBILITY) {
            // Running figure.
            dc.fillCircle(n(x + h * 0.3), n(y - h * 0.72), n(h * 0.2));
            line(dc, x + h * 0.15, y - h * 0.42, x - h * 0.1, y + h * 0.1);
            poly(dc, [[x - h * 0.55, y - h * 0.15], [x, y - h * 0.38], [x + h * 0.55, y - h * 0.1]]);
            poly(dc, [[x - h * 0.1, y + h * 0.1], [x + h * 0.35, y + h * 0.42], [x + h * 0.3, y + h * 0.95]]);
            poly(dc, [[x - h * 0.1, y + h * 0.1], [x - h * 0.35, y + h * 0.5], [x - h * 0.85, y + h * 0.55]]);
        } else if (id == Models.CAT_SLEEP) {
            dc.fillCircle(x, y, n(h * 4 / 5));
            dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(n(x + h * 2 / 5), n(y - h / 4), n(h * 2 / 3));
        } else if (id == Models.CAT_RECOVER) {
            // Leaf: lens between two circles on the other diagonal, plus midrib.
            var a = h * 3 / 4;
            var c = h * 2 / 5;
            var r = Math.sqrt(2 * a * a + 2 * c * c);
            var t = Math.toDegrees(Math.atan2(a + c, a - c)).toNumber();
            dc.drawArc(n(x + c), n(y + c), n(r), Graphics.ARC_COUNTER_CLOCKWISE, t, 270 - t);
            dc.drawArc(n(x - c), n(y - c), n(r), Graphics.ARC_COUNTER_CLOCKWISE, t + 180, (450 - t) % 360);
            line(dc, x - a, y + a, x + a, y - a);
        } else if (id == PLAY) {
            dc.fillPolygon([[n(x - h / 2), n(y - h * 2 / 3)], [n(x + h * 2 / 3), y], [n(x - h / 2), n(y + h * 2 / 3)]]);
        } else if (id == HISTORY) {
            var bw = n(s / 6.0);
            var hs = [h / 2, h, h * 3 / 4, h * 3 / 2];
            for (var b = 0; b < 4; b++) {
                dc.fillRectangle(n(x - h + b * (bw + 2)), n(y + h * 3 / 4 - hs[b]), bw, n(hs[b]));
            }
        } else if (id == SETTINGS) {
            dc.drawCircle(x, y, n(h * 2 / 3));
            dc.fillCircle(x, y, n(h / 4));
            line(dc, x - h, y, x - h * 2 / 3, y);
            line(dc, x + h * 2 / 3, y, x + h, y);
            line(dc, x, y - h, x, y - h * 2 / 3);
            line(dc, x, y + h * 2 / 3, x, y + h);
        } else if (id == LUNGS) {
            line(dc, x, y - h, x, y - h * 0.25);
            poly(dc, [[x - h * 0.35, y], [x, y - h * 0.3], [x + h * 0.35, y]]);
            dc.drawEllipse(n(x - h * 0.55), n(y + h * 0.2), n(h * 0.4), n(h * 0.72));
            dc.drawEllipse(n(x + h * 0.55), n(y + h * 0.2), n(h * 0.4), n(h * 0.72));
        } else if (id == CLOCK) {
            dc.drawCircle(x, y, n(h));
            poly(dc, [[x, y - h * 0.6], [x, y], [x + h * 0.45, y + h * 0.3]]);
        } else if (id == HEART) {
            // Parametric heart outline.
            var pts = [];
            for (var j = 0; j <= 24; j++) {
                var t2 = j * Math.PI * 2 / 24;
                var st = Math.sin(t2);
                pts.add([x + h * st * st * st,
                    y - h * 0.06 * (13 * Math.cos(t2) - 5 * Math.cos(2 * t2) - 2 * Math.cos(3 * t2) - Math.cos(4 * t2)) - h * 0.1]);
            }
            poly(dc, pts);
        } else if (id == CHECK) {
            dc.setPenWidth(3);
            dc.drawCircle(x, y, n(h));
            poly(dc, [[x - h * 0.42, y + h * 0.02], [x - h * 0.1, y + h * 0.34], [x + h * 0.45, y - h * 0.3]]);
        } else if (id == CHEVRON) {
            poly(dc, [[x - h * 0.3, y - h], [x + h * 0.3, y], [x - h * 0.3, y + h]]);
        } else if (id == UP) {
            dc.fillPolygon([[x, n(y - h)], [n(x + h), n(y + h * 0.8)], [n(x - h), n(y + h * 0.8)]]);
        } else if (id == DOWN) {
            dc.fillPolygon([[x, n(y + h)], [n(x + h), n(y - h * 0.8)], [n(x - h), n(y - h * 0.8)]]);
        }
        dc.setPenWidth(1);
    }

    function n(v) as Number {
        return Math.round(v).toNumber();
    }

    function line(dc as Graphics.Dc, x0, y0, x1, y1) as Void {
        dc.drawLine(n(x0), n(y0), n(x1), n(y1));
    }

    function poly(dc as Graphics.Dc, pts as Array) as Void {
        for (var i = 1; i < pts.size(); i++) {
            line(dc, pts[i - 1][0], pts[i - 1][1], pts[i][0], pts[i][1]);
        }
    }
}
