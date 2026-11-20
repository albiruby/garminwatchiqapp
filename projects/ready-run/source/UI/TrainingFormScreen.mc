import Toybox.Graphics;
import Toybox.Lang;

// TrainingFormScreen — "What's my fitness vs fatigue?" Paginated:
//   Page A: form score + status + FITNESS bar + FATIGUE bar
//   Page B: Trend + Balance + a short context note
// Bars keep LABEL/VALUE on one line, spacing, then the bar (never collide).

class TrainingFormScreen {
    static function draw(dc as Dc, sz as SafeZone, layout as Layout, state as AppState, sub as Number) as Void {
        ScreenHeader.draw(dc, sz, "TRAINING FORM", layout.getHeaderY());

        if (sub == 0) {
            var scoreText = state.form.available ? (state.form.score as Number).format("%d") : "--";
            ScoreDisplay.draw(dc, sz, scoreText, layout.getScoreY(), state.form.available ? Colors.arg(state.form.colorKey) : Colors.arg(ColorKey.MUTED));
            StatusDisplay.draw(dc, sz, state.form.status, layout.getStatusY(), state.form.colorKey);
            Divider.draw(dc, sz, layout.getDividerY());

            // FITNESS bar + FATIGUE bar in the content zone.
            var barY = layout.getContentY() + 4;
            _labeledBar(dc, sz, "FITNESS", state.form.fitnessPct, barY, ColorKey.READY);
            _labeledBar(dc, sz, "FATIGUE", state.form.fatiguePct, barY + 44, ColorKey.WARNING);
        } else {
            var rowH = 26;
            var gap = 12;
            var top = layout.getContentY() - 6;
            var r0 = top;
            var r1 = top + rowH + gap;

            MetricRow.draw(dc, sz, "TREND", state.form.trend, Colors.arg(state.form.trendColorKey), r0);
            MetricRow.divider(dc, sz, r0 + 15);
            MetricRow.draw(dc, sz, "BALANCE", state.form.balance, Colors.arg(state.form.balanceColorKey), r1);
        }
    }

    // LABEL (left) + VALUE% (right) on one line, then the bar below it.
    static function _labeledBar(dc as Dc, sz as SafeZone, label as String, pct as Number or Null, y as Number, colorKey as Number) as Void {
        var rowH = 22;
        var half = sz.maxHalfWidthAt(y, rowH);
        var leftX = sz.cx - half + 2;
        var rightX = sz.cx + half - 2;

        var pctText = "--";
        var barPct = 0.0;
        if (pct != null) {
            pctText = (pct as Number).format("%d") + "%";
            barPct = pct as Number;
        }

        // Label + value on one line.
        dc.setColor(Colors.arg(ColorKey.SECONDARY), Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftX, y, Typography.label(), label, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(pct != null ? Colors.arg(colorKey) : Colors.arg(ColorKey.MUTED), Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightX, y, Typography.value(), pctText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Bar below, with vertical spacing so it never collides.
        var barTop = y + 14;
        var barW = (half * 2) - 4;
        var barH = 8;
        ProgressBar.draw(dc, sz.cx - (barW / 2), barTop, barW, barH, barPct, Colors.arg(colorKey), Colors.arg(ColorKey.TRACK));
    }
}
