import Toybox.Graphics;
import Toybox.Lang;

// Divider — a thin faint horizontal line spanning the safe width at a y.

class Divider {
    static function draw(dc as Dc, sz as SafeZone, y as Number) as Void {
        var half = sz.maxHalfWidthAt(y, 2) - 14;
        if (half < 10) { return; }
        dc.setColor(Colors.arg(ColorKey.DIVIDER), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(sz.cx - half, y, sz.cx + half, y);
    }
}
