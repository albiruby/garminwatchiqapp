import Toybox.Graphics;
import Toybox.Lang;

// SectionLabel — a small left- or center-aligned muted label (Level 2/3 text).

class SectionLabel {
    static function draw(dc as Dc, sz as SafeZone, text as String, y as Number, justify as Number) as Void {
        var font = Typography.label();
        var half = sz.maxHalfWidthAt(y, 16);
        var maxWidth = (half * 2) - 12;
        var x = sz.cx;
        if (justify == Graphics.TEXT_JUSTIFY_LEFT) { x = sz.cx - half + 6; }
        if (justify == Graphics.TEXT_JUSTIFY_RIGHT) { x = sz.cx + half - 6; }
        DynamicText.drawFit(dc, text.toUpper(), font, x, y, maxWidth, Colors.arg(ColorKey.MUTED), justify);
    }
}
