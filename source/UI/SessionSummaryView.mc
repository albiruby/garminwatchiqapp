import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Completion summary. Every number shows where it came from
//! ("Garmin" vs "RESTORA calc"); missing data is shown as "--" or omitted.
class SessionSummaryView extends WatchUi.View {

    hidden var _title as String;
    hidden var _lines as Array;
    hidden var _saved as Boolean;

    function initialize(record as Dictionary, def, saved as Boolean) {
        View.initialize();
        _saved = saved;
        _title = RecordUtil.isCompleted(record) ? "COMPLETED" : "SESSION ENDED";
        _lines = buildLines(CalculationEngine.summarizeSession(record), record);
        _lines = [def[SessionLibrary.F_NAME]].addAll(_lines);
    }

    hidden function buildLines(m as Dictionary, record as Dictionary) as Array {
        var lines = [];
        lines.add("Time " + TimeFormatter.clock(m.get("duration").value));
        lines.add("Exercises " + m.get("completion").display());
        if (RecordUtil.tagSeconds(record, Models.TAG_BREATH) > 0) {
            lines.add("Breath cycles " + m.get("cycles").display());
        }
        if (m.get("elevation").value > 0) {
            lines.add("Leg elevation " + TimeFormatter.clock(m.get("elevation").value));
        }
        if (m.get("ankle").value > 0) {
            lines.add("Ankle movement " + TimeFormatter.clock(m.get("ankle").value));
        }
        var hrB = m.get("hrBefore");
        var hrA = m.get("hrAfter");
        if (hrB.isAvailable() || hrA.isAvailable()) {
            lines.add("HR " + hrB.display() + " > " + hrA.display() + " (Garmin)");
            var d = m.get("hrChange");
            if (d.isAvailable()) {
                lines.add("Observed change " + d.display());
            }
        }
        return lines;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var cx = DeviceProfile.centerX(dc);
        var h = dc.getHeight();
        dc.setColor(DeviceProfile.COLOR_TEXT, DeviceProfile.COLOR_BG);
        dc.clear();
        dc.setColor(DeviceProfile.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 12 / 100, Graphics.FONT_SMALL, _title, Graphics.TEXT_JUSTIFY_CENTER);

        var y = h * 25 / 100;
        var lineH = dc.getFontHeight(Graphics.FONT_TINY);
        dc.setColor(DeviceProfile.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _lines.size() && y < h * 78 / 100; i++) {
            dc.drawText(cx, y, Graphics.FONT_TINY, _lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += lineH;
        }
        dc.setColor(DeviceProfile.COLOR_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 82 / 100, Graphics.FONT_XTINY,
            _saved ? "Saved - RESTORA calc" : "Not saved", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class SessionSummaryDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
