import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

// Screenshot-time collision check (only active when Preview.ON). Every drawn element
// registers its visible box; overlapping boxes (with a 3 px margin) and boxes that
// leave the content circle are outlined in pure red (#FF0000), a colour the face never
// uses otherwise, so tools/sheet.ps1 can flag the shot automatically.
class LayoutAudit {

    const MARGIN = 3;
    const RED = 0xFF0000;

    private var _boxes as Array = [];
    var enabled as Boolean = false;

    function reset(on as Boolean) as Void {
        enabled = on;
        _boxes = [];
    }

    // inCircle: false for elements that intentionally sit in the track opening (battery).
    function add(tag as String, x0 as Number, y0 as Number, x1 as Number, y1 as Number, inCircle as Boolean) as Void {
        if (enabled) {
            _boxes.add([tag, x0, y0, x1, y1, inCircle]);
        }
    }

    // Bitmap fonts are cropped to their ink, so the font height is the glyph box.
    function addText(tag as String, x as Number, y as Number, width as Number, height as Number, justify as Number) as Void {
        if (!enabled) {
            return;
        }
        // TEXT_JUSTIFY_RIGHT is 0, so test LEFT and CENTER explicitly
        var x0 = x - width;
        if ((justify & Graphics.TEXT_JUSTIFY_LEFT) != 0) {
            x0 = x;
        } else if ((justify & Graphics.TEXT_JUSTIFY_CENTER) != 0) {
            x0 = x - width / 2;
        }
        add(tag, x0, y - height / 2, x0 + width, y + height / 2, true);
    }

    // Returns the number of problems and outlines each one.
    function check(dc as Graphics.Dc, L as LayoutEngine) as Number {
        if (!enabled) {
            return 0;
        }
        var bad = 0;
        dc.setPenWidth(1);
        dc.setColor(RED, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _boxes.size(); i++) {
            var a = _boxes[i] as Array;
            if ((a[5] as Boolean) && !inside(a, L)) {
                outline(dc, a);
                System.println("AUDIT outside: " + a[0]);
                bad++;
            }
            for (var j = i + 1; j < _boxes.size(); j++) {
                var b = _boxes[j] as Array;
                if (overlap(a, b)) {
                    outline(dc, a);
                    outline(dc, b);
                    System.println("AUDIT overlap: " + a[0] + " / " + b[0]);
                    bad++;
                }
            }
        }
        return bad;
    }

    private function overlap(a as Array, b as Array) as Boolean {
        return (a[1] as Number) < (b[3] as Number) + MARGIN && (b[1] as Number) < (a[3] as Number) + MARGIN
            && (a[2] as Number) < (b[4] as Number) + MARGIN && (b[2] as Number) < (a[4] as Number) + MARGIN;
    }

    private function inside(a as Array, L as LayoutEngine) as Boolean {
        var xs = [a[1], a[3]];
        var ys = [a[2], a[4]];
        var lim = L.contentR * L.contentR;
        for (var i = 0; i < 2; i++) {
            for (var j = 0; j < 2; j++) {
                var dx = (xs[i] as Number) - L.cx;
                var dy = (ys[j] as Number) - L.cy;
                if (dx * dx + dy * dy > lim) {
                    return false;
                }
            }
        }
        return true;
    }

    private function outline(dc as Graphics.Dc, a as Array) as Void {
        dc.drawRectangle(a[1] as Number, a[2] as Number, (a[3] as Number) - (a[1] as Number) + 1,
                         (a[4] as Number) - (a[2] as Number) + 1);
    }
}
