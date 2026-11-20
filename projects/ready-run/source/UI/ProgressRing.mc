import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// ProgressRing — native Dc.drawArc only (no images). Draws a faint track plus
// a foreground arc for `score` (0..100). Thickness approximated by a few
// adjacent-radius arcs to keep draw calls minimal. Radius stays inside safe zone.

class ProgressRing {
    // Draw a ring centered at (cx, cy). pct 0..100, color ARGB, track ARGB.
    static function draw(dc as Dc, cx as Number, cy as Number, radius as Number, pct as Number, color as Number, trackColor as Number, thickness as Number) as Void {
        if (radius <= 0) { return; }
        var start = -90;  // 12 o'clock
        var sweep = ((pct * 360) / 100).toNumber();
        if (sweep > 359) { sweep = 359; }
        if (sweep < 0) { sweep = 0; }
        var end = start + sweep;

        // Track (full circle) in faint color.
        dc.setColor(trackColor, Graphics.COLOR_TRANSPARENT);
        _arcThick(dc, cx, cy, radius, start, start + 359, thickness);

        // Foreground progress arc.
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (sweep >= 1.0) {
            _arcThick(dc, cx, cy, radius, start, end, thickness);
        }
    }

    // Approximate thickness by drawing 1..N concentric arcs around `radius`.
    static function _arcThick(dc as Dc, cx as Number, cy as Number, radius as Number, degStart as Number, degEnd as Number, thickness as Number) as Void {
        var half = thickness / 2;
        var i;
        var r;
        if (thickness <= 2) {
            dc.setPenWidth(thickness < 1 ? 1 : thickness);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, degStart, degEnd);
            return;
        }
        dc.setPenWidth(1);
        for (i = -half; i <= half; i++) {
            r = radius + i;
            if (r > 1) {
                dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, degStart, degEnd);
            }
        }
    }
}
