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
    // Page 1: 49 title / 94 hairline / 95+144 row 1 / 178 hairline /
    //         177+226 row 2 / 262 share bar / 276 completed / 306 source
    // Page 2: 49 title / 94 hairline / rows every 34 px from 100 / 278 top / 306 source
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.IVORY, Theme.BG);
        dc.clear();
        var cx = Theme.cx(dc);
        var safe = Theme.SAFE_PAGE;
        Theme.centerText(dc, Theme.px(dc, 49), Theme.title(), Theme.IVORY, "THIS WEEK");
        Theme.divider(dc, Theme.px(dc, 94), safe, Theme.px(dc, 16));

        if (page == 0) {
            var off = Theme.px(dc, 64);
            stat(dc, cx - off, 95, "sessions", "SESSIONS");
            stat(dc, cx + off, 95, "minutes", "MINUTES");
            stat(dc, cx - off, 177, "categories", "MODULES");
            stat(dc, cx + off, 177, "streak", "STREAK");
            dc.setColor(Theme.LINE, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx, Theme.px(dc, 104), cx, Theme.px(dc, 246));
            Theme.divider(dc, Theme.px(dc, 170), safe, Theme.px(dc, 40));
            shareBar(dc, Theme.px(dc, 262));
            Theme.centerText(dc, Theme.px(dc, 276), Theme.label(), Theme.GREY,
                "COMPLETED " + _m.get("completionRate").display());
        } else {
            var rows = [
                ["CIRCULATION", "circulation"], ["LEG ELEV.", "elevation"], ["WIND-DOWN", "windDown"],
                ["AVG SESSION", "avgSession"], ["PRE HR 14D", "hrBaseline"]
            ];
            var rowH = Theme.px(dc, 34);
            var y = Theme.px(dc, 100);
            for (var i = 0; i < rows.size(); i++) {
                var half = Theme.lineWidth(dc, y + Theme.px(dc, 7), Theme.px(dc, 15), safe) / 2 - Theme.px(dc, 6);
                var metric = _m.get(rows[i][1]);
                var v = metric.display().toUpper();
                if (rows[i][1].equals("avgSession") && metric.isAvailable()) {
                    v = Hud.mmss(metric.value);
                }
                Theme.text(dc, cx - half, y + Theme.px(dc, 4), Theme.label(), Theme.GREY, rows[i][0], Graphics.TEXT_JUSTIFY_LEFT);
                Theme.text(dc, cx + half, y, Theme.body(), metric.isAvailable() ? Theme.IVORY : Theme.GREY, v,
                    Graphics.TEXT_JUSTIFY_RIGHT);
                if (i < rows.size() - 1) {
                    Theme.divider(dc, y + Theme.px(dc, 30), safe, Theme.px(dc, 24));
                }
                y += rowH;
            }
            var top = SessionLibrary.get(_m.get("mostUsed").value);
            Theme.fitLine(dc, Theme.px(dc, 278), "TOP: " + ((top != null) ? top[SessionLibrary.F_NAME].toUpper() : "--"),
                Theme.label(), null, safe, Theme.SAGE);
        }
        Theme.centerText(dc, Theme.px(dc, 306), Theme.label(), Theme.GREY, "CALC: RESTORA");
    }

    //! Headline number (44 px) with its label 49 px below (390-px units).
    hidden function stat(dc as Graphics.Dc, x as Number, y as Number, key as String, label as String) as Void {
        var metric = _m.get(key);
        Theme.text(dc, x, Theme.px(dc, y), Theme.num(), metric.isAvailable() ? Theme.MINT : Theme.GREY,
            metric.isAvailable() ? metric.value.toString() : "--", Graphics.TEXT_JUSTIFY_CENTER);
        Theme.text(dc, x, Theme.px(dc, y + 49), Theme.label(), Theme.GREY, label, Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Thin stacked bar of module share (6 segments, sage shades, gaps between).
    hidden function shareBar(dc as Graphics.Dc, y as Number) as Void {
        var share = _m.get("moduleShare").value;
        var half = Theme.safeHalf(dc, y + 6, Theme.SAFE_PAGE) - Theme.px(dc, 40);
        var x = Theme.cx(dc) - half;
        var width = half * 2;
        dc.setColor(Theme.SURFACE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, width, Theme.px(dc, 6), 3);
        var colors = [Theme.MINT, Theme.SAGE, 0xA9C4AE, 0x6E8F77, 0xDCE8DD, 0x557461];
        for (var i = 0; i < share.size(); i++) {
            if (share[i] != null && share[i] > 0) {
                var segW = width * share[i] / 100;
                dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, y, (segW > 2) ? segW - 2 : segW, Theme.px(dc, 6));
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
