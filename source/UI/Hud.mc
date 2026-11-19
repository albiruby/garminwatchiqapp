import Toybox.Graphics;
import Toybox.Lang;

//! Sports-watch style HUD primitives: segmented bezel rings, labelled data
//! fields, haptic mark. All sizes are 390-px design units (Theme.px).
module Hud {

    const GAP_DEG = 3;
    const BEZEL_R = 190;   // step ring radius, pen 6 -> 187..193
    const PHASE_R = 177;   // breathing ring radius, pen 8 -> 173..181

    //! Float degrees -> Number in 0..359.
    function deg(d) as Number {
        var n = d.toNumber() % 360;
        return (n < 0) ? n + 360 : n;
    }

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
        var r = Theme.px(dc, radius);
        dc.setPenWidth(Theme.px(dc, pen));
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

    //! Small uppercase label (y) over a value (valueY), centred on x.
    function field(dc as Graphics.Dc, x as Number, y as Number, valueY as Number, label as String,
            value as String, valueFont, valueColor as Number) as Void {
        Theme.text(dc, x, y, Theme.label(), Theme.GREY, label, Graphics.TEXT_JUSTIFY_CENTER);
        Theme.text(dc, x, valueY, valueFont, valueColor, value, Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Two fields at cx -/+ off with a hairline between them (390-px units).
    function fieldPair(dc as Graphics.Dc, y as Number, valueY as Number, off as Number,
            l1 as String, v1 as String, l2 as String, v2 as String, valueFont) as Void {
        var cx = Theme.cx(dc);
        var o = Theme.px(dc, off);
        field(dc, cx - o, Theme.px(dc, y), Theme.px(dc, valueY), l1, v1, valueFont, Theme.IVORY);
        field(dc, cx + o, Theme.px(dc, y), Theme.px(dc, valueY), l2, v2, valueFont, Theme.IVORY);
        dc.setColor(Theme.LINE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx, Theme.px(dc, y + 4), cx, Theme.px(dc, valueY + 24));
    }

    //! Tiny vibration mark (three bars) centred at (x, y) when haptics are on.
    function hapticMark(dc as Graphics.Dc, y as Number) as Void {
        if (!SettingsRepository.hapticsEnabled()) {
            return;
        }
        var x = Theme.cx(dc);
        var yy = Theme.px(dc, y);
        dc.setColor(Theme.SAGE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x - 4, yy - 3, x - 4, yy + 4);
        dc.drawLine(x, yy - 5, x, yy + 6);
        dc.drawLine(x + 4, yy - 3, x + 4, yy + 4);
    }

    //! "mm:ss" with leading zero minutes for a steady mono width ("04:32").
    function mmss(seconds as Number) as String {
        if (seconds < 0) {
            seconds = 0;
        }
        return (seconds / 60).format("%02d") + ":" + (seconds % 60).format("%02d");
    }
}
