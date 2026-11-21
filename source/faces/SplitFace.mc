import Toybox.Graphics;
import Toybox.Lang;

// Balanced and Data Dense: time | spine | readouts.
module SplitFace {

    function draw(c as Canvas, s as SettingsManager, m as Metrics, g as Goal, t as Array<String>, sec as Number) as Void {
        var L = c.L;
        var dc = c.dc as Graphics.Dc;
        var RIGHT = Graphics.TEXT_JUSTIFY_RIGHT;
        var LEFT = Graphics.TEXT_JUSTIFY_LEFT;
        var marker = (s.showAmPm && !t[2].equals("")) ? t[2] : "";

        // spine: rule in the look's style, or the goal gauge in linear style
        if (L.linear) {
            ProgressRenderer.gauge(dc, L.cx, L.gaugeTop, L.gaugeBottom, L.barH, g, s);
            c.audit.add("gauge", L.cx - L.barH / 2, L.gaugeTop, L.cx + L.barH / 2, L.gaugeBottom, true);
        } else {
            c.vline("spine", L.cx, L.spineTop, L.spineBottom);
        }

        // time column
        c.text("hours", L.leftX, L.hoursY, L.timeFont, t[0], ThemeManager.TEXT, RIGHT);
        c.text("minutes", L.leftX, L.minutesY, L.timeFont, t[1], ThemeManager.TEXT, RIGHT);
        if (L.markerY >= 0 && !marker.equals("")) {
            c.text("ampm", L.leftX, L.markerY, L.textFont, marker, ThemeManager.MUTED, RIGHT);
            marker = "";
        }
        if (L.secondsY >= 0 && s.showSeconds && sec >= 0) {
            c.text("sec", L.leftX, L.secondsY, L.textFont, sec.format("%02d"), ThemeManager.MUTED, RIGHT);
        }

        // date heads the readout column (Balanced) or the time column (Data Dense)
        if (s.showDate) {
            var dx = L.dateLeft ? L.leftX : L.rightX;
            var dj = L.dateLeft ? RIGHT : LEFT;
            c.text("date", dx, L.dateY, L.textFont, Readouts.fittedDate(c, dx, L.dateY, dj, marker), ThemeManager.MUTED, dj);
        }
        if (s.showMoveBar) {
            c.moveBar(L.rightX, L.moveY, m.moveBar);
        }

        // steps: readout column in Balanced, under the time in Data Dense
        var dense = L.preset == SettingsManager.LAYOUT_DENSE;
        var sx = dense ? L.leftX : L.rightX;
        var sj = dense ? RIGHT : LEFT;
        c.text("steps", sx, L.stepsY, L.stepsFont, g.valid ? FormatUtils.thousands(g.value) : "--",
               g.valid ? ThemeManager.TEXT : ThemeManager.MUTED, sj);
        c.line("status", sx, L.statusY, Readouts.fittedStatus(c, g, sx, L.statusY, sj), sj);

        if (L.dividerY >= 0) {
            c.hline("divider", L.rightX, L.rightX + L.colW, L.dividerY);
        }
        var ids = Readouts.visible(m, s, true);
        for (var i = 0; i < ids.size() && i < L.rows.size(); i++) {
            row(c, s, L.rows[i], ids[i], m);
        }
    }

    // Readout row: label on the left, value on the right, goal bar underneath.
    function row(c as Canvas, s as SettingsManager, y as Number, id as Number, m as Metrics) as Void {
        var L = c.L;
        var dc = c.dc as Graphics.Dc;
        var r = Readouts.metric(id, m, s);
        var tag = "row" + id;
        // the smaller label sits on the value's bottom edge
        var dy = (dc.getFontHeight(L.valueFont) - dc.getFontHeight(L.labelFont)) / 2;
        if (s.showLabels) {
            c.text(tag + "-label", L.rightX, y + dy, L.labelFont, r[1] as String, ThemeManager.MUTED, Graphics.TEXT_JUSTIFY_LEFT);
        }
        c.text(tag + "-value", L.rightX + L.colW, y, L.valueFont, r[0] as String, r[2] as Number, Graphics.TEXT_JUSTIFY_RIGHT);
        var goal = r[3] as Goal?;
        if (goal != null && goal.hasTarget) {
            c.bar(tag + "-bar", L.rightX + L.colW / 2, y + LayoutEngine.ROW_BAR_DY, L.colW, LayoutEngine.MINI_BAR_H, goal, s,
                  s.goalStyle == SettingsManager.STYLE_SEGMENTED ? ProgressRenderer.MINI_SEGMENTS : 1);
        }
    }
}
