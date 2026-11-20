import Toybox.Graphics;
import Toybox.Lang;

// Pagination — dot indicators in the reserved bottom strip. Identical position
// on every screen. Filled dot = current page; hollow = other pages.

class Pagination {
    static function draw(dc as Dc, sz as SafeZone, layout as Layout, activeIndex as Number, total as Number) as Void {
        if (total <= 1) { return; }  // single page -> no dots (keeps HOME calm)
        var y = layout.getPaginationY();
        var dotR = 3;
        var gap = 12;
        var totalW = (total * dotR * 2) + ((total - 1) * (gap - dotR * 2));
        var startX = sz.cx - (totalW / 2) + dotR;
        var i;
        var x;
        for (i = 0; i < total; i++) {
            x = startX + i * gap;
            if (i == activeIndex) {
                dc.setColor(Colors.arg(ColorKey.PRIMARY), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, dotR);
            } else {
                dc.setColor(Colors.arg(ColorKey.MUTED), Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(x, y, dotR);
            }
        }
    }
}
