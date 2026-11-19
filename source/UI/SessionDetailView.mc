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

    // 390-px grid, safe circle r170:
    //   52 module icon / 68 MODULE / 84 name / 113 "10 min · 5 steps" / 140 hairline
    //   146 + 22n step table / 260 hairline / 266-284 safety note / 312 Start pill
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.WHITE, Theme.BG);
        dc.clear();
        var cx = Theme.cx(dc);
        var safe = Theme.SAFE_PAGE;
        var cat = _def[SessionLibrary.F_CAT];
        var steps = _def[SessionLibrary.F_STEPS];

        Icons.draw(dc, cat, cx, Theme.px(dc, 52), Theme.px(dc, 22), Theme.GREEN);
        Theme.centerText(dc, Theme.px(dc, 68), Theme.label(), Theme.GREEN, Models.categoryName(cat).toUpper());
        Theme.fitLine(dc, Theme.px(dc, 84), _def[SessionLibrary.F_NAME], Theme.title(), Theme.body(), safe, Theme.WHITE);
        Theme.centerText(dc, Theme.px(dc, 113), Theme.small(), Theme.GREY,
            RecordUtil.toMinutes(SessionLibrary.totalSeconds(_def)).toString() + " min · "
                + steps.size().toString() + " steps");
        Theme.divider(dc, Theme.px(dc, 140), safe, Theme.px(dc, 16));

        // Step table: "1  Name ............ 2:00", each row inside the safe circle.
        var rowH = Theme.px(dc, 22);
        var y = Theme.px(dc, 146);
        var maxRows = 5;
        var shown = (steps.size() > maxRows) ? maxRows - 1 : steps.size();
        for (var i = 0; i < shown; i++) {
            var half = Theme.lineWidth(dc, y + Theme.px(dc, 4), Theme.px(dc, 14), safe) / 2 - Theme.px(dc, 8);
            var ex = ExerciseLibrary.get(steps[i][0]);
            var name = (ex != null) ? ex[ExerciseLibrary.F_NAME] : steps[i][0];
            var time = Hud.mss(steps[i][1]);
            var x0 = cx - half;
            var x1 = cx + half;
            var nameX = x0 + dc.getTextWidthInPixels("5  ", Theme.small());
            var nameMax = x1 - nameX - dc.getTextWidthInPixels("  " + time, Theme.small());
            Theme.text(dc, x0, y, Theme.small(), Theme.GREEN, (i + 1).toString(), Graphics.TEXT_JUSTIFY_LEFT);
            Theme.text(dc, nameX, y, Theme.small(), Theme.WHITE, Theme.fit(dc, name, Theme.small(), nameMax), Graphics.TEXT_JUSTIFY_LEFT);
            Theme.text(dc, x1, y, Theme.small(), Theme.GREY, time, Graphics.TEXT_JUSTIFY_RIGHT);
            y += rowH;
        }
        if (shown < steps.size()) {
            Theme.centerText(dc, y, Theme.small(), Theme.GREY, "+" + (steps.size() - shown).toString() + " more");
        }

        Theme.divider(dc, Theme.px(dc, 260), safe, Theme.px(dc, 16));
        var noteW = Theme.lineWidth(dc, Theme.px(dc, 266), Theme.px(dc, 40), safe) - Theme.px(dc, 8);
        var note = Graphics.fitTextToArea(_def[SessionLibrary.F_SAFETY], Theme.label(), noteW, Theme.px(dc, 36), true);
        Theme.centerText(dc, Theme.px(dc, 266), Theme.label(), Theme.GREY, note);
        Theme.pill(dc, 312, "Start");
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
