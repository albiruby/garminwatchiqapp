import Toybox.Graphics;
import Toybox.Lang;

//! Sports-watch HUD primitives: segmented progress ring, segmented bar.
//! Sizes are 390-px design units (Theme.px).
module Hud {

    const RING_CY = 186;   // ring centre y
    const RING_R = 88;     // radius; pen 8 -> 84..92
    const RING_PEN = 8;
    const GAP_DEG = 2;     // per side, between segments

    //! Float degrees -> Number in 0..359.
    function deg(d) as Number {
        var v = d.toNumber() % 360;
        return (v < 0) ? v + 360 : v;
    }

    //! Segmented ring around (cx, cy), clockwise from 12 o'clock.
    //! weights = relative segment sizes (zeros skipped). Segments before
    //! `active` are GREEN, `active` fills by permille in activeColor, the rest
    //! show the TRACK colour. A single weight draws one continuous ring.
    function segmentRing(dc as Graphics.Dc, cy as Number, weights as Array, active as Number, permille as Number,
            radius as Number, pen as Number, activeColor as Number) as Void {
        var cx = Theme.cx(dc);
        var r = Theme.px(dc, radius);
        dc.setPenWidth(Theme.px(dc, pen));
        var total = 0;
        var count = 0;
        for (var i = 0; i < weights.size(); i++) {
            if (weights[i] > 0) {
                total += weights[i];
                count++;
            }
        }
        if (total <= 0) {
            dc.setPenWidth(1);
            return;
        }
        if (count == 1) {
            dc.setColor(Theme.TRACK, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, r);
            dc.setColor(activeColor, Graphics.COLOR_TRANSPARENT);
            if (permille >= 1000 || active > 0) {
                dc.drawCircle(cx, cy, r);
            } else if (permille > 0) {
                var end = 90 - 360.0 * permille / 1000;
                if (90 - end >= 1) {
                    dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, deg(end));
                }
            }
            dc.setPenWidth(1);
            return;
        }
        var start = 90.0;
        for (var i = 0; i < weights.size(); i++) {
            if (weights[i] <= 0) {
                continue;
            }
            var sweep = 360.0 * weights[i] / total;
            var s = start - GAP_DEG;
            var e = start - sweep + GAP_DEG;
            if (s - e >= 1) {
                dc.setColor((i < active) ? Theme.GREEN : Theme.TRACK, Graphics.COLOR_TRANSPARENT);
                dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, deg(s), deg(e));
                if (i == active && permille > 0) {
                    var fe = s - (s - e) * permille / 1000.0;
                    if (s - fe >= 1) {
                        dc.setColor(activeColor, Graphics.COLOR_TRANSPARENT);
                        dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, deg(s), deg(fe));
                    }
                }
            }
            start -= sweep;
        }
        dc.setPenWidth(1);
    }

    //! Horizontal segmented bar (4 px high, 2 px gaps), one segment per weight.
    function segmentBar(dc as Graphics.Dc, y as Number, half as Number, weights as Array, active as Number,
            permille as Number) as Void {
        var total = 0;
        for (var i = 0; i < weights.size(); i++) {
            total += weights[i];
        }
        if (total <= 0) {
            return;
        }
        var width = 2 * half;
        var hgt = Theme.px(dc, 4);
        var x = Theme.cx(dc) - half;
        for (var i = 0; i < weights.size(); i++) {
            var sw = width * weights[i] / total;
            var seg = sw - 2;
            if (seg > 0) {
                dc.setColor((i < active) ? Theme.GREEN : Theme.TRACK, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, y, seg, hgt);
                if (i == active && permille > 0) {
                    dc.setColor(Theme.GREEN, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle(x, y, seg * permille / 1000, hgt);
                }
            }
            x += sw;
        }
    }

    //! "mm:ss" with leading zero minutes ("04:32").
    function mmss(seconds as Number) as String {
        if (seconds < 0) {
            seconds = 0;
        }
        return (seconds / 60).format("%02d") + ":" + (seconds % 60).format("%02d");
    }

    //! "m:ss" ("9:50").
    function mss(seconds as Number) as String {
        if (seconds < 0) {
            seconds = 0;
        }
        return (seconds / 60).toString() + ":" + (seconds % 60).format("%02d");
    }
}
