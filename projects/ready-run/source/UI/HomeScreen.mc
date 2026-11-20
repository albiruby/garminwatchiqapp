import Toybox.Graphics;
import Toybox.Lang;

// HomeScreen - "How am I today?" Readiness score + status, training status,
// today's recommendation. Calm, spacious. A tight readiness ring encircles the
// score number only. The bottom stats are full-width stacked blocks chained by
// MEASURED heights: every y-position is computed from the previous element's
// real fitted dimensions, so blocks can never overlap.

class HomeScreen {
    static function draw(dc as Dc, sz as SafeZone, layout as Layout, state as AppState, sub as Number) as Void {
        // Level 1 - header, score (ringed), status.
        ScreenHeader.draw(dc, sz, "READY RUN", layout.getHeaderY());

        var scoreY = layout.getScoreY();
        var scoreText = state.readiness.available ? (state.readiness.score as Number).format("%d") : "--";

        if (state.readiness.available) {
            ProgressRing.draw(dc, sz.cx, scoreY, 46, state.readiness.score as Number, Colors.arg(state.readiness.colorKey), Colors.arg(ColorKey.TRACK), 5);
        }
        ScoreDisplay.draw(dc, sz, scoreText, scoreY, state.readiness.available ? Colors.arg(state.readiness.colorKey) : Colors.arg(ColorKey.MUTED));

        var statusY = layout.getStatusY();
        var res = StatusDisplay.fitText(dc, sz, state.readiness.category, statusY);
        dc.setColor(Colors.arg(state.readiness.colorKey), Graphics.COLOR_TRANSPARENT);
        dc.drawText(sz.cx, statusY, res[0], res[1], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var statusBottom = statusY + (res[3] / 2);

        // Level 2 - two stacked stat blocks, chained by measured heights.
        var trainText = state.trainingStatus.available ? state.trainingStatus.status : "NOT AVAILABLE";
        var blockBottom = _statBlockMeasured(dc, sz, layout, statusBottom, "TRAINING STATUS", trainText, state.trainingStatus.colorKey);

        var recText = state.recommendation.category;
        var labelH = dc.getTextDimensions("AG", Typography.label())[1];
        var y2top = blockBottom + layout.spSm();
        // Keep block 2 above the pagination strip; DynamicText already guards
        // the width, and the stacked fit check happens via safe chord.
        _statBlockMeasuredTop(dc, sz, layout, y2top, "TODAY", recText, state.recommendation.categoryColorKey);
    }

    // Draw one block starting at topEdge (the top of the label). Returns the
    // bottom edge of the value text (measured).
    static function _statBlockMeasured(dc as Dc, sz as SafeZone, layout as Layout, topEdge as Number, label as String, value as String, valueKey as Number) as Number {
        var labelH = dc.getTextDimensions("AG", Typography.label())[1];
        var labelY = topEdge + (labelH / 2);
        var lf = DynamicText.fit(dc, label.toUpper(), Typography.label(), (sz.maxHalfWidthAt(labelY, labelH) * 2) - 12);
        dc.setColor(Colors.arg(ColorKey.MUTED), Graphics.COLOR_TRANSPARENT);
        dc.drawText(sz.cx, labelY, lf[0], lf[1], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var labelBottom = labelY + (lf[3] / 2);

        var valueY = labelBottom + layout.spTight() + (dc.getTextDimensions("AG", Typography.value())[1] / 2);
        var vf = DynamicText.fit(dc, value, Typography.value(), (sz.maxHalfWidthAt(valueY, 24) * 2) - 12);
        dc.setColor(Colors.arg(valueKey), Graphics.COLOR_TRANSPARENT);
        dc.drawText(sz.cx, valueY, vf[0], vf[1], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        return valueY + (vf[3] / 2);
    }

    // Draw one block with an explicit top edge (used when chained by caller).
    static function _statBlockMeasuredTop(dc as Dc, sz as SafeZone, layout as Layout, topEdge as Number, label as String, value as String, valueKey as Number) as Number {
        return _statBlockMeasured(dc, sz, layout, topEdge, label, value, valueKey);
    }
}
