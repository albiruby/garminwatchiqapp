import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

module SessionDetail {
    function push(sessionId) as Void {
        var def = SessionLibrary.get(sessionId);
        if (def == null) {
            return;
        }
        WatchUi.pushView(new SessionDetailView(sessionId, def), new SessionDetailDelegate(sessionId, def), WatchUi.SLIDE_LEFT);
    }
}

//! Session detail: name, duration, exercise sequence, safety note, START.
class SessionDetailView extends WatchUi.View {

    hidden var _id;
    hidden var _def;

    function initialize(id, def) {
        View.initialize();
        _id = id;
        _def = def;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var cx = DeviceProfile.centerX(dc);
        var h = dc.getHeight();
        var w = dc.getWidth();
        dc.setColor(DeviceProfile.COLOR_TEXT, DeviceProfile.COLOR_BG);
        dc.clear();

        dc.setColor(DeviceProfile.COLOR_SAGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 10 / 100, Graphics.FONT_XTINY, Models.categoryName(_def[SessionLibrary.F_CAT]), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(DeviceProfile.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 16 / 100, Graphics.FONT_SMALL, _def[SessionLibrary.F_NAME], Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(DeviceProfile.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 26 / 100, Graphics.FONT_TINY, TimeFormatter.minutes(SessionLibrary.totalSeconds(_def)), Graphics.TEXT_JUSTIFY_CENTER);

        var steps = _def[SessionLibrary.F_STEPS];
        var y = h * 36 / 100;
        var lineH = dc.getFontHeight(Graphics.FONT_XTINY);
        var shown = (steps.size() > 5) ? 4 : steps.size();
        dc.setColor(DeviceProfile.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < shown; i++) {
            var ex = ExerciseLibrary.get(steps[i][0]);
            var name = (ex != null) ? ex[ExerciseLibrary.F_NAME] : steps[i][0];
            dc.drawText(cx, y, Graphics.FONT_XTINY, name + "  " + TimeFormatter.clock(steps[i][1]), Graphics.TEXT_JUSTIFY_CENTER);
            y += lineH;
        }
        if (shown < steps.size()) {
            dc.drawText(cx, y, Graphics.FONT_XTINY, "+" + (steps.size() - shown) + " more", Graphics.TEXT_JUSTIFY_CENTER);
            y += lineH;
        }

        dc.setColor(DeviceProfile.COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        var boxW = w * 70 / 100;
        var safety = Graphics.fitTextToArea(_def[SessionLibrary.F_SAFETY], Graphics.FONT_XTINY, boxW, h * 18 / 100, true);
        dc.drawText(cx, h * 70 / 100, Graphics.FONT_XTINY, safety, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(DeviceProfile.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 88 / 100, Graphics.FONT_XTINY, "START to begin", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class SessionDetailDelegate extends WatchUi.BehaviorDelegate {

    hidden var _id;
    hidden var _def;

    function initialize(id, def) {
        BehaviorDelegate.initialize();
        _id = id;
        _def = def;
    }

    function onSelect() as Boolean {
        var view = new SessionPlayerView(_id, _def);
        WatchUi.switchToView(view, new SessionPlayerDelegate(view), WatchUi.SLIDE_LEFT);
        return true;
    }
}
