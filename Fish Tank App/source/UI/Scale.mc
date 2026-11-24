import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

// Multi-device layout. All drawing and hit testing is written for a 390 x 390 round
// screen (Forerunner 165). On another round screen every draw call goes through ScaledDc,
// which maps the 390 canvas onto the real one, and touch points are mapped back. On a
// 390 screen nothing is wrapped, so the FR165 pays nothing for this.
//
// Fonts are not scaled: each resolution has its own Pixelify Sans set baked at the right
// size (resources-round-WxH/fonts, tools/make-fonts.py), so text stays pixel-sharp. Text
// widths and heights are reported back in canvas units, so every fit / wrap measurement
// keeps working unchanged.
module Scale {
    const BASE = 390;
    var s = 1.0;           // real pixels per canvas pixel
    var on = false;
    var mip = false;       // 64-color memory-in-pixel screen (every supported watch under 300 px)

    function init() {
        var w = System.getDeviceSettings().screenWidth;
        if (w == null || w <= 0) { w = BASE; }
        s = w / (BASE * 1.0);
        on = w != BASE;
        mip = w < 300;
    }

    // Canvas -> screen
    function px(v) {
        var r = v * s;
        return r >= 0 ? (r + 0.5).toNumber() : (r - 0.5).toNumber();
    }

    // Screen -> canvas (touch input)
    function inv(v) {
        return (v / s).toNumber();
    }

    // A touch point [x, y] in canvas coordinates.
    function canvas(c) {
        return on ? [inv(c[0]), inv(c[1])] : c;
    }

    // The Dc to draw with: the real one on a 390 screen, otherwise a scaling wrapper.
    function wrap(dc) {
        return on ? new ScaledDc(dc) : dc;
    }
}

// The subset of Graphics.Dc the app uses, in canvas coordinates. Rectangles are scaled by
// their edges, so neighbouring pixel-art blocks still meet without gaps or overlaps.
class ScaledDc {
    var dc;
    var k;          // Scale.s, kept here: this is called hundreds of times per frame

    function initialize(d) {
        dc = d;
        k = Scale.s;
    }

    function getWidth() {
        return Scale.BASE;
    }

    function getHeight() {
        return Scale.BASE;
    }

    function setColor(fg, bg) {
        dc.setColor(fg, bg);
    }

    function setPenWidth(w) {
        var p = Scale.px(w);
        dc.setPenWidth(p < 1 ? 1 : p);
    }

    function len(v) {
        var p = Scale.px(v);
        return (p < 1 && v > 0) ? 1 : p;
    }

    // The hottest call (every pixel-art block): rounding inline, no helper calls.
    // Coordinates on screen are >= 0, where adding 0.5 and truncating rounds.
    function fillRectangle(x, y, w, h) {
        var x0 = (x * k + 0.5).toNumber();
        var y0 = (y * k + 0.5).toNumber();
        var ww = ((x + w) * k + 0.5).toNumber() - x0;
        var hh = ((y + h) * k + 0.5).toNumber() - y0;
        if (ww < 1) { ww = 1; }
        if (hh < 1) { hh = 1; }
        dc.fillRectangle(x0, y0, ww, hh);
    }

    function fillRoundedRectangle(x, y, w, h, r) {
        var x0 = Scale.px(x);
        var y0 = Scale.px(y);
        dc.fillRoundedRectangle(x0, y0, Scale.px(x + w) - x0, Scale.px(y + h) - y0, len(r));
    }

    function drawRoundedRectangle(x, y, w, h, r) {
        var x0 = Scale.px(x);
        var y0 = Scale.px(y);
        dc.drawRoundedRectangle(x0, y0, Scale.px(x + w) - x0, Scale.px(y + h) - y0, len(r));
    }

    function fillCircle(x, y, r) {
        dc.fillCircle(Scale.px(x), Scale.px(y), len(r));
    }

    function drawCircle(x, y, r) {
        dc.drawCircle(Scale.px(x), Scale.px(y), len(r));
    }

    function fillEllipse(x, y, a, b) {
        dc.fillEllipse(Scale.px(x), Scale.px(y), len(a), len(b));
    }

    function fillPolygon(pts) {
        var out = new [pts.size()];
        for (var i = 0; i < pts.size(); i++) { out[i] = [Scale.px(pts[i][0]), Scale.px(pts[i][1])]; }
        dc.fillPolygon(out);
    }

    function drawLine(x1, y1, x2, y2) {
        dc.drawLine(Scale.px(x1), Scale.px(y1), Scale.px(x2), Scale.px(y2));
    }

    function drawText(x, y, font, text, just) {
        dc.drawText(Scale.px(x), Scale.px(y), font, text, just);
    }

    function getTextWidthInPixels(text, font) {
        return (dc.getTextWidthInPixels(text, font) / Scale.s + 0.5).toNumber();
    }

    function getFontHeight(font) {
        return (dc.getFontHeight(font) / Scale.s + 0.5).toNumber();
    }

    // Bitmaps are drawn at their real size (the tank's scene cache is screen-sized).
    function drawBitmap(x, y, bmp) {
        dc.drawBitmap(Scale.px(x), Scale.px(y), bmp);
    }
}
