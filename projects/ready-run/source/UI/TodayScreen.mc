import Toybox.Graphics;
import Toybox.Lang;

// TodayScreen — "What should I do today?" Session category, the recommendation
// as the visual focus, three context values, and an action-state pill.

class TodayScreen {
    static function draw(dc as Dc, sz as SafeZone, layout as Layout, state as AppState, sub as Number) as Void {
        ScreenHeader.draw(dc, sz, "TODAY", layout.getHeaderY());

        // Level 1 — session category (small, colored).
        SectionLabel.draw(dc, sz, state.recommendation.category, layout.getScoreY() - 40, Graphics.TEXT_JUSTIFY_CENTER);

        // Recommendation detail as the centerpiece (fitted, may wrap to 2 lines).
        var recY = layout.getScoreY() + 4;
        var font = Typography.status();
        var half = sz.maxHalfWidthAt(recY, 30);
        var maxWidth = (half * 2) - 16;
        DynamicText.drawFit(dc, state.recommendation.detail, font, sz.cx, recY, maxWidth, Colors.arg(ColorKey.PRIMARY), Graphics.TEXT_JUSTIFY_CENTER);

        Divider.draw(dc, sz, layout.getDividerY());

        // Three context values: Readiness · Training · Form (label above value).
        _contextTriplet(dc, sz, layout.getContentY() + 6, state);

        // Action pill.
        RecommendationDisplay.drawPill(dc, sz.cx, layout.getTertiaryY() + 6, state.recommendation.actionState, state.recommendation.actionColorKey);
    }

    // Three evenly spaced columns; each shows a small label over a value.
    static function _contextTriplet(dc as Dc, sz as SafeZone, y as Number, state as AppState) as Void {
        var colHalf = sz.maxHalfWidthAt(y, 30) - 4;
        // Three column centers, evenly spread within the safe width.
        var spread = colHalf - 10;
        var x0 = sz.cx - spread;
        var x1 = sz.cx;
        var x2 = sz.cx + spread;

        var r1 = state.readiness.available ? (state.readiness.score as Number).format("%d") : "--";
        var r2 = state.trainingStatus.available ? state.trainingStatus.status : "--";
        var r3 = state.form.available ? (state.form.score as Number).format("%d") : "--";

        _col(dc, x0, y, "READY", r1, state.readiness.available ? state.readiness.colorKey : ColorKey.MUTED);
        _col(dc, x1, y, "TRAINING", r2, state.trainingStatus.colorKey);
        _col(dc, x2, y, "FORM", r3, state.form.colorKey);
    }

    static function _col(dc as Dc, x as Number, y as Number, label as String, value as String, valueKey as Number) as Void {
        // Label (tiny, muted) then value below it, both centered on x.
        dc.setColor(Colors.arg(ColorKey.MUTED), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y - 12, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var vf = DynamicText.fit(dc, value, Typography.value(), 92);
        dc.setColor(Colors.arg(valueKey), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + 10, vf[0], vf[1], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
