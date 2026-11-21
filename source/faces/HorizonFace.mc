import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Horizon: the step goal is a level rising from the bottom of the screen to a GOAL line.
// The fill is a dark tint of the progress colour (12 %), so all text on it keeps
// >= 4.5:1. Overshoot runs as a lap bar under the goal line. Quarter marks sit at the
// screen edge.
module HorizonFace {

    const TINT = 0.12;

    function draw(c as Canvas, s as SettingsManager, m as Metrics, g as Goal, t as Array<String>) as Void {
        var L = c.L;
        var dc = c.dc as Graphics.Dc;
        var CENTER = Graphics.TEXT_JUSTIFY_CENTER;
        var range = L.levelBottom - L.levelGoal;
        var base = ThemeManager.progressColor(g.state);

        // level (drawn first, text sits on top of it)
        if (g.hasTarget) {
            var y = L.levelBottom - (ActivityGoalEngine.trackFraction(g) * range).toNumber();
            dc.setColor(tint(base), ThemeManager.BLACK);
            dc.fillRectangle(0, y, L.w, L.h - y);
            dc.setColor(base, ThemeManager.BLACK);
            dc.fillRectangle(0, y - 1, L.w, 2);
            var lap = ActivityGoalEngine.lapFraction(g);
            if (lap > 0.0) {
                var half = edge(L, L.levelGoal);
                dc.setColor(ThemeManager.lapColor(), ThemeManager.BLACK);
                dc.fillRectangle(L.cx - half, L.levelGoal + 3, (2 * half * lap).toNumber(), 3);
            }
        }
        marks(c, L);

        // time, date, hero step count, status, two readouts
        c.text("time", L.cx, L.timeY, L.timeFont, t[0] + ":" + t[1], ThemeManager.TEXT, CENTER);
        if (s.showDate) {
            var marker = (s.showAmPm && !t[2].equals("")) ? t[2] : "";
            c.text("date", L.cx, L.dateY, L.textFont, Readouts.fittedDate(c, L.cx, L.dateY, CENTER, marker), ThemeManager.MUTED, CENTER);
        }
        c.text("hero", L.cx, L.heroY, L.heroFont, g.valid ? FormatUtils.thousands(g.value) : "--",
               g.valid ? ThemeManager.TEXT : ThemeManager.MUTED, CENTER);
        c.line("status", L.cx, L.statusY, Readouts.fittedStatus(c, g, L.cx, L.statusY, CENTER), CENTER);

        var ids = Readouts.visible(m, s, true);
        var runs = [];
        for (var i = 0; i < ids.size() && i < 2; i++) {
            var r = Readouts.metric(ids[i], m, s);
            runs.add([(i > 0 ? "     " : "") + (r[0] as String), r[2] as Number, L.valueFont]);
            if (s.showLabels) {
                runs.add([" " + (r[1] as String), ThemeManager.MUTED, L.labelFont]);
            }
        }
        if (runs.size() > 0 && c.fits(runs, L.cx, L.valueY, CENTER)) {
            c.line("readouts", L.cx, L.valueY, runs, CENTER);
        }
    }

    // Quarter marks at both screen edges; the 100 % mark is longer and labelled GOAL.
    function marks(c as Canvas, L as LayoutEngine) as Void {
        var dc = c.dc as Graphics.Dc;
        var range = L.levelBottom - L.levelGoal;
        for (var q = 1; q <= 4; q++) {
            var y = L.levelBottom - range * q / 4;
            var half = edge(L, y);
            var len = q == 4 ? 18 : 9;
            dc.setColor(q == 4 ? ThemeManager.MUTED : ThemeManager.FAINT, ThemeManager.BLACK);
            dc.fillRectangle(L.cx - half, y - 1, len, 2);
            dc.fillRectangle(L.cx + half - len, y - 1, len, 2);
        }
        var gx = L.cx + edge(L, L.levelGoal) - 24;
        c.text("goal-label", gx, L.levelGoal - 12, L.labelFont, "GOAL", ThemeManager.MUTED, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // Half-width of the screen at y, 6 px in from the edge.
    function edge(L as LayoutEngine, y as Number) as Number {
        var rr = L.r - 6;
        var dy = (y - L.cy).abs();
        return dy >= rr ? 0 : Math.sqrt(rr * rr - dy * dy).toNumber();
    }

    function tint(rgb as Number) as Number {
        var r = (((rgb >> 16) & 0xFF) * TINT).toNumber();
        var g = (((rgb >> 8) & 0xFF) * TINT).toNumber();
        var b = ((rgb & 0xFF) * TINT).toNumber();
        return (r << 16) | (g << 8) | b;
    }
}
