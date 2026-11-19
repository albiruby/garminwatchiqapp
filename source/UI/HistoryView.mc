import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

//! Weekly recovery-activity dashboard (7 local days ending today).
//! Page 1: 2x2 grid of headline numbers + per-module share bar.
//! Page 2 (DOWN): label/value table.
class HistoryView extends WatchUi.View {

    hidden var _m as Dictionary;
    var page as Number = 0;

    function initialize() {
        View.initialize();
        _m = CalculationEngine.summarizeWeek(HistoryRepository.load(), Time.now().value(),
            System.getClockTime().timeZoneOffset);
    }

    // 390-px grid, safe circle r170.
    // Page 1: 44 clock / 70 title / 108 hairline / 112+158 row 1 / 180 hairline /
    //         186+232 row 2 / 262 share bar / 276 completed / 300 source
    // Page 2: rows every 32 px from 116 / 282 top session / 304 source
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.WHITE, Theme.BG);
        dc.clear();
        var cx = Theme.cx(dc);
        var safe = Theme.SAFE_PAGE;
        Theme.centerText(dc, Theme.px(dc, 44), Theme.body(), Theme.WHITE, Theme.clock());
        Theme.centerText(dc, Theme.px(dc, 70), Theme.title(), Theme.WHITE, "This week");
        Theme.divider(dc, Theme.px(dc, 108), safe, Theme.px(dc, 16));

        if (page == 0) {
            var off = Theme.px(dc, 62);
            stat(dc, cx - off, 112, "sessions", "SESSIONS");
            stat(dc, cx + off, 112, "minutes", "MINUTES");
            stat(dc, cx - off, 186, "categories", "MODULES");
            stat(dc, cx + off, 186, "streak", "DAY STREAK");
            dc.setColor(Theme.LINE, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx, Theme.px(dc, 118), cx, Theme.px(dc, 244));
            Theme.divider(dc, Theme.px(dc, 180), safe, Theme.px(dc, 46));
            shareBar(dc, Theme.px(dc, 262));
            var rate = _m.get("completionRate");
            Theme.centerText(dc, Theme.px(dc, 276), Theme.small(), Theme.WHITE,
                rate.isAvailable() ? rate.value.toString() + "% completed" : "No sessions yet");
            Theme.centerText(dc, Theme.px(dc, 300), Theme.label(), Theme.GREY, "RESTORA CALC");
        } else {
            var rows = [
                ["Circulation", "circulation"], ["Leg elevation", "elevation"], ["Wind-down", "windDown"],
                ["Avg session", "avgSession"], ["Pre-session HR (14 d)", "hrBaseline"]
            ];
            var rowH = Theme.px(dc, 32);
            var y = Theme.px(dc, 116);
            for (var i = 0; i < rows.size(); i++) {
                var half = Theme.lineWidth(dc, y + Theme.px(dc, 4), Theme.px(dc, 16), safe) / 2 - Theme.px(dc, 8);
                var metric = _m.get(rows[i][1]);
                var v = metric.display();
                if (rows[i][1].equals("avgSession") && metric.isAvailable()) {
                    v = Hud.mss(metric.value);
                }
                Theme.text(dc, cx - half, y + Theme.px(dc, 2), Theme.small(), Theme.GREY, rows[i][0], Graphics.TEXT_JUSTIFY_LEFT);
                Theme.text(dc, cx + half, y, Theme.body(), metric.isAvailable() ? Theme.WHITE : Theme.GREY, v,
                    Graphics.TEXT_JUSTIFY_RIGHT);
                if (i < rows.size() - 1) {
                    Theme.divider(dc, y + Theme.px(dc, 28), safe, Theme.px(dc, 26));
                }
                y += rowH;
            }
            var top = SessionLibrary.get(_m.get("mostUsed").value);
            Theme.fitLine(dc, Theme.px(dc, 282), "Top: " + ((top != null) ? top[SessionLibrary.F_NAME] : "--"),
                Theme.small(), null, safe, Theme.GREEN);
            Theme.centerText(dc, Theme.px(dc, 304), Theme.label(), Theme.GREY, "RESTORA CALC");
        }
    }

    //! Headline number (40 px, green) with its label 46 px below (390-px units).
    hidden function stat(dc as Graphics.Dc, x as Number, y as Number, key as String, label as String) as Void {
        var metric = _m.get(key);
        Theme.text(dc, x, Theme.px(dc, y), Theme.num(), metric.isAvailable() ? Theme.GREEN : Theme.GREY,
            metric.isAvailable() ? metric.value.toString() : "--", Graphics.TEXT_JUSTIFY_CENTER);
        Theme.text(dc, x, Theme.px(dc, y + 46), Theme.label(), Theme.GREY, label, Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Thin stacked bar of module share (6 green shades, 2 px gaps).
    hidden function shareBar(dc as Graphics.Dc, y as Number) as Void {
        var share = _m.get("moduleShare").value;
        var half = Theme.safeHalf(dc, y + 4, Theme.SAFE_PAGE) - Theme.px(dc, 50);
        var x = Theme.cx(dc) - half;
        var width = half * 2;
        var hgt = Theme.px(dc, 4);
        dc.setColor(Theme.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, width, hgt);
        var colors = [Theme.GREEN, 0x3FA866, 0x7FDCA0, Theme.GREEN_DIM, 0xA9E7BE, 0x255A3A];
        for (var i = 0; i < share.size(); i++) {
            if (share[i] != null && share[i] > 0) {
                var segW = width * share[i] / 100;
                dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, y, (segW > 2) ? segW - 2 : segW, hgt);
                x += segW;
            }
        }
    }

    function onHide() as Void {
        Theme.releaseLarge();
    }
}

class HistoryDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view as HistoryView;

    function initialize(view as HistoryView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.page = 1;
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.page = 0;
        WatchUi.requestUpdate();
        return true;
    }
}
