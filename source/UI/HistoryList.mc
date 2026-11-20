import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! History: the weekly dashboard first, then the most recent sessions
//! (newest first). Selecting a session opens its detail.
module HistoryList {

    const MAX_ROWS = 20;

    function build() as WatchUi.CustomMenu {
        var history = HistoryRepository.load();
        var n = history.size();
        var menu = MenuKit.newMenu("History", n.toString() + ((n == 1) ? " SESSION" : " SESSIONS"), false);
        menu.addItem(new RowItem(:week, "This week", "Totals and streak", Icons.HISTORY, null));
        if (n == 0) {
            menu.addItem(new RowItem(:none, "No sessions yet", "Start one from a module", RowItem.ICON_NONE, ""));
        }
        for (var i = n - 1; i >= 0 && i >= n - MAX_ROWS; i--) {
            var r = history[i];
            menu.addItem(new RowItem(i, name(r), dateText(r) + " · " + Hud.mss(RecordUtil.getNum(r, Models.K_DUR, 0)),
                RecordUtil.getNum(r, Models.K_CAT, -1), RecordUtil.isCompleted(r) ? null : "Ended"));
        }
        return menu;
    }

    function name(r as Dictionary) as String {
        var def = SessionLibrary.get(r.get(Models.K_ID));
        return (def != null) ? def[SessionLibrary.F_NAME] : "Session";
    }

    //! "20 Nov 14:05" in local time, or "--" when the start time is missing.
    function dateText(r as Dictionary) as String {
        var start = r.get(Models.K_START);
        if (start == null) {
            return "--";
        }
        var g = Gregorian.info(new Time.Moment(start), Time.FORMAT_MEDIUM);
        return g.day.toString() + " " + g.month + " " + g.hour.format("%02d") + ":" + g.min.format("%02d");
    }
}

class HistoryListDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :week) {
            var hv = new HistoryView();
            WatchUi.pushView(hv, new HistoryDelegate(hv), WatchUi.SLIDE_LEFT);
        } else if (id instanceof Number) {
            var history = HistoryRepository.load();
            if (id < history.size()) {
                WatchUi.pushView(new SessionRecordView(history[id]), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_LEFT);
            }
        }
    }
}

//! One stored session: status, date, then a label / value table. Every value
//! that was not measured shows "--".
class SessionRecordView extends WatchUi.View {

    hidden var _r as Dictionary;

    function initialize(record as Dictionary) {
        View.initialize();
        _r = record;
    }

    // 390-px grid, safe circle r170:
    //   52 status / 76 name / 106 date / 130 hairline / rows every 30 px from 138 /
    //   318 source line
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.WHITE, Theme.BG);
        dc.clear();
        var safe = Theme.SAFE_PAGE;
        var done = RecordUtil.isCompleted(_r);
        Theme.centerText(dc, Theme.px(dc, 52), Theme.label(), done ? Theme.GREEN : Theme.AMBER, done ? "COMPLETED" : "ENDED EARLY");
        Theme.fitLine(dc, Theme.px(dc, 70), HistoryList.name(_r), Theme.title(), Theme.body(), safe, Theme.WHITE);
        Theme.centerText(dc, Theme.px(dc, 100), Theme.small(), Theme.GREY, HistoryList.dateText(_r));
        Theme.divider(dc, Theme.px(dc, 128), safe, Theme.px(dc, Theme.SP_XL));

        var hrB = _r.get(Models.K_HR_BEFORE);
        var hrA = _r.get(Models.K_HR_AFTER);
        var hrPair = (hrB == null && hrA == null) ? "--"
            : ((hrB != null ? hrB.toString() : "--") + " → " + (hrA != null ? hrA.toString() : "--"));
        var avg = _r.get(Models.K_HR_AVG);
        var hrv = SessionSummaryView.hrvText(_r);
        var rows = [
            ["Duration", Hud.mss(RecordUtil.getNum(_r, Models.K_DUR, 0))],
            ["Exercises", RecordUtil.getNum(_r, Models.K_DONE, 0).toString() + "/" + RecordUtil.getNum(_r, Models.K_TOTAL, 0).toString()
                + "  skip " + RecordUtil.getNum(_r, Models.K_SKIP, 0).toString()],
            ["HR before → after", hrPair],
            ["Avg HR", (avg != null) ? avg.toString() + " bpm" : "--"],
            ["HRV (RMSSD)", (hrv != null) ? hrv : "--"]
        ];
        var y = Theme.px(dc, 138);
        var rowH = Theme.px(dc, 30);
        for (var i = 0; i < rows.size(); i++) {
            var half = Theme.lineWidth(dc, y + Theme.px(dc, Theme.SP_S), Theme.px(dc, 16), safe) / 2 - Theme.px(dc, Theme.SP_M);
            var cx = Theme.cx(dc);
            Theme.text(dc, cx - half, y, Theme.small(), Theme.GREY, rows[i][0], Graphics.TEXT_JUSTIFY_LEFT);
            Theme.text(dc, cx + half, y, Theme.small(), Theme.WHITE, rows[i][1], Graphics.TEXT_JUSTIFY_RIGHT);
            y += rowH;
        }
        Theme.centerText(dc, Theme.px(dc, 296), Theme.label(), Theme.GREY, "HR · GARMIN   HRV · RESTORA CALC");
    }
}
