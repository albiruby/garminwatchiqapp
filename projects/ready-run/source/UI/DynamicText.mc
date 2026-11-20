import Toybox.Graphics;
import Toybox.Lang;

// DynamicText — measure every dynamic string before drawing. If it doesn't
// fit the allowed width: (1) smaller font -> (2) abbreviate -> (3) truncate.
// Never clip, never draw outside the safe zone. Returns chosen font + text.

class DynamicText {
    // Pick the best (font, text) to fit maxWidth. Starts at `font` and steps
    // down the ladder; abbreviates known-long words; last resort truncates
    // with an ellipsis. Returns [font, text, width, height].
    static function fit(dc as Dc, text as String, font as Graphics.FontDefinition, maxWidth as Number) as Array {
        var ladder = _ladderFor(font);
        var i;
        for (i = 0; i < ladder.size(); i++) {
            var f = ladder[i];
            var dims = dc.getTextDimensions(text, f);
            if (dims[0] <= maxWidth) {
                return [f, text, dims[0], dims[1]];
            }
        }
        // Still too wide at smallest font -> abbreviate, then truncate.
        var small = ladder[ladder.size() - 1];
        var abbrev = abbreviate(text);
        var d2 = dc.getTextDimensions(abbrev, small);
        if (d2[0] <= maxWidth) {
            return [small, abbrev, d2[0], d2[1]];
        }
        var trunc = truncate(dc, abbrev, small, maxWidth);
        var d3 = dc.getTextDimensions(trunc, small);
        return [small, trunc, d3[0], d3[1]];
    }

    // Font ladder to try, descending size, starting from the requested font.
    static function _ladderFor(font as Graphics.FontDefinition) as Array {
        if (font == Graphics.FONT_NUMBER_HOT) {
            return [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_LARGE];
        }
        if (font == Graphics.FONT_LARGE) {
            return [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL];
        }
        if (font == Graphics.FONT_MEDIUM) {
            return [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_XTINY];
        }
        return [Graphics.FONT_SMALL, Graphics.FONT_XTINY];
    }

    // Known long status/workout strings -> compact forms.
    static function abbreviate(text as String) as String {
        var t = text.toUpper();
        if (t == "UNPRODUCTIVE") { return "UNPROD"; }
        if (t == "OVERREACHING") { return "OVERECH"; }
        if (t == "DETRAINING") { return "DETRAIN"; }
        if (t == "MAINTAINING") { return "MAINTAIN"; }
        if (t == "PRODUCTIVE") { return "PROD"; }
        if (t == "HIGH INTENSITY INTERVAL") { return "HI INTERVAL"; }
        if (t == "THRESHOLD SESSION") { return "THRESHOLD"; }
        if (t == "LONG EASY RUN") { return "LONG EASY"; }
        if (t == "NOT AVAILABLE") { return "N/A"; }
        return text;
    }

    // Binary-trim the string (by whole characters) to fit maxWidth.
    static function truncate(dc as Dc, text as String, font as Graphics.FontDefinition, maxWidth as Number) as String {
        if (dc.getTextDimensions(text, font)[0] <= maxWidth) {
            return text;
        }
        var out = text;
        var guard = 0;
        while (out.length() > 1 && guard < 40) {
            out = out.substring(0, out.length() - 1);
            if (dc.getTextDimensions(out + "-", font)[0] <= maxWidth) {
                return out + "-";
            }
            guard = guard + 1;
        }
        return out;
    }

    // Convenience: draw a fitted, justified line inside maxWidth at (x, y).
    // justify is a Graphics.TEXT_JUSTIFY_* value. y is the baseline top.
    static function drawFit(dc as Dc, text as String, font as Graphics.FontDefinition, x as Number, y as Number, maxWidth as Number, color as Number, justify as Number) as Void {
        var res = fit(dc, text, font, maxWidth);
        var f = res[0];
        var t = res[1];
        var h = res[3];
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        // Vertically center within the line box using VCENTER when supported.
        dc.drawText(x, y, f, t, justify | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
