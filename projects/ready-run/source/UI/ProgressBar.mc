import Toybox.Graphics;
import Toybox.Lang;

// ProgressBar — horizontal bar. value/max -> fill fraction. LABEL and VALUE
// are drawn on one line above the bar by the caller (MetricRow-like); this
// component only draws the bar itself so spacing never collides.

class ProgressBar {
    // Draw a bar with top-left at (x, y), given width/height. pct 0..100.
    static function draw(dc as Dc, x as Number, y as Number, w as Number, h as Number, pct as Number, fgColor as Number, bgColor as Number) as Void {
        if (w <= 0 || h <= 0) { return; }
        var p = pct;
        if (p < 0) { p = 0; }
        if (p > 100) { p = 100; }
        var fill = ((w * p) / 100.0).toNumber();
        if (fill < 1 && p > 0) { fill = 1; }
        // Track.
        dc.setColor(bgColor, bgColor);
        dc.fillRoundedRectangle(x, y, w, h, h / 2);
        // Fill.
        if (fill > 0) {
            dc.setColor(fgColor, fgColor);
            dc.fillRoundedRectangle(x, y, fill, h, h / 2);
        }
    }
}
