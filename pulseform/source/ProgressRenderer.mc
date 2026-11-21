import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// GOAL TRACK drawing. Geometry is exact: the filled sweep is ratio x 300 deg, segments
// light only when fully earned, and overshoot is a separate inner lap. The instrument
// details (10 % scale, needle at the exact position) are part of the face's identity.
module ProgressRenderer {

    const SEGMENTS = 10;
    const MINI_SEGMENTS = 5;

    // Angle (deg, CCW from 3 o'clock) at a fraction of the track.
    function angleAt(frac as Float) as Float {
        return 240.0 - frac * 300.0;
    }

    // Main ring for circular and segmented styles.
    function ring(dc as Graphics.Dc, L as LayoutEngine, g as Goal, s as SettingsManager) as Void {
        var accent = ThemeManager.progressColor(g.state);
        dc.setPenWidth(L.ringW);
        if (s.goalStyle == SettingsManager.STYLE_SEGMENTED) {
            var filled = ActivityGoalEngine.filledSegments(g, SEGMENTS);
            var span = 300.0 / SEGMENTS;
            var gap = 3.0;
            for (var i = 0; i < SEGMENTS; i++) {
                var a0 = 240.0 - i * span - gap / 2;
                dc.setColor(i < filled ? accent : ThemeManager.TRACK, ThemeManager.BLACK);
                arc(dc, L.cx, L.cy, L.ringR, a0, a0 - (span - gap));
            }
        } else {
            dc.setColor(ThemeManager.TRACK, ThemeManager.BLACK);
            arc(dc, L.cx, L.cy, L.ringR, 240.0, -60.0);
            var frac = ActivityGoalEngine.trackFraction(g);
            if (frac > 0.0) {
                dc.setColor(accent, ThemeManager.BLACK);
                arc(dc, L.cx, L.cy, L.ringR, 240.0, angleAt(frac));
            }
            scale(dc, L);
        }
        targetMarker(dc, L, g, s);
        lap(dc, L, g, s);
        needle(dc, L, g);
        dc.setPenWidth(1);
    }

    // 10 % ruler just inside the track, drawn in the look's style:
    // ticks (Carbon), dots (Reflective, Field) or heavy ticks (Signal). 50 % is marked.
    function scale(dc as Graphics.Dc, L as LayoutEngine) as Void {
        var r0 = L.ringR - L.ringW / 2 - 2;
        var st = ThemeManager.scaleStyle;
        for (var i = 1; i < 10; i++) {
            var half = i == 5;
            dc.setColor(half ? ThemeManager.MUTED : ThemeManager.FAINT, ThemeManager.BLACK);
            if (st == ThemeManager.SCALE_DOTS) {
                var a = Math.toRadians(angleAt(i / 10.0));
                var rr = r0 - 3;
                dc.fillCircle(L.cx + (rr * Math.cos(a)).toNumber(), L.cy - (rr * Math.sin(a)).toNumber(), half ? 3 : 2);
            } else if (st == ThemeManager.SCALE_HEAVY) {
                dc.setPenWidth(half ? 4 : 3);
                radial(dc, L, angleAt(i / 10.0), r0 - (half ? 9 : 6), r0);
            } else {
                dc.setPenWidth(half ? 2 : 1);
                radial(dc, L, angleAt(i / 10.0), r0 - (half ? 7 : 3), r0);
            }
        }
    }

    // White cursor across the track at the exact progress; hidden once the goal is met
    // (the completion dot takes over) and when there is no target.
    function needle(dc as Graphics.Dc, L as LayoutEngine, g as Goal) as Void {
        if (!g.hasTarget || g.percent >= 100) {
            return;
        }
        var deg = angleAt(ActivityGoalEngine.trackFraction(g));
        var inner = L.ringR - L.ringW / 2;
        var outer = L.ringR + L.ringW / 2;
        if (outer > L.r - 2) {
            outer = L.r - 2;
        }
        dc.setColor(ThemeManager.TEXT, ThemeManager.BLACK);
        var st = ThemeManager.needleStyle;
        if (st == ThemeManager.NEEDLE_CHEVRON) {
            // arrowhead on the inner edge, pointing at the track
            var a = Math.toRadians(deg);
            var t = Math.toRadians(deg + 90.0);
            var tipR = inner - 1;
            var baseR = inner - 11;
            var tip = [L.cx + (tipR * Math.cos(a)).toNumber(), L.cy - (tipR * Math.sin(a)).toNumber()];
            var bx = L.cx + baseR * Math.cos(a);
            var by = L.cy - baseR * Math.sin(a);
            dc.fillPolygon([tip,
                [(bx + 6 * Math.cos(t)).toNumber(), (by - 6 * Math.sin(t)).toNumber()],
                [(bx - 6 * Math.cos(t)).toNumber(), (by + 6 * Math.sin(t)).toNumber()]]);
        } else if (st == ThemeManager.NEEDLE_DOT) {
            var a = Math.toRadians(deg);
            dc.fillCircle(L.cx + (L.ringR * Math.cos(a)).toNumber(), L.cy - (L.ringR * Math.sin(a)).toNumber(), L.ringW / 2 + 3);
            dc.setColor(ThemeManager.BLACK, ThemeManager.BLACK);
            dc.fillCircle(L.cx + (L.ringR * Math.cos(a)).toNumber(), L.cy - (L.ringR * Math.sin(a)).toNumber(), 2);
        } else if (st == ThemeManager.NEEDLE_BLOCK) {
            dc.setPenWidth(7);
            radial(dc, L, deg, inner - 4, outer);
        } else {
            dc.setPenWidth(3);
            radial(dc, L, deg, inner - 6, outer);
        }
    }

