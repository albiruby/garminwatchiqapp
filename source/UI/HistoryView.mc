import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

//! Weekly recovery-activity dashboard (7 local days ending today).
//! Page 1: sessions, minutes, modules, streak. Page 2: module detail.
class HistoryView extends WatchUi.View {

    hidden var _m as Dictionary;
    var page as Number = 0;

    function initialize() {
        View.initialize();
        _m = CalculationEngine.summarizeWeek(HistoryRepository.load(), Time.now().value(),
            System.getClockTime().timeZoneOffset);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var cx = DeviceProfile.centerX(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(DeviceProfile.COLOR_TEXT, DeviceProfile.COLOR_BG);
        dc.clear();
        dc.setColor(DeviceProfile.COLOR_SAGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 10 / 100, Graphics.FONT_XTINY, "YOUR RECOVERY ACTIVITY", Graphics.TEXT_JUSTIFY_CENTER);

        if (page == 0) {
            stat(dc, w * 30 / 100, h * 24 / 100, "sessions");
            stat(dc, w * 70 / 100, h * 24 / 100, "minutes");
            stat(dc, w * 30 / 100, h * 50 / 100, "categories");
            stat(dc, w * 70 / 100, h * 50 / 100, "streak");
            dc.setColor(DeviceProfile.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 74 / 100, Graphics.FONT_XTINY,
                "Completed " + _m.get("completionRate").display(), Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var keys = ["circulation", "elevation", "windDown", "avgSession", "hrBaseline"];
            var y = h * 22 / 100;
            var lineH = dc.getFontHeight(Graphics.FONT_XTINY) + 4;
            dc.setColor(DeviceProfile.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < keys.size(); i++) {
                var metric = _m.get(keys[i]);
                dc.drawText(cx, y, Graphics.FONT_XTINY, metric.label + " " + metric.display(), Graphics.TEXT_JUSTIFY_CENTER);
                y += lineH;
            }
            var top = _m.get("mostUsed").value;
            var def = SessionLibrary.get(top);
            dc.drawText(cx, y, Graphics.FONT_XTINY, "Most used " + ((def != null) ? def[SessionLibrary.F_NAME] : "--"),
                Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(DeviceProfile.COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 84 / 100, Graphics.FONT_XTINY, "This week - RESTORA calc", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function stat(dc as Graphics.Dc, x as Number, y as Number, key as String) as Void {
        var metric = _m.get(key);
        dc.setColor(DeviceProfile.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_NUMBER_MILD, metric.display(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(DeviceProfile.COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + dc.getFontHeight(Graphics.FONT_NUMBER_MILD), Graphics.FONT_XTINY, metric.label, Graphics.TEXT_JUSTIFY_CENTER);
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
