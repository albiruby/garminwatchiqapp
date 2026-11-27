import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Glance preview: a tiny porthole into the tank. A slim HUD strip carries the identity
// and the two numbers that matter (coins, level); the rest of the canvas is the scene.
// Runs in the glance context, so it reads only the core save and uses the pixel fonts.
(:glance)
class FishTankGlanceView extends WatchUi.GlanceView {
    var _small = null;

    function initialize() {
        GlanceView.initialize();
    }

    function smallFont() {
        if (_small == null) { _small = WatchUi.loadResource(Rez.Fonts.PixG); }
        return _small;
    }

    function short(n) {
        if (n < 10000) { return n.toString(); }
        if (n < 100000) { return (n / 1000).toString() + "." + ((n % 1000) / 100).toString() + "k"; }
        return (n / 1000).toString() + "k";
    }

    // Theme tints only the top water band; the rest of the palette stays aquarium-dark.
    function water(t) {
        if (t == 0) { return 0x1F7A72; }
        if (t == 1) { return 0x1F4E9E; }
        if (t == 2) { return 0x5B3A8E; }
        if (t == 4) { return 0x2A7FA8; }
        if (t == 5) { return 0x14284D; }
        return 0x1F4E9E;
    }

    function fish(dc, x, y, r, body, tail, stripe) {
        dc.setColor(tail, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x - r + 1, y],
            [x - r - (r / 2), y - (r / 2)],
            [x - r - (r / 2), y + (r / 2)]
        ]);
        dc.setColor(body, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(x, y, r, (r * 3) / 5);
        if (stripe != null) {
            dc.setColor(stripe, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - (r / 3), y - (r / 2), (r < 9 ? 1 : 2), r);
        }
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x + (r / 2), y - 2, 1);
    }

    function plant(dc, x, base, height, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, base - height, 3, height);
        dc.fillRectangle(x - 3, base - height + 5, 3, 2);
        dc.fillRectangle(x + 3, base - height + 9, 3, 2);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var compact = h < 90;
        var sf = smallFont();
        var fh = dc.getFontHeight(sf);
        var strip = fh + 6;
        // The wide glance rectangle tucks under the round glass at the top and sides.
        var topInset = w > 240 ? 10 : 0;
        var insetX = w > 240 ? 18 : 8;
        var top = topInset + strip;

        var coins = 0;
        var lv = 1;
        var theme = 3;
        var ready = false;
        var d = Application.Storage.getValue("tank") as Lang.Dictionary;
        if (d != null) {
            var v = d["c"];
            if (v instanceof Number) { coins = v; ready = true; }
            v = d["l"];
            if (v instanceof Number) { lv = v; }
            v = d["th"];
            if (v instanceof Number) { theme = v; }
        }

        // Canvas base.
        dc.setColor(0x081326, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h);

        // Scene: three water bands, a sand shelf, plants and two fish.
        var floor = top + (((h - top) * 72) / 100);
        var band = (floor - top) / 3;
        // A 2 px theme accent keeps the water palette calm instead of a bright band.
        dc.setColor(water(theme), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, top, w, 2);
        dc.setColor(0x1B5E6E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, top + 2, w, band - 2);
        dc.setColor(0x174C63, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, top + band, w, band);
        dc.setColor(0x123A52, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, top + band * 2, w, floor - (top + band * 2));
        dc.setColor(0x6B4A8A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, floor, w, h - floor);
        dc.setColor(0x8E6AAE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, floor, w, 2);
        dc.setColor(0x4A3266, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h - 3, w, 3);

        var ph = compact ? 12 : 22;
        plant(dc, insetX - 1, floor + 2, ph, 0x2FA37A);
        plant(dc, insetX + 7, floor + 2, ph - 6, 0x1F7A5A);
        plant(dc, w - (compact ? 48 : 60), floor + 2, ph - 4, 0x8E5AD6);
        plant(dc, w - (compact ? 40 : 52), floor + 2, ph - 10, 0x5B3A8E);

        var fr = compact ? 7 : 12;
        fish(dc, (w * (compact ? 0.54 : 0.60)).toNumber(), (top + floor) / 2, fr, 0xFF8A3C, 0xFF6A2C, 0xFFFFFF);
        fish(dc, (w * (compact ? 0.68 : 0.70)).toNumber(), top + ((floor - top) / 3), (fr * 2) / 3, 0x7FE7FF, 0x4FB3D1, null);
        dc.setColor(0xBDEBFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle((w * 0.71).toNumber(), top + ((floor - top) / 4), 1);
        dc.fillCircle((w * 0.76).toNumber(), top + ((floor - top) / 2), 1);

        // Slim HUD strip: identity left, coins and level right.
        dc.setColor(0x081326, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, top);
        dc.setColor(0x2A4A7A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, top - 1, w, 1);

        var row = topInset + strip / 2;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(insetX, row, sf, "FISH TANK", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Keep the right side inside the visible chord of the round glass.
        var right = w - (w > 240 ? 80 : 42);
        if (ready) {
            var lvText = "LV" + lv.toString();
            var coinText = short(coins) + "c";
            var lvW = dc.getTextWidthInPixels(lvText, sf);
            var coinW = dc.getTextWidthInPixels(coinText, sf);
            var lvX = right - lvW;
            var coinX = lvX - 8 - coinW;
            dc.setColor(0x7FE7FF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(lvX, row, sf, lvText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(0xFFC93C, Graphics.COLOR_TRANSPARENT);
            dc.drawText(coinX, row, sf, coinText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            var openText = "OPEN";
            var ow = dc.getTextWidthInPixels(openText, sf);
            dc.setColor(0x9FE8FF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(right - ow, row, sf, openText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}



