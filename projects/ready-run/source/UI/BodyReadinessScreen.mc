import Toybox.Graphics;
import Toybox.Lang;

// BodyReadinessScreen — "How ready is my body?" Paginated for the round display:
//   Page A: score + status + Body Battery + Sleep Quality
//   Page B: Overnight HR + Night Stress + Recovery
// Five metrics will not fit one round screen -> paginate (spec rule).

class BodyReadinessScreen {
    static function draw(dc as Dc, sz as SafeZone, layout as Layout, state as AppState, sub as Number) as Void {
        ScreenHeader.draw(dc, sz, "BODY READINESS", layout.getHeaderY());

        if (sub == 0) {
            // Score + status.
            var scoreText = state.readiness.available ? (state.readiness.score as Number).format("%d") : "--";
            ScoreDisplay.draw(dc, sz, scoreText, layout.getScoreY(), state.readiness.available ? Colors.arg(state.readiness.colorKey) : Colors.arg(ColorKey.MUTED));
            StatusDisplay.draw(dc, sz, state.readiness.category, layout.getStatusY(), state.readiness.colorKey);
            Divider.draw(dc, sz, layout.getDividerY());

            // Two metric rows below the divider.
            var rowY = layout.getContentY();
            MetricRow.draw(dc, sz, "BODY BATTERY", state.health.bodyBattery.display(), _batteryKey(state.health.bodyBattery), rowY);
            MetricRow.divider(dc, sz, rowY + 15);
            MetricRow.draw(dc, sz, "SLEEP QUALITY", state.health.sleepQuality.display(), _sleepKey(state.health.sleepQuality), rowY + 34);
        } else {
            // Three rows, vertically centered in the content band.
            var rowH = 26;
            var gap = 12;
            var top = layout.getContentY() - 18;
            var r0 = top;
            var r1 = top + rowH + gap;
            var r2 = top + 2 * (rowH + gap);

            MetricRow.draw(dc, sz, "OVERNIGHT HR", state.health.overnightHr.display(), _hrKey(state.health.overnightHr), r0);
            MetricRow.divider(dc, sz, r0 + 15);
            MetricRow.draw(dc, sz, "NIGHT STRESS", state.health.nightStress.display(), _stressKey(state.health.nightStress), r1);
            MetricRow.divider(dc, sz, r1 + 15);
            MetricRow.draw(dc, sz, "RECOVERY", state.health.recovery.display(), _recoveryKey(state.health.recovery), r2);
        }
    }

    static function _batteryKey(m as MetricValue) as Number {
        if (!m.isUsable()) { return ColorKey.MUTED; }
        var v = m.value as Number;
        if (v >= 70) { return ColorKey.READY; }
        if (v >= 40) { return ColorKey.MODERATE; }
        return ColorKey.WARNING;
    }

    static function _sleepKey(m as MetricValue) as Number {
        if (!m.isUsable()) { return ColorKey.MUTED; }
        var v = m.value as Number;
        if (v >= 80) { return ColorKey.READY; }
        if (v >= 60) { return ColorKey.MODERATE; }
        return ColorKey.WARNING;
    }

    static function _hrKey(m as MetricValue) as Number {
        if (!m.isUsable()) { return ColorKey.MUTED; }
        var v = m.value as Number;
        if (v <= 60) { return ColorKey.READY; }
        if (v <= 70) { return ColorKey.MODERATE; }
        return ColorKey.WARNING;
    }

    static function _stressKey(m as MetricValue) as Number {
        if (!m.isUsable()) { return ColorKey.MUTED; }
        var v = m.value as Number;
        if (v <= 30) { return ColorKey.READY; }
        if (v <= 55) { return ColorKey.MODERATE; }
        return ColorKey.WARNING;
    }

    static function _recoveryKey(m as MetricValue) as Number {
        if (!m.isUsable()) { return ColorKey.MUTED; }
        var v = m.value as Number;
        if (v >= 24) { return ColorKey.READY; }
        if (v >= 12) { return ColorKey.MODERATE; }
        return ColorKey.WARNING;
    }
}
