import Toybox.Graphics;
import Toybox.Lang;

// StatusDisplay — centered status word (semantic color) under a score/header.
// Fitted to safe width so long states (UNPRODUCTIVE, OVERREACHING) never clip.

class StatusDisplay {
    static function draw(dc as Dc, sz as SafeZone, statusText as String, y as Number, colorKey as Number) as Void {
        var res = fitText(dc, sz, statusText, y);
        dc.setColor(Colors.arg(colorKey), Graphics.COLOR_TRANSPARENT);
        dc.drawText(sz.cx, y, res[0], res[1], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Exposes the fitted font/text/dimensions so callers can stack content
    // below the status with measured (never assumed) spacing.
    static function fitText(dc as Dc, sz as SafeZone, statusText as String, y as Number) as Array {
        var font = Typography.status();
        var half = sz.maxHalfWidthAt(y, 26);
        var maxWidth = (half * 2) - 16;
        return DynamicText.fit(dc, statusText, font, maxWidth);
    }
}
