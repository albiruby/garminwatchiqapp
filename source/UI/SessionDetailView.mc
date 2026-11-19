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

//! Session detail: module, name, total / steps, step table, safety note,
//! START hint on the bezel next to the START button.
class SessionDetailView extends WatchUi.View {

    hidden var _id;
    hidden var _def;

    function initialize(id, def) {
        View.initialize();
        _id = id;
        _def = def;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.IVORY, Theme.BG);
        dc.clear();
        var cx = Theme.cx(dc);
        var cat = _def[SessionLibrary.F_CAT];
        var steps = _def[SessionLibrary.F_STEPS];

        Icons.draw(dc, cat, cx, Theme.y(dc, 95), 22, Theme.SAGE);
        Theme.centerText(dc, Theme.y(dc, 140), Theme.label(), Theme.SAGE, Models.categoryName(cat));
        var titleY = Theme.y(dc, 185);
        Theme.centerText(dc, titleY, Theme.title(), Theme.IVORY,
            Theme.fit(dc, _def[SessionLibrary.F_NAME].toUpper(), Theme.title(), Theme.chordHalf(dc, titleY) * 2 - 40));
        Theme.centerText(dc, Theme.y(dc, 268), Theme.label(), Theme.GREY,
            Hud.mmss(SessionLibrary.totalSeconds(_def)) + "  /  " + steps.size().toString() + " STEPS");
        Theme.divider(dc, Theme.y(dc, 330), 30);

        // Step table: "01  NAME ......  2:00"
        var rowH = 26;
        var y = Theme.y(dc, 345);
        var maxRows = 5;
        var shown = (steps.size() > maxRows) ? maxRows - 1 : steps.size();
        for (var i = 0; i < shown; i++) {
            var half = Theme.chordHalf(dc, y + rowH / 2) - 34;
            var ex = ExerciseLibrary.get(steps[i][0]);
            var name = ((ex != null) ? ex[ExerciseLibrary.F_NAME] : steps[i][0]).toUpper();
            var idx = (i + 1).format("%02d");
            var time = Hud.mmss(steps[i][1]);
            var x0 = cx - half;
            var x1 = cx + half;
            var nameX = x0 + dc.getTextWidthInPixels(idx + " ", Theme.label());
            var nameMax = x1 - nameX - dc.getTextWidthInPixels(" " + time, Theme.label());
            Theme.text(dc, x0, y, Theme.label(), Theme.SAGE, idx, Graphics.TEXT_JUSTIFY_LEFT);
            Theme.text(dc, nameX, y, Theme.label(), Theme.IVORY, Theme.fit(dc, name, Theme.label(), nameMax), Graphics.TEXT_JUSTIFY_LEFT);
            Theme.text(dc, x1, y, Theme.label(), Theme.GREY, time, Graphics.TEXT_JUSTIFY_RIGHT);
            y += rowH;
        }
        if (shown < steps.size()) {
            Theme.centerText(dc, y, Theme.label(), Theme.GREY, "+" + (steps.size() - shown).toString() + " MORE");
            y += rowH;
        }

        Theme.divider(dc, Theme.y(dc, 690), 30);
        var note = Graphics.fitTextToArea(_def[SessionLibrary.F_SAFETY], Theme.label(), dc.getWidth() * 62 / 100,
            Theme.y(dc, 125), true);
        Theme.centerText(dc, Theme.y(dc, 705), Theme.label(), Theme.GREY, note);
        Theme.centerText(dc, Theme.y(dc, 858), Theme.title(), Theme.MINT, "START");
        Theme.startHint(dc);
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
