import Toybox.Graphics;
import Toybox.Lang;

// RecommendationDisplay — TODAY screen focus. Category label (small), the
// recommendation as the visual centerpiece, and an action pill (READY /
// CAUTION / RECOVERY) drawn as a rounded capsule with its semantic color.

class RecommendationDisplay {
    // Draw the action pill (rounded capsule) centered at (cx, y).
    static function drawPill(dc as Dc, cx as Number, y as Number, text as String, colorKey as Number) as Void {
        var font = Typography.value();
        var dims = dc.getTextDimensions(text, font);
        var padX = 16;
        var pillW = dims[0] + padX * 2;
        var pillH = dims[1] + 10;
        var x = cx - (pillW / 2);
        var py = y - (pillH / 2);
        var color = Colors.arg(colorKey);

        // Capsule outline + faint fill.
        dc.setPenWidth(2);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, py, pillW, pillH, pillH / 2);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        // Label.
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
