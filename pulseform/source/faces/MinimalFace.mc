import Toybox.Graphics;
import Toybox.Lang;

// Minimal: centred stacked time, one footer line ("74%  5.24 KM").
module MinimalFace {

    function draw(c as Canvas, s as SettingsManager, m as Metrics, g as Goal, t as Array<String>) as Void {
        var L = c.L;
        var CENTER = Graphics.TEXT_JUSTIFY_CENTER;
        if (s.showDate) {
            var marker = (s.showAmPm && !t[2].equals("")) ? t[2] : "";
            c.text("date", L.cx, L.dateY, L.textFont, Readouts.fittedDate(c, L.cx, L.dateY, CENTER, marker), ThemeManager.MUTED, CENTER);
        }
        c.text("hours", L.cx, L.hoursY, L.timeFont, t[0], ThemeManager.TEXT, CENTER);
        c.text("minutes", L.cx, L.minutesY, L.timeFont, t[1], ThemeManager.TEXT, CENTER);
        if (L.linear) {
            c.bar("track", L.cx, L.barY, L.barW, L.barH, g, s, 1);
        }

        var runs = [];
        if (g.hasTarget) {
            runs.add([FormatUtils.percent(g.percent), ThemeManager.textAccent(g.state), L.textFont]);
        } else {
            runs.add([g.valid ? FormatUtils.thousands(g.value) : "--", ThemeManager.TEXT, L.textFont]);
            runs.add([" STEPS", ThemeManager.MUTED, L.labelFont]);
        }
        if (s.minimalMetric <= Readouts.M_HEART) {
            var r = Readouts.metric(s.minimalMetric, m, s);
            runs.add(["   " + (r[0] as String), r[2] as Number, L.textFont]);
            runs.add([" " + (r[1] as String), ThemeManager.MUTED, L.labelFont]);
        }
        c.line("footer", L.cx, L.footerY, runs, CENTER);
    }
}
