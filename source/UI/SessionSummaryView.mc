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
            rows.add([Icons.HEART, hrv, "HRV (RMSSD) · Garmin RR"]);
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

    // 390-px grid, safe circle r170:
    //   58 check / 82 title / 111 subtitle / 138 hairline
    //   146, 196, 246 metric rows (icon x112, value + label x140) / 306 Done pill
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.WHITE, Theme.BG);
        dc.clear();
        CompletionAnimation.draw(dc, Theme.cx(dc), Theme.px(dc, 58), Theme.px(dc, 34), _completed ? Theme.GREEN : Theme.AMBER,
            _badge.value(System.getTimer()));
        Theme.centerText(dc, Theme.px(dc, 82), Theme.title(), Theme.WHITE, _completed ? "Session complete" : "Session ended");
        Theme.fitLine(dc, Theme.px(dc, 111), _subtitle, Theme.small(), null, Theme.SAFE_PAGE, Theme.GREY);
        Theme.divider(dc, Theme.px(dc, 138), Theme.SAFE_PAGE, Theme.px(dc, 20));
        for (var i = 0; i < _rows.size(); i++) {
            var y = Theme.px(dc, 146 + 50 * i);
            Icons.draw(dc, _rows[i][0], Theme.px(dc, 112), y + Theme.px(dc, 16), Theme.px(dc, 22), Theme.WHITE);
            Theme.text(dc, Theme.px(dc, 140), y, Theme.title(), Theme.WHITE, _rows[i][1], Graphics.TEXT_JUSTIFY_LEFT);
            Theme.text(dc, Theme.px(dc, 140), y + Theme.px(dc, 28), Theme.label(), Theme.GREY, _rows[i][2], Graphics.TEXT_JUSTIFY_LEFT);
        }
        Theme.pill(dc, 306, "Done");
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
