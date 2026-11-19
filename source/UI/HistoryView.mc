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

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.IVORY, Theme.BG);
        dc.clear();
        var cx = Theme.cx(dc);
        Hud.statusLine(dc, Theme.y(dc, 110));
        Theme.centerText(dc, Theme.y(dc, 170), Theme.title(), Theme.IVORY, "THIS WEEK");
        Theme.divider(dc, Theme.y(dc, 260), 24);

        if (page == 0) {
            var off = dc.getWidth() * 18 / 100;
            stat(dc, cx - off, Theme.y(dc, 280), "sessions", "SESSIONS");
            stat(dc, cx + off, Theme.y(dc, 280), "minutes", "MINUTES");
            stat(dc, cx - off, Theme.y(dc, 490), "categories", "MODULES");
            stat(dc, cx + off, Theme.y(dc, 490), "streak", "STREAK");
            dc.setColor(Theme.LINE, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx, Theme.y(dc, 285), cx, Theme.y(dc, 680));
            Theme.divider(dc, Theme.y(dc, 475), 40);
            shareBar(dc, Theme.y(dc, 715));
            Theme.centerText(dc, Theme.y(dc, 745), Theme.label(), Theme.GREY,
                "COMPLETED " + _m.get("completionRate").display());
        } else {
            var rows = [
                ["CIRCULATION", "circulation"], ["LEG ELEV.", "elevation"], ["WIND-DOWN", "windDown"],
                ["AVG SESSION", "avgSession"], ["PRE HR 14D", "hrBaseline"]
            ];
            var y = Theme.y(dc, 285);
            var rowH = Theme.y(dc, 82);
            for (var i = 0; i < rows.size(); i++) {
                var half = Theme.chordHalf(dc, y + 10) - 36;
                var metric = _m.get(rows[i][1]);
                var v = metric.display().toUpper();
                if (rows[i][1].equals("avgSession") && metric.isAvailable()) {
                    v = Hud.mmss(metric.value);
                }
                Theme.text(dc, cx - half, y, Theme.label(), Theme.GREY, rows[i][0], Graphics.TEXT_JUSTIFY_LEFT);
                Theme.text(dc, cx + half, y - 3, Theme.body(), metric.isAvailable() ? Theme.IVORY : Theme.GREY, v,
                    Graphics.TEXT_JUSTIFY_RIGHT);
                y += rowH;
                if (i < rows.size() - 1) {
                    Theme.divider(dc, y - rowH / 3, 44);
                }
            }
            var top = SessionLibrary.get(_m.get("mostUsed").value);
            Theme.centerText(dc, y, Theme.label(), Theme.SAGE,
                "TOP: " + ((top != null) ? top[SessionLibrary.F_NAME].toUpper() : "--"));
        }
        Theme.centerText(dc, Theme.y(dc, 830), Theme.label(), Theme.GREY, "CALC: RESTORA");
    }

    hidden function stat(dc as Graphics.Dc, x as Number, y as Number, key as String, label as String) as Void {
        var metric = _m.get(key);
        Theme.text(dc, x, y, Theme.num(), metric.isAvailable() ? Theme.MINT : Theme.GREY,
            metric.isAvailable() ? metric.value.toString() : "--", Graphics.TEXT_JUSTIFY_CENTER);
        Theme.text(dc, x, y + Theme.y(dc, 140), Theme.label(), Theme.GREY, label, Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Thin stacked bar of module share (6 segments, sage shades, gaps between).
    hidden function shareBar(dc as Graphics.Dc, y as Number) as Void {
        var share = _m.get("moduleShare").value;
        var half = Theme.chordHalf(dc, y) - 60;
        var x = Theme.cx(dc) - half;
        var width = half * 2;
        dc.setColor(Theme.SURFACE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, width, 6, 3);
        var colors = [Theme.MINT, Theme.SAGE, 0xA9C4AE, 0x6E8F77, 0xDCE8DD, 0x557461];
        for (var i = 0; i < share.size(); i++) {
            if (share[i] != null && share[i] > 0) {
                var segW = width * share[i] / 100;
                dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, y, (segW > 2) ? segW - 2 : segW, 6);
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
