import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Post-session summary, laid out like a run summary: status, name, active
//! time as the headline number, then a 2x2 grid of the most relevant fields.
//! Missing data is never shown as a number; HR fields only appear when Garmin
//! readings exist.
class SessionSummaryView extends WatchUi.View {

    hidden var _completed as Boolean;
    hidden var _subtitle as String;
    hidden var _rows as Array; // [[iconId, value, label], ...] up to 3
    hidden var _badge as Tween;
    hidden var _clock as FrameClock;

    function initialize(record as Dictionary, def, saved as Boolean) {
        View.initialize();
        _completed = RecordUtil.isCompleted(record);
        _subtitle = def[SessionLibrary.F_NAME] + " · " + (saved ? "RESTORA calc" : "not saved");
        _rows = buildRows(CalculationEngine.summarizeSession(record), record);
        _badge = new Tween();
        _clock = new FrameClock(method(:onFrame));
    }

    //! Play the completion badge once, then stop the clock (static screen).
    function onShow() as Void {
        _badge.start(System.getTimer(), CompletionAnimation.DURATION_MS, Easing.OUT_CUBIC);
        if (_badge.isRunning(System.getTimer())) {
            _clock.setInterval(MotionConfig.frameMs(true));
        }
    }

    function onFrame() as Void {
        if (!_badge.isRunning(System.getTimer())) {
            _clock.stop();
        }
        WatchUi.requestUpdate();
    }

    //! Duration, then the most relevant practice metric, then HR (Garmin) or
    //! completion. Missing data is never shown as a number.
    hidden function buildRows(m as Dictionary, record as Dictionary) as Array {
        var rows = [[Icons.CLOCK, Hud.mss(m.get("duration").value), "Duration"]];
        if (RecordUtil.tagSeconds(record, Models.TAG_BREATH) > 0 && m.get("cycles").isAvailable()) {
            rows.add([Icons.LUNGS, m.get("cycles").value.toString(), "Breathing cycles"]);
        } else if (m.get("elevation").value > 0) {
            rows.add([Models.CAT_CIRCULATE, Hud.mss(m.get("elevation").value), "Leg elevation"]);
        } else {
            var done = RecordUtil.getNum(record, Models.K_DONE, 0);
            var tot = RecordUtil.getNum(record, Models.K_TOTAL, 0);
            rows.add([Models.CAT_MOBILITY, done.toString() + "/" + tot.toString(), "Exercises"]);
        }
        var hrv = SessionSummaryView.hrvText(record);
        var d = m.get("hrChange");
        if (hrv != null) {
            rows.add([Icons.HEART, hrv, "HRV · Garmin RR"]);
        } else if (d.isAvailable()) {
            var change = -d.value; // after - before
            var arrow = (change < 0) ? "↓ " : ((change > 0) ? "↑ " : "");
            rows.add([Icons.HEART, arrow + change.abs().toString() + " bpm", "HR change · Garmin"]);
        } else {
            rows.add([Icons.CHECK, m.get("completion").display(), "Completed"]);
        }
        return rows;
    }

    //! "38 → 46 ms", "46 ms", or null when no HRV was measured.
    static function hrvText(record as Dictionary) {
        var s = record.get(Models.K_HRV_START);
        var e = record.get(Models.K_HRV_END);
        if (s != null && e != null) {
            return s.toString() + " → " + e.toString() + " ms";
        }
        if (e != null) {
            return e.toString() + " ms";
        }
        return null;
    }

    // 390-px grid, safe circle r170. Everything is centred on the round face:
    //   46-94 badge (r24 @ 70) / 102 title / 134 subtitle / 164 hairline /
    //   rows every 40 px from 176 (icon + grey label left, white value right,
    //   width from the safe circle at that height) / 296 Done pill (to 326)
    hidden const ROW_Y = 176;
    hidden const ROW_H = 40;

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.WHITE, Theme.BG);
        dc.clear();
        var cx = Theme.cx(dc);
        var safe = Theme.SAFE_PAGE;
        CompletionAnimation.draw(dc, cx, Theme.px(dc, 70), Theme.px(dc, 24), _completed ? Theme.GREEN : Theme.AMBER,
            _badge.value(System.getTimer()));
        Theme.fitLine(dc, Theme.px(dc, 102), _completed ? "Session complete" : "Session ended", Theme.title(), Theme.body(),
            safe, Theme.WHITE);
        Theme.fitLine(dc, Theme.px(dc, 134), _subtitle, Theme.small(), null, safe, Theme.GREY);
        Theme.divider(dc, Theme.px(dc, 164), safe, Theme.px(dc, Theme.SP_XXL));

        var iconS = Theme.px(dc, 18);
        var lineH = dc.getFontHeight(Theme.body());
        // one column width for every row (the narrowest, lowest row) so icons,
        // labels and values line up vertically
        var lastY = Theme.px(dc, ROW_Y + ROW_H * (_rows.size() - 1));
        var half = Theme.lineWidth(dc, lastY, lineH, safe) / 2 - Theme.px(dc, Theme.SP_XL);
        for (var i = 0; i < _rows.size(); i++) {
            var y = Theme.px(dc, ROW_Y + ROW_H * i);
            var midY = y + lineH / 2;
            Icons.draw(dc, _rows[i][0], cx - half + iconS / 2, midY, iconS, Theme.SOFT);
            var labelX = cx - half + iconS + Theme.px(dc, Theme.SP_M);
            var valueW = dc.getTextWidthInPixels(_rows[i][1], Theme.body());
            var labelMax = (cx + half) - valueW - Theme.px(dc, Theme.SP_M) - labelX;
            Theme.text(dc, labelX, midY - dc.getFontHeight(Theme.small()) / 2, Theme.small(), Theme.GREY,
                Theme.fit(dc, _rows[i][2], Theme.small(), labelMax), Graphics.TEXT_JUSTIFY_LEFT);
            Theme.text(dc, cx + half, y, Theme.body(), Theme.WHITE, _rows[i][1], Graphics.TEXT_JUSTIFY_RIGHT);
            if (i < _rows.size() - 1) {
                var ly = y + Theme.px(dc, ROW_H) - Theme.px(dc, Theme.SP_S) - Theme.px(dc, 2);
                dc.setColor(Theme.LINE, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(cx - half, ly, cx + half, ly);
            }
        }
        Theme.pill(dc, 296, "Done");
        Theme.startHint(dc);
    }

    function onHide() as Void {
        _clock.stop();
        Theme.releaseLarge();
    }
}

class SessionSummaryDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    //! START = done, back to the session list.
    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
