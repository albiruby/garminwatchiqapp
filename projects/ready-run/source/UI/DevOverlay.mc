import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

// DevOverlay — development-only layout validator. Disabled in production via
// the DEVMODE constant (compile to false strips the drawing). Draws the safe
// / core circles, pagination strip, and component bounding boxes, and logs
// OVERLAP / CLIPPING / SAFE-ZONE VIOLATION to the console when detected.

module Dev {
    const ENABLED = false;   // flip to true during development only
}

class DevOverlay {
    static function draw(dc as Dc, sz as SafeZone, layout as Layout) as Void {
        if (!Dev.ENABLED) { return; }

        // Safe + core circles.
        dc.setPenWidth(1);
        dc.setColor(Colors.arg(ColorKey.DANGER), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(sz.cx, sz.cy, sz.safeRadius);
        dc.setColor(Colors.arg(ColorKey.INFO), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(sz.cx, sz.cy, sz.coreRadius);

        // Pagination reserved strip.
        dc.setColor(Colors.arg(ColorKey.MODERATE), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(sz.cx - sz.safeRadius, sz.paginationTop, sz.cx + sz.safeRadius, sz.paginationTop);

        // Zone markers (header/score/status/content) as faint horizontal guides.
        dc.setColor(Colors.arg(ColorKey.TRACK), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(sz.cx - 40, layout.getHeaderY(), sz.cx + 40, layout.getHeaderY());
        dc.drawLine(sz.cx - 40, layout.getScoreY(), sz.cx + 40, layout.getScoreY());
        dc.drawLine(sz.cx - 40, layout.getStatusY(), sz.cx + 40, layout.getStatusY());
        dc.drawLine(sz.cx - 40, layout.getContentY(), sz.cx + 40, layout.getContentY());
    }

    // Static check: log a safe-zone violation if a centered box doesn't fit.
    static function checkFit(sz as SafeZone, tag as String, y as Number, w as Number, h as Number) as Void {
        if (!Dev.ENABLED) { return; }
        if (!sz.fitsCentered(y, w, h)) {
            System.println("[LAYOUT ERROR] " + tag + " exceeds safe width at y=" + y);
        }
        if (sz.intrudesPagination(y, h)) {
            System.println("[LAYOUT ERROR] " + tag + " intrudes into pagination zone");
        }
    }
}
