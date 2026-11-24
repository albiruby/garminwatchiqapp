import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Dial: analog instrument. Hands over 11 hour indices (6 o'clock is the battery's
// opening), readouts at 9 and 3 o'clock, steps at 6. The goal track keeps its bezel
// ring, scale and needle. Hands follow the look: solid, outlined or slim.
module DialFace {

    function draw(c as Canvas, s as SettingsManager, m as Metrics, g as Goal, hour as Number, min as Number,
                  sec as Number, marker as String) as Void {
        var L = c.L;
        var dc = c.dc as Graphics.Dc;
        var CENTER = Graphics.TEXT_JUSTIFY_CENTER;

        indices(dc, L, ThemeManager.TEXT, ThemeManager.MUTED, true);

        if (s.showDate) {
            c.text("date", L.cx, L.dateY, L.textFont, Readouts.fittedDate(c, L.cx, L.dateY, CENTER, marker), ThemeManager.MUTED, CENTER);
        }

        // readouts at 9 and 3 o'clock: value, unit, goal bar
        var ids = Readouts.visible(m, s, true);
        for (var i = 0; i < ids.size() && i < 2; i++) {
            var x = L.cx + (i == 0 ? -L.sideDX : L.sideDX);
            var r = Readouts.metric(ids[i], m, s);
            var tag = "side" + i;
            c.text(tag + "-value", x, L.sideY, L.valueFont, r[0] as String, r[2] as Number, CENTER);
            if (s.showLabels) {
                c.text(tag + "-label", x, L.sideY + 26, L.labelFont, r[1] as String, ThemeManager.MUTED, CENTER);
            }
            var goal = r[3] as Goal?;
            if (goal != null && goal.hasTarget) {
                c.bar(tag + "-bar", x, L.sideY + 42, 50, LayoutEngine.MINI_BAR_H, goal, s,
                      s.goalStyle == SettingsManager.STYLE_SEGMENTED ? ProgressRenderer.MINI_SEGMENTS : 1);
            }
        }

        c.text("steps", L.cx, L.stepsY, L.stepsFont, g.valid ? FormatUtils.thousands(g.value) : "--",
               g.valid ? ThemeManager.TEXT : ThemeManager.MUTED, CENTER);
        c.line("status", L.cx, L.statusY, Readouts.fittedStatus(c, g, L.cx, L.statusY, CENTER), CENTER);

        // hands move, so they are not part of the layout audit
        var lenH = L.contentR * 55 / 100;
        var lenM = L.contentR * 88 / 100;
        var style = ThemeManager.numerals;
        hand(dc, L.cx, L.cy, hourAngle(hour, min), lenH, 14, style == ThemeManager.NUM_LIGHT ? 7 : 11, ThemeManager.TEXT, style);
        hand(dc, L.cx, L.cy, 90.0 - min * 6.0, lenM, 16, style == ThemeManager.NUM_LIGHT ? 5 : 8, ThemeManager.TEXT, style);
        if (s.showSeconds && sec >= 0) {
            var a = Math.toRadians(90.0 - sec * 6.0);
            dc.setPenWidth(2);
            dc.setColor(ThemeManager.textAccent(g.state), ThemeManager.BLACK);
            dc.drawLine(L.cx - (20 * Math.cos(a)).toNumber(), L.cy + (20 * Math.sin(a)).toNumber(),
                        L.cx + ((lenM + 8) * Math.cos(a)).toNumber(), L.cy - ((lenM + 8) * Math.sin(a)).toNumber());
        }
        // centre cap in the accent
        dc.setColor(ThemeManager.accent(), ThemeManager.BLACK);
        dc.fillCircle(L.cx, L.cy, 7);
        dc.setColor(ThemeManager.BLACK, ThemeManager.BLACK);
        dc.fillCircle(L.cx, L.cy, 3);
    }

    function hourAngle(hour as Number, min as Number) as Float {
        return 90.0 - ((hour % 12) + min / 60.0) * 30.0;
    }

    // Hour indices; quarters are longer. all = false keeps only 12, 3 and 9 (always-on).
    function indices(dc as Graphics.Dc, L as LayoutEngine, quarter as Number, other as Number, all as Boolean) as Void {
        for (var h = 0; h < 12; h++) {
            var q = h % 3 == 0;
            if (h == 6 || (!all && !q)) {
                continue;
            }
            var a = Math.toRadians(90.0 - h * 30.0);
            var r1 = L.contentR - 2;
            var r0 = r1 - (q ? 15 : 8);
            dc.setPenWidth(q ? 4 : 2);
            dc.setColor(q ? quarter : other, ThemeManager.BLACK);
            dc.drawLine(L.cx + (r0 * Math.cos(a)).toNumber(), L.cy - (r0 * Math.sin(a)).toNumber(),
                        L.cx + (r1 * Math.cos(a)).toNumber(), L.cy - (r1 * Math.sin(a)).toNumber());
        }
    }

    // Tapered hand with a short tail. Outline style draws the edge only.
    function hand(dc as Graphics.Dc, cx as Number, cy as Number, deg as Float, len as Number, tail as Number,
                  w as Number, color as Number, style as Number) as Void {
        var a = Math.toRadians(deg);
        var dx = Math.cos(a);
        var dy = -Math.sin(a);
        var px = -dy;   // perpendicular
        var py = dx;
        var pts = [
            [(cx - dx * tail).toNumber(), (cy - dy * tail).toNumber()],
            [(cx + px * w / 2).toNumber(), (cy + py * w / 2).toNumber()],
            [(cx + dx * len + px * w / 4).toNumber(), (cy + dy * len + py * w / 4).toNumber()],
            [(cx + dx * len - px * w / 4).toNumber(), (cy + dy * len - py * w / 4).toNumber()],
            [(cx - px * w / 2).toNumber(), (cy - py * w / 2).toNumber()]
        ];
        dc.setColor(color, ThemeManager.BLACK);
        if (style == ThemeManager.NUM_OUTLINE) {
            dc.setPenWidth(2);
            for (var i = 0; i < pts.size(); i++) {
                var p = pts[i] as Array<Number>;
                var q = pts[(i + 1) % pts.size()] as Array<Number>;
                dc.drawLine(p[0], p[1], q[0], q[1]);
            }
        } else {
            dc.fillPolygon(pts);
        }
    }

    // Always-on: three indices, outlined hands, thin progress line; shifted for burn-in.
    function aod(dc as Graphics.Dc, L as LayoutEngine, s as SettingsManager, hour as Number, min as Number,
                 g as Goal, dx as Number, dy as Number) as Void {
        indices(dc, L, PowerManager.AOD_TEXT, PowerManager.AOD_TEXT, false);
        hand(dc, L.cx + dx, L.cy + dy, hourAngle(hour, min), L.contentR * 55 / 100, 10, 9, PowerManager.AOD_TIME, ThemeManager.NUM_OUTLINE);
        hand(dc, L.cx + dx, L.cy + dy, 90.0 - min * 6.0, L.contentR * 88 / 100, 12, 7, PowerManager.AOD_TIME, ThemeManager.NUM_OUTLINE);
        if (s.aodStyle == 0 && g.hasTarget) {
            dc.setPenWidth(2);
            dc.setColor(ThemeManager.accentDim(), ThemeManager.BLACK);
            ProgressRenderer.arc(dc, L.cx + dx, L.cy + dy, L.ringR, 240.0,
                                 ProgressRenderer.angleAt(ActivityGoalEngine.trackFraction(g)));
        }
        dc.setPenWidth(1);
    }
}
