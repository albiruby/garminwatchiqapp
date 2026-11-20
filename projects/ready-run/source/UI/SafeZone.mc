import Toybox.Lang;
import Toybox.Math;

// SafeZone — round-display geometry + fit tests. Central place for all
// circle math so screens never hardcode radius/center values.
// FR165: 390x390 round. physical r=195, safe content r ~ 165, core r ~ 145.

class SafeZone {
    var cx as Number;
    var cy as Number;
    var width as Number;
    var height as Number;
    var physicalRadius as Number;
    var safeRadius as Number;     // content must stay inside
    var coreRadius as Number;     // primary content band
    var paginationTop as Number;  // y above which pagination lives (reserved)

    function initialize(w as Number, h as Number) {
        width = w;
        height = h;
        cx = w / 2;
        cy = h / 2;
        physicalRadius = (w < h ? w : h) / 2;
        safeRadius = physicalRadius - 30;   // ~165 on FR165
        coreRadius = physicalRadius - 50;   // ~145 on FR165
        // Reserved pagination strip near the bottom bezel.
        paginationTop = physicalRadius + coreRadius - 8;
    }

    // Max half-width available at a given y for a box of the given height,
    // measured against the safe circle at the box's top and bottom edges.
    function maxHalfWidthAt(y as Number, boxH as Number) as Number {
        var top = y - (boxH / 2);
        var bot = y + (boxH / 2);
        var worst = _halfAtY(top);
        var wb = _halfAtY(bot);
        if (wb < worst) { worst = wb; }
        if (worst < 0) { worst = 0; }
        return worst.toNumber();
    }

    function _halfAtY(yy as Number) as Float {
        var dy = yy - cy;
        var d2 = (safeRadius * safeRadius) - (dy * dy);
        if (d2 <= 0) { return 0.0; }
        return Math.sqrt(d2);
    }

    // Does a centered box (centered on cx) of the given width/height at y fit
    // inside the safe circle? Checks the widest (bottom) corner.
    function fitsCentered(y as Number, boxW as Number, boxH as Number) as Boolean {
        return maxHalfWidthAt(y, boxH) * 2 >= boxW;
    }

    // Does an arbitrary bounding box fit? Checks all four corners.
    function fitsBox(x as Number, y as Number, boxW as Number, boxH as Number) as Boolean {
        var l = x;
        var r = x + boxW;
        var t = y;
        var b = y + boxH;
        return _inside(l, t) && _inside(r, t) && _inside(l, b) && _inside(r, b);
    }

    function _inside(px as Number, py as Number) as Boolean {
        var dx = px - cx;
        var dy = py - cy;
        return (dx * dx + dy * dy) <= (safeRadius * safeRadius);
    }

    // True if a content box would intrude into the reserved pagination strip.
    function intrudesPagination(y as Number, boxH as Number) as Boolean {
        return (y + boxH) > paginationTop;
    }
}
