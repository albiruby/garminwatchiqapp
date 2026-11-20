import Toybox.Graphics;
import Toybox.Lang;

// MetricRow — label left, value right on one line, measured dynamically so the
// two never collide. Optional thin divider below. Used by BODY READINESS pages.

class MetricRow {
    // Draw a row: label (left, muted) + value (right, colored) centered on rowY.
    // Returns the row height used so callers can advance.
    static function draw(dc as Dc, sz as SafeZone, label as String, valueText as String, valueColor as Number, rowY as Number) as Number {
        var rowH = 26;
        var half = sz.maxHalfWidthAt(rowY, rowH);
        var leftX = sz.cx - half + 6;
        var rightX = sz.cx + half - 6;

        // Measure label and value; shrink value if they'd overlap.
        var labelFont = Typography.label();
        var valueFont = Typography.value();
        var lw = dc.getTextDimensions(label, labelFont)[0];
        var vw = dc.getTextDimensions(valueText, valueFont)[0];

        var avail = (half * 2) - 12;
        // If combined width exceeds available, shrink the value font first.
        while (valueFont != Graphics.FONT_XTINY && (lw + vw + 10) > avail) {
            valueFont = (valueFont == Graphics.FONT_MEDIUM) ? Graphics.FONT_SMALL : Graphics.FONT_XTINY;
            vw = dc.getTextDimensions(valueText, valueFont)[0];
        }

        // Label.
        dc.setColor(Colors.arg(ColorKey.SECONDARY), Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftX, rowY, labelFont, label, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Value (right aligned).
        dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightX, rowY, valueFont, valueText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        return rowH;
    }

    // A faint divider under a row, spanning the safe width at that y.
    static function divider(dc as Dc, sz as SafeZone, y as Number) as Void {
        var half = sz.maxHalfWidthAt(y, 2) - 14;
        if (half < 10) { return; }
        dc.setColor(Colors.arg(ColorKey.DIVIDER), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(sz.cx - half, y, sz.cx + half, y);
    }
}
