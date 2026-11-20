import Toybox.Graphics;
import Toybox.Lang;

// TrainingStatusScreen — "How is my training?" Large status word in semantic
// color, then supporting indicators. Paginated:
//   Page A: big status + VO2 Max + HRV
//   Page B: Acute Load + Performance
// Only available metrics are shown; missing -> "--" / NOT AVAILABLE.

class TrainingStatusScreen {
    static function draw(dc as Dc, sz as SafeZone, layout as Layout, state as AppState, sub as Number) as Void {
        ScreenHeader.draw(dc, sz, "TRAINING STATUS", layout.getHeaderY());

        if (sub == 0) {
            // Big status word.
            StatusDisplay.draw(dc, sz, state.trainingStatus.status, layout.getScoreY() - 6, state.trainingStatus.colorKey);
            Divider.draw(dc, sz, layout.getDividerY());

            var rowY = layout.getContentY();
            _indicatorRow(dc, sz, "VO2 MAX", _vo2Text(state.trainingStatus.vo2), _trendArrow(state.trainingStatus.vo2Trend), state.trainingStatus.vo2.isUsable() ? ColorKey.READY : ColorKey.MUTED, rowY);
            MetricRow.divider(dc, sz, rowY + 15);
            _indicatorRow(dc, sz, "HRV", state.trainingStatus.hrvStatus, "", state.trainingStatus.hrvColorKey, rowY + 34);
        } else {
            var rowH = 26;
            var gap = 12;
            var top = layout.getContentY() + 6;
            var r0 = top;
            var r1 = top + rowH + gap;

            _indicatorRow(dc, sz, "ACUTE LOAD", state.trainingStatus.acuteLoad, "", state.trainingStatus.acuteColorKey, r0);
            MetricRow.divider(dc, sz, r0 + 15);
            _indicatorRow(dc, sz, "PERFORMANCE", state.trainingStatus.performance, "", state.trainingStatus.perfColorKey, r1);
        }
    }

    static function _vo2Text(m as MetricValue) as String {
        if (!m.isUsable() || m.value == null) { return "--"; }
        return (m.value as Number).format("%d");
    }

    static function _trendArrow(trend as Number) as String {
        if (trend == 1) { return "(up)"; }
        if (trend == -1) { return "(dn)"; }
        return "";
    }

    // label left, value + optional arrow right.
    static function _indicatorRow(dc as Dc, sz as SafeZone, label as String, value as String, arrow as String, valueKey as Number, rowY as Number) as Void {
        var full = value;
        if (arrow.length() > 0) { full = value + " " + arrow; }
        MetricRow.draw(dc, sz, label, full, Colors.arg(valueKey), rowY);
    }
}
