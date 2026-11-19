import Toybox.Graphics;
import Toybox.Lang;

//! Sports-watch style HUD primitives: segmented bezel rings, labelled data
//! fields, status line. Inspired by the data-first layouts of modern running
//! watches: hairline dividers, small uppercase labels, big mono numerals.
module Hud {

    const GAP_DEG = 3;

    //! Segmented ring, clockwise from 12 o'clock. weights = relative sizes;
    //! segments before `active` are full (MINT), `active` fills by
    //! permille (0..1000), the rest are SURFACE. Zero weights are skipped.
    function segmentRing(dc as Graphics.Dc, weights as Array, active as Number, permille as Number,
            radius as Number, pen as Number, activeColor as Number) as Void {
        var total = 0;
        for (var i = 0; i < weights.size(); i++) {
            total += weights[i];
        }
        if (total <= 0) {
            return;
        }
        var cx = Theme.cx(dc);
        var cy = Theme.cy(dc);
        dc.setPenWidth(pen);
        var start = 90.0;
        for (var i = 0; i < weights.size(); i++) {
            if (weights[i] <= 0) {
                continue;
            }
            var sweep = 360.0 * weights[i] / total;
            var s = start - GAP_DEG / 2.0;
            var e = start - sweep + GAP_DEG / 2.0;
            if (s - e >= 1) {
                dc.setColor((i < active) ? Theme.MINT : Theme.SURFACE, Graphics.COLOR_TRANSPARENT);
                dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, deg(s), deg(e));
                if (i == active && permille > 0) {
                    var fe = s - (s - e) * permille / 1000.0;
                    if (s - fe >= 1) {
                        dc.setColor(activeColor, Graphics.COLOR_TRANSPARENT);
                        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, deg(s), deg(fe));
                    }
                }
            }
            start -= sweep;
        }
        dc.setPenWidth(1);
    }

    //! Float degrees -> Number in 0..359.
    function deg(d) as Number {
        var n = d.toNumber() % 360;
        return (n < 0) ? n + 360 : n;
    }

    //! Small uppercase label over a value, centred on x.
    function field(dc as Graphics.Dc, x as Number, y as Number, label as String, value as String,
            valueFont, valueColor as Number) as Void {
        Theme.text(dc, x, y, Theme.label(), Theme.GREY, label, Graphics.TEXT_JUSTIFY_CENTER);
        Theme.text(dc, x, y + 19, valueFont, valueColor, value, Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Two fields side by side under a divider, with a vertical hairline.
    function fieldPair(dc as Graphics.Dc, y as Number, l1 as String, v1 as String, l2 as String, v2 as String,
            valueFont, valueColor as Number) as Void {
        var cx = Theme.cx(dc);
        var off = dc.getWidth() * 16 / 100;
        field(dc, cx - off, y, l1, v1, valueFont, valueColor);
        field(dc, cx + off, y, l2, v2, valueFont, valueColor);
        dc.setColor(Theme.LINE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx, y + 2, cx, y + 46);
    }

    //! Top status line: local time, plus a small vibration mark when haptics are on.
    function statusLine(dc as Graphics.Dc, y as Number) as Void {
        var cx = Theme.cx(dc);
        var t = Theme.clock();
        Theme.text(dc, cx, y, Theme.label(), Theme.GREY, t, Graphics.TEXT_JUSTIFY_CENTER);
        if (SettingsRepository.hapticsEnabled()) {
            var x = cx + dc.getTextWidthInPixels(t, Theme.label()) / 2 + 8;
            var my = y + 10;
            dc.setColor(Theme.SAGE, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x, my - 4, x, my + 4);
            dc.drawLine(x + 4, my - 6, x + 4, my + 6);
            dc.drawLine(x + 8, my - 4, x + 8, my + 4);
        }
    }

    //! "m:ss" with leading zero minutes for a steady mono width ("04:32").
    function mmss(seconds as Number) as String {
        if (seconds < 0) {
            seconds = 0;
        }
        return (seconds / 60).format("%02d") + ":" + (seconds % 60).format("%02d");
    }
}
