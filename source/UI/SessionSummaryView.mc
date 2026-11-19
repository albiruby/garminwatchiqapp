import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Post-session summary, laid out like a run summary: status, name, active
//! time as the headline number, then a 2x2 grid of the most relevant fields.
//! Missing data is never shown as a number; HR fields only appear when Garmin
//! readings exist.
class SessionSummaryView extends WatchUi.View {

    hidden var _completed as Boolean;
    hidden var _name as String;
    hidden var _time as String;
    hidden var _fields as Array; // [[label, value], ...] up to 4
    hidden var _footer as String;

    function initialize(record as Dictionary, def, saved as Boolean) {
        View.initialize();
        _completed = RecordUtil.isCompleted(record);
        _name = def[SessionLibrary.F_NAME].toUpper();
        var m = CalculationEngine.summarizeSession(record);
        _time = Hud.mmss(m.get("duration").value);
        _fields = buildFields(m, record);
        var hasHr = m.get("hrBefore").isAvailable() || m.get("hrAfter").isAvailable();
        _footer = !saved ? "NOT SAVED" : (hasHr ? "HR GARMIN / CALC RESTORA" : "CALC: RESTORA");
    }

    hidden function buildFields(m as Dictionary, record as Dictionary) as Array {
        var f = [];
        var done = RecordUtil.getNum(record, Models.K_DONE, 0);
        var tot = RecordUtil.getNum(record, Models.K_TOTAL, 0);
        f.add(["EXERCISES", done.toString() + "/" + tot.toString()]);
        f.add(["COMPLETE", m.get("completion").display()]);
        var hrB = m.get("hrBefore");
        var hrA = m.get("hrAfter");
        var d = m.get("hrChange");
        if (d.isAvailable()) {
            var change = -d.value; // after - before
            f.add(["HR " + hrB.value.toString() + ">" + hrA.value.toString(), ((change > 0) ? "+" : "") + change.toString()]);
        } else if (hrB.isAvailable() || hrA.isAvailable()) {
            f.add(["HR", hrB.isAvailable() ? hrB.value.toString() : hrA.value.toString()]);
        }
        if (RecordUtil.tagSeconds(record, Models.TAG_BREATH) > 0 && m.get("cycles").isAvailable()) {
            f.add(["CYCLES", m.get("cycles").value.toString()]);
        }
        if (m.get("elevation").value > 0) {
            f.add(["ELEVATION", Hud.mmss(m.get("elevation").value)]);
        }
        if (m.get("ankle").value > 0) {
            f.add(["ANKLE", Hud.mmss(m.get("ankle").value)]);
        }
        if (m.get("skipped").value != null && m.get("skipped").value > 0) {
            f.add(["SKIPPED", m.get("skipped").value.toString()]);
        }
        return (f.size() > 4) ? f.slice(0, 4) : f;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.IVORY, Theme.BG);
        dc.clear();
        var cx = Theme.cx(dc);
        Theme.centerText(dc, Theme.y(dc, 120), Theme.label(), _completed ? Theme.MINT : Theme.AMBER,
            _completed ? "SESSION COMPLETE" : "SESSION ENDED");
        var nameY = Theme.y(dc, 165);
        Theme.centerText(dc, nameY, Theme.title(), Theme.IVORY,
            Theme.fit(dc, _name, Theme.title(), Theme.chordHalf(dc, nameY) * 2 - 40));
        Theme.text(dc, cx, Theme.y(dc, 235), Theme.num(), Theme.IVORY, _time, Graphics.TEXT_JUSTIFY_CENTER);
        Theme.centerText(dc, Theme.y(dc, 385), Theme.label(), Theme.GREY, "ACTIVE TIME");
        Theme.divider(dc, Theme.y(dc, 440), 24);

        var off = dc.getWidth() * 17 / 100;
        for (var i = 0; i < _fields.size(); i++) {
            var x = (i % 2 == 0) ? cx - off : cx + off;
            if (i == _fields.size() - 1 && i % 2 == 0) {
                x = cx; // odd count: centre the last field
            }
            var y = Theme.y(dc, (i < 2) ? 455 : 625);
            Hud.field(dc, x, y, _fields[i][0], _fields[i][1], Theme.title(), Theme.IVORY);
        }
        dc.setColor(Theme.LINE, Graphics.COLOR_TRANSPARENT);
        if (_fields.size() > 1) {
            dc.drawLine(cx, Theme.y(dc, 460), cx, Theme.y(dc, 595));
        }
        if (_fields.size() > 2) {
            Theme.divider(dc, Theme.y(dc, 610), 40);
            if (_fields.size() > 3) {
                dc.setColor(Theme.LINE, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(cx, Theme.y(dc, 630), cx, Theme.y(dc, 765));
            }
        }
        Theme.divider(dc, Theme.y(dc, 785), 30);
        Theme.centerText(dc, Theme.y(dc, 798), Theme.label(), Theme.GREY, _footer);
        Theme.startHint(dc);
    }

    function onHide() as Void {
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
