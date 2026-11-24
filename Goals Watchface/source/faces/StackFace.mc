import Toybox.Graphics;
import Toybox.Lang;

// Stack: every goal as a column against one shared 100 % line. Steps comes first;
// distance, calories, intensity and floors follow when shown. A metric without a target
// gets an empty outline instead of an invented bar. Overshoot rises above the line.
module StackFace {

    function draw(c as Canvas, s as SettingsManager, m as Metrics, g as Goal, t as Array<String>) as Void {
        var L = c.L;
        var dc = c.dc as Graphics.Dc;
        var CENTER = Graphics.TEXT_JUSTIFY_CENTER;

        c.text("time", L.cx, L.timeY, L.timeFont, t[0] + ":" + t[1], ThemeManager.TEXT, CENTER);
        if (s.showDate) {
            var marker = (s.showAmPm && !t[2].equals("")) ? t[2] : "";
            c.text("date", L.cx, L.dateY, L.textFont, Readouts.fittedDate(c, L.cx, L.dateY, CENTER, marker), ThemeManager.MUTED, CENTER);
        }

        // columns: [value text, short label, goal]
        var cols = [[g.valid ? FormatUtils.compact(g.value) : "--", "STEPS", g]];
        var ids = Readouts.visible(m, s, false);
        var shortLabels = ["", "KCAL", "MIN", "", "FL"];
        for (var i = 0; i < ids.size() && cols.size() < 5; i++) {
            var r = Readouts.metric(ids[i], m, s);
            var value = r[0] as String;
            if (ids[i] == Readouts.M_CALORIES && m.calories != null) {
                value = FormatUtils.compact(m.calories);
            }
            var label = ids[i] == Readouts.M_DISTANCE ? r[1] as String : shortLabels[ids[i]] as String;
            cols.add([value, label, r[3]]);
        }

        var n = cols.size();
        var first = L.cx - (n - 1) * L.colPitch / 2;
        var height = L.colBottom - L.colGoal;
        var extra = L.colGoal - L.colTop;
        for (var i = 0; i < n; i++) {
            var col = cols[i] as Array;
            var x = first + i * L.colPitch;
            var left = x - L.colWidth / 2;
            var goal = col[2] as Goal?;
            if (goal != null && goal.hasTarget) {
                dc.setColor(ThemeManager.TRACK, ThemeManager.BLACK);
                dc.fillRectangle(left, L.colGoal, L.colWidth, height);
                var fh = (ActivityGoalEngine.trackFraction(goal) * height).toNumber();
                if (fh > 0) {
                    dc.setColor(ThemeManager.progressColor(goal.state), ThemeManager.BLACK);
                    dc.fillRectangle(left, L.colBottom - fh, L.colWidth, fh);
                }
                var oh = (ActivityGoalEngine.lapFraction(goal) * extra).toNumber();
                if (oh > 0) {
                    dc.setColor(ThemeManager.lapColor(), ThemeManager.BLACK);
                    dc.fillRectangle(left, L.colGoal - oh, L.colWidth, oh);
                }
            } else {
                // no target: outline only, never an invented level
                dc.setColor(ThemeManager.FAINT, ThemeManager.BLACK);
                dc.setPenWidth(1);
                dc.drawRectangle(left, L.colGoal, L.colWidth, height);
            }
            c.audit.add("col" + i, left, L.colTop, left + L.colWidth, L.colBottom, true);
            // Text font: column pitch is 48 px, the value font would touch its neighbours
            c.text("col" + i + "-value", x, L.valueY, L.textFont, col[0] as String,
                   i == 0 && goal != null ? ThemeManager.textAccent(goal.state) : ThemeManager.TEXT, CENTER);
            if (s.showLabels) {
                c.text("col" + i + "-label", x, L.labelY, L.labelFont, col[1] as String, ThemeManager.MUTED, CENTER);
            }
        }

        // shared 100 % line across the columns, in the look's rule style
        var x0 = first - L.colWidth / 2 - 6;
        var x1 = first + (n - 1) * L.colPitch + L.colWidth / 2 + 6;
        dc.setColor(ThemeManager.MUTED, ThemeManager.BLACK);
        dc.setPenWidth(1);
        for (var x = x0; x < x1; x += 6) {
            dc.drawLine(x, L.colGoal, (x + 3 < x1 ? x + 3 : x1), L.colGoal);
        }
    }
}
