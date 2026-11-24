import Toybox.Graphics;
import Toybox.Lang;

// Drawing helpers shared by every face. Each helper registers what it draws with the
// LayoutAudit, so screenshot runs catch overlaps and anything leaving the circle.
class Canvas {

    const VC = Graphics.TEXT_JUSTIFY_VCENTER;
    const LEFT = Graphics.TEXT_JUSTIFY_LEFT;
    const CENTER = Graphics.TEXT_JUSTIFY_CENTER;

    var dc as Graphics.Dc? = null;
    var L as LayoutEngine;
    var audit as LayoutAudit;

    function initialize(layout as LayoutEngine, a as LayoutAudit) {
        L = layout;
        audit = a;
    }

    function text(tag as String, x as Number, y as Number, font, str as String, color as Number,
                  justify as Number) as Void {
        var d = dc as Graphics.Dc;
        d.setColor(color, Graphics.COLOR_TRANSPARENT);
        d.drawText(x, y, font, str, justify | VC);
        audit.addText(tag, x, y, d.getTextWidthInPixels(str, font), d.getFontHeight(font), justify);
    }

    // [text, colour, font] runs as one line anchored like a single text; smaller runs sit
    // on the bottom edge of the tallest one.
    function line(tag as String, x as Number, y as Number, runs as Array, justify as Number) as Void {
        var d = dc as Graphics.Dc;
        var total = width(runs);
        var tallest = height(runs);
        var x0 = start(x, total, justify);
        audit.add(tag, x0, y - tallest / 2, x0 + total, y + tallest / 2, true);
        for (var i = 0; i < runs.size(); i++) {
            var p = runs[i] as Array;
            var dy = (tallest - d.getFontHeight(p[2])) / 2;
            d.setColor(p[1] as Number, Graphics.COLOR_TRANSPARENT);
            d.drawText(x0, y + dy, p[2], p[0] as String, LEFT | VC);
            x0 += d.getTextWidthInPixels(p[0] as String, p[2]);
        }
    }

    // True when the runs, anchored like line() draws them, stay inside the content circle.
    function fits(runs as Array, x as Number, y as Number, justify as Number) as Boolean {
        var total = width(runs);
        var tallest = height(runs);
        var top = L.chord(y - tallest / 2);
        var bottom = L.chord(y + tallest / 2);
        var half = top < bottom ? top : bottom;
        var x0 = start(x, total, justify);
        return x0 >= L.cx - half && x0 + total <= L.cx + half;
    }

    function width(runs as Array) as Number {
        var d = dc as Graphics.Dc;
        var total = 0;
        for (var i = 0; i < runs.size(); i++) {
            var p = runs[i] as Array;
            total += d.getTextWidthInPixels(p[0] as String, p[2]);
        }
        return total;
    }

    private function height(runs as Array) as Number {
        var d = dc as Graphics.Dc;
        var tallest = 0;
        for (var i = 0; i < runs.size(); i++) {
            var fh = d.getFontHeight((runs[i] as Array)[2]);
            tallest = fh > tallest ? fh : tallest;
        }
        return tallest;
    }

    private function start(x as Number, total as Number, justify as Number) as Number {
        if (justify == LEFT) {
            return x;
        }
        return justify == CENTER ? x - total / 2 : x - total;
    }

    // Rules between groups, in the look's style: hairline, dashed, none or bold.
    function vline(tag as String, x as Number, y0 as Number, y1 as Number) as Void {
        rule(x, y0, x, y1);
        if (ThemeManager.dividerStyle != ThemeManager.DIV_NONE) {
            audit.add(tag, x, y0, x, y1, true);
        }
    }

    function hline(tag as String, x0 as Number, x1 as Number, y as Number) as Void {
        rule(x0, y, x1, y);
        if (ThemeManager.dividerStyle != ThemeManager.DIV_NONE) {
            audit.add(tag, x0, y, x1, y, true);
        }
    }

    private function rule(x0 as Number, y0 as Number, x1 as Number, y1 as Number) as Void {
        var st = ThemeManager.dividerStyle;
        if (st == ThemeManager.DIV_NONE) {
            return;
        }
        var d = dc as Graphics.Dc;
        d.setColor(ThemeManager.DIVIDER, ThemeManager.BLACK);
        d.setPenWidth(st == ThemeManager.DIV_BOLD ? 2 : 1);
        if (st != ThemeManager.DIV_DASHED) {
            d.drawLine(x0, y0, x1, y1);
            return;
        }
        // 4 px dash, 4 px gap
        var len = (x1 - x0).abs() + (y1 - y0).abs();
        for (var p = 0; p < len; p += 8) {
            var e = p + 4 > len ? len : p + 4;
            if (x0 == x1) {
                d.drawLine(x0, y0 + p, x0, y0 + e);
            } else {
                d.drawLine(x0 + p, y0, x0 + e, y0);
            }
        }
    }

    // Horizontal goal bar with its audit box.
    function bar(tag as String, x as Number, y as Number, w as Number, h as Number, g as Goal,
                 s as SettingsManager, segments as Number) as Void {
        ProgressRenderer.bar(dc as Graphics.Dc, x, y, w, h, g, s, segments);
        audit.add(tag, x - w / 2, y - h / 2, x + w / 2, y + h / 2, true);
    }

    // Battery: icon + percentage in the track opening (exempt from the circle check).
    function battery(m as Metrics, withDays as Boolean) as Void {
        if (m.battery == null) {
            return;
        }
        var d = dc as Graphics.Dc;
        var y = L.batteryY;
        var pct = m.battery.toNumber();
        var low = pct < 15;
        var str = pct.toString() + "%";
        if (withDays && m.batteryDays != null) {
            str += "  " + m.batteryDays.toString() + "D";
        }
        var f = L.textFont;
        var tw = d.getTextWidthInPixels(str, f);
        var iw = 20;
        var ih = 10;
        var x = L.cx - (iw + 6 + tw) / 2;
        var c = low ? ThemeManager.WARN : ThemeManager.MUTED;
        d.setColor(c, ThemeManager.BLACK);
        d.setPenWidth(1);
        d.drawRectangle(x, y - ih / 2, iw, ih);
        d.fillRectangle(x + iw, y - 2, 2, 4);
        var fill = (iw - 4) * (pct > 100 ? 100 : pct) / 100;
        if (fill > 0) {
            d.fillRectangle(x + 2, y - ih / 2 + 2, fill, ih - 4);
        }
        d.setColor(c, Graphics.COLOR_TRANSPARENT);
        d.drawText(x + iw + 6, y, f, str, LEFT | VC);
        var fh = d.getFontHeight(f);
        audit.add("battery", x, y - fh / 2, x + iw + 6 + tw, y + fh / 2, false);
    }

    // Move bar: five short dashes from x; nothing when the device reports no inactivity.
    function moveBar(x as Number, y as Number, level as Number?) as Void {
        if (y < 0 || level == null || level <= 0) {
            return;
        }
        var d = dc as Graphics.Dc;
        var sw = 14;
        var gap = 4;
        for (var i = 0; i < 5; i++) {
            var on = i < level;
            d.setColor(on ? (level >= 5 ? ThemeManager.WARN : ThemeManager.TEXT) : ThemeManager.FAINT, ThemeManager.BLACK);
            d.fillRectangle(x + i * (sw + gap), y - 2, sw, 4);
        }
        audit.add("move", x, y - 2, x + 5 * sw + 4 * gap, y + 2, true);
    }
}
