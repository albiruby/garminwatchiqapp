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
    //   50 icon / 64 module / 83 title / 114 total + steps / 145 hairline
    //   150 + 22n step table / 264 hairline / 271-294 safety note / 324 START
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.IVORY, Theme.BG);
        dc.clear();
        var cx = Theme.cx(dc);
        var safe = Theme.SAFE_PAGE;
        var cat = _def[SessionLibrary.F_CAT];
        var steps = _def[SessionLibrary.F_STEPS];

        Icons.draw(dc, cat, cx, Theme.px(dc, 50), Theme.px(dc, 20), Theme.SAGE);
        Theme.centerText(dc, Theme.px(dc, 64), Theme.label(), Theme.SAGE, Models.categoryName(cat));
        Theme.fitLine(dc, Theme.px(dc, 83), _def[SessionLibrary.F_NAME].toUpper(), Theme.title(), Theme.body(), safe, Theme.IVORY);
        Theme.centerText(dc, Theme.px(dc, 114), Theme.label(), Theme.GREY,
            Hud.mmss(SessionLibrary.totalSeconds(_def)) + "  " + steps.size().toString() + " STEPS");
        Theme.divider(dc, Theme.px(dc, 145), safe, Theme.px(dc, 16));

        // Step table: "01 NAME ......... 02:00", each row inside the safe circle.
        var rowH = Theme.px(dc, 22);
        var y = Theme.px(dc, 150);
        var maxRows = 5;
        var shown = (steps.size() > maxRows) ? maxRows - 1 : steps.size();
        for (var i = 0; i < shown; i++) {
            var half = Theme.lineWidth(dc, y + Theme.px(dc, 5), Theme.px(dc, 14), safe) / 2 - Theme.px(dc, 6);
            var ex = ExerciseLibrary.get(steps[i][0]);
            var name = ((ex != null) ? ex[ExerciseLibrary.F_NAME] : steps[i][0]).toUpper();
            var idx = (i + 1).format("%02d");
            var time = Hud.mmss(steps[i][1]);
            var x0 = cx - half;
            var x1 = cx + half;
            var nameX = x0 + dc.getTextWidthInPixels(idx + " ", Theme.label());
            var nameMax = x1 - nameX - dc.getTextWidthInPixels("  " + time, Theme.label());
            Theme.text(dc, x0, y, Theme.label(), Theme.SAGE, idx, Graphics.TEXT_JUSTIFY_LEFT);
            Theme.text(dc, nameX, y, Theme.label(), Theme.IVORY, Theme.fit(dc, name, Theme.label(), nameMax), Graphics.TEXT_JUSTIFY_LEFT);
            Theme.text(dc, x1, y, Theme.label(), Theme.GREY, time, Graphics.TEXT_JUSTIFY_RIGHT);
            y += rowH;
        }
        if (shown < steps.size()) {
            Theme.centerText(dc, y, Theme.label(), Theme.GREY, "+" + (steps.size() - shown).toString() + " MORE");
        }

        Theme.divider(dc, Theme.px(dc, 264), safe, Theme.px(dc, 16));
        var noteW = Theme.lineWidth(dc, Theme.px(dc, 276), Theme.px(dc, 37), safe) - Theme.px(dc, 8);
        var note = Graphics.fitTextToArea(_def[SessionLibrary.F_SAFETY], Theme.label(), noteW, Theme.px(dc, 46), true);
        Theme.centerText(dc, Theme.px(dc, 271), Theme.label(), Theme.GREY, note);
        Theme.centerText(dc, Theme.px(dc, 324), Theme.label(), Theme.MINT, "START");
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
