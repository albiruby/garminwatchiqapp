import Toybox.Graphics;
import Toybox.Lang;

// ScreenHeader — small centered uppercase title inside the safe zone.

class ScreenHeader {
    static function draw(dc as Dc, sz as SafeZone, title as String, y as Number) as Void {
        var font = Typography.title();
        var half = sz.maxHalfWidthAt(y, 20);
        var maxWidth = (half * 2) - 12;
        DynamicText.drawFit(dc, title.toUpper(), font, sz.cx, y, maxWidth, Colors.arg(ColorKey.SECONDARY), Graphics.TEXT_JUSTIFY_CENTER);
    }
}