    // Small tick where 100 % lands; becomes a filled accent dot once the goal is met.
    function targetMarker(dc as Graphics.Dc, L as LayoutEngine, g as Goal, s as SettingsManager) as Void {
        if (!g.hasTarget) {
            return;
        }
        if (g.percent >= 100) {
            var a = Math.toRadians(-60.0);
            var x = L.cx + (L.ringR * Math.cos(a)).toNumber();
            var y = L.cy - (L.ringR * Math.sin(a)).toNumber();
            var dr = L.ringW / 2 + 3;
            dc.setColor(ThemeManager.accent(), ThemeManager.BLACK);
            dc.fillCircle(x, y, dr);
            dc.setColor(ThemeManager.BLACK, ThemeManager.BLACK);
            dc.fillCircle(x, y, dr / 3);
        } else {
            dc.setPenWidth(2);
            dc.setColor(ThemeManager.MUTED, ThemeManager.BLACK);
            radial(dc, L, -60.0, L.ringR - L.ringW / 2 - 4, L.ringR + L.ringW / 2 + 2);
        }
    }

    function lap(dc as Graphics.Dc, L as LayoutEngine, g as Goal, s as SettingsManager) as Void {
        var lf = ActivityGoalEngine.lapFraction(g);
        if (lf <= 0.0) {
            return;
        }
        dc.setPenWidth(L.lapW);
        dc.setColor(ThemeManager.lapColor(), ThemeManager.BLACK);
        arc(dc, L.cx, L.cy, L.lapR, 240.0, angleAt(lf));
    }

    // Vertical gauge on the spine (linear style): fills bottom to top, overshoot lap runs
    // up its centre.
    function gauge(dc as Graphics.Dc, x as Number, top as Number, bottom as Number, w as Number,
                   g as Goal, s as SettingsManager) as Void {
        var hgt = bottom - top;
        var left = x - w / 2;
        dc.setColor(ThemeManager.TRACK, ThemeManager.BLACK);
        dc.fillRectangle(left, top, w, hgt);
        var fh = (ActivityGoalEngine.trackFraction(g) * hgt).toNumber();
        if (fh > 0) {
            dc.setColor(ThemeManager.progressColor(g.state), ThemeManager.BLACK);
            dc.fillRectangle(left, bottom - fh, w, fh);
        }
        dc.setColor(ThemeManager.BLACK, ThemeManager.BLACK);
        for (var q = 1; q < 10; q++) {
            dc.fillRectangle(left, bottom - hgt * q / 10, w, q == 5 ? 2 : 1);
        }
        var lh = (ActivityGoalEngine.lapFraction(g) * hgt).toNumber();
        if (lh > 0) {
            var lw = w / 3 < 2 ? 2 : w / 3;
            dc.setColor(ThemeManager.lapColor(), ThemeManager.BLACK);
            dc.fillRectangle(x - lw / 2, bottom - lh, lw, lh);
        }
    }

    // Horizontal bar, centred on x; overshoot lap runs along its centre line.
    function bar(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number, g as Goal,
                 s as SettingsManager, segments as Number) as Void {
        var left = x - w / 2;
        var top = y - h / 2;
        var accent = ThemeManager.progressColor(g.state);
        if (segments > 1) {
            var gap = 3;
            var sw = (w - gap * (segments - 1)) / segments;
            var filled = ActivityGoalEngine.filledSegments(g, segments);
            for (var i = 0; i < segments; i++) {
                dc.setColor(i < filled ? accent : ThemeManager.TRACK, ThemeManager.BLACK);
                dc.fillRectangle(left + i * (sw + gap), top, sw, h);
            }
        } else {
            dc.setColor(ThemeManager.TRACK, ThemeManager.BLACK);
            dc.fillRectangle(left, top, w, h);
            var fw = (ActivityGoalEngine.trackFraction(g) * w).toNumber();
            if (fw > 0) {
                dc.setColor(accent, ThemeManager.BLACK);
                dc.fillRectangle(left, top, fw, h);
            }
        }
        var lw = (ActivityGoalEngine.lapFraction(g) * w).toNumber();
        if (lw > 0 && h >= 6) {
            var lh = h / 3;
            dc.setColor(ThemeManager.lapColor(), ThemeManager.BLACK);
            dc.fillRectangle(left, y - lh / 2, lw, lh);
        }
    }

    function radial(dc as Graphics.Dc, L as LayoutEngine, deg as Float, r0 as Number, r1 as Number) as Void {
        var a = Math.toRadians(deg);
        var c = Math.cos(a);
        var sn = Math.sin(a);
        dc.drawLine(L.cx + (r0 * c).toNumber(), L.cy - (r0 * sn).toNumber(),
                    L.cx + (r1 * c).toNumber(), L.cy - (r1 * sn).toNumber());
    }

    // Clockwise arc from a0 to a1 (degrees); skips sweeps under half a degree, which
    // drawArc would otherwise render as a full circle.
    function arc(dc as Graphics.Dc, x as Number, y as Number, r as Number, a0 as Float, a1 as Float) as Void {
        if (a0 - a1 < 0.5) {
            return;
        }
        var s = norm(Math.round(a0).toNumber());
        var e = norm(Math.round(a1).toNumber());
        if (s == e) {
            e = norm(e - 1);
        }
        dc.drawArc(x, y, r, Graphics.ARC_CLOCKWISE, s, e);
    }

    function norm(d as Number) as Number {
        return ((d % 360) + 360) % 360;
    }
}
