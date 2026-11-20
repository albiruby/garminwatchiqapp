import Toybox.Graphics;
import Toybox.Lang;

// ScoreDisplay — dominant centered score number. Fitted to the safe width.
// scoreText is e.g. "65" or "--". Rendered in the score color (accent).

class ScoreDisplay {
    static function draw(dc as Dc, sz as SafeZone, scoreText as String, y as Number, color as Number) as Void {
        var font = Typography.score();
        var half = sz.maxHalfWidthAt(y, 56);
        var maxWidth = (half * 2) - 16;
        DynamicText.drawFit(dc, scoreText, font, sz.cx, y, maxWidth, color, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
