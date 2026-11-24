import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! Success check: the circle sweeps in (0..60% of progress), then the check
//! mark is stroked (60..100%). progress = 1.0 draws the finished badge, which
//! is also what reduced motion shows.
module CompletionAnimation {

    const DURATION_MS = 450;

    function draw(dc as Graphics.Dc, x as Number, y as Number, s as Number, color as Number, progress) as Void {
        var h = s / 2.0;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        var ring = Easing.clamp01(progress / 0.6);
        if (ring >= 1.0) {
            dc.drawCircle(x, y, h.toNumber());
        } else if (ring > 0.02) {
            dc.drawArc(x, y, h.toNumber(), Graphics.ARC_CLOCKWISE, 90, Hud.deg(90 - 360 * ring));
        }
        var tick = Easing.clamp01((progress - 0.6) / 0.4);
        if (tick > 0) {
            // two strokes: short down-stroke then long up-stroke
            var x0 = x - h * 0.42;
            var y0 = y + h * 0.02;
            var x1 = x - h * 0.10;
            var y1 = y + h * 0.34;
            var x2 = x + h * 0.45;
            var y2 = y - h * 0.30;
            var first = Easing.clamp01(tick / 0.35);
            dc.drawLine(x0.toNumber(), y0.toNumber(), (x0 + (x1 - x0) * first).toNumber(), (y0 + (y1 - y0) * first).toNumber());
            if (tick > 0.35) {
                var second = (tick - 0.35) / 0.65;
                dc.drawLine(x1.toNumber(), y1.toNumber(), (x1 + (x2 - x1) * second).toNumber(), (y1 + (y2 - y1) * second).toNumber());
            }
        }
        dc.setPenWidth(1);
    }
}
