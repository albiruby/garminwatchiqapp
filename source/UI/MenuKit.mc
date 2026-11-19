import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Custom-drawn menus so lists use Roboto Mono, module icons and the RESTORA
//! palette (native Menu2 cannot use custom fonts).
module MenuKit {

    const ITEM_H = 64;
    const FOCUS_H = 104;
    const TITLE_H = 92;

    function newMenu(title as String) as WatchUi.CustomMenu {
        return new WatchUi.CustomMenu(ITEM_H, Theme.BG, {
            :focusItemHeight => FOCUS_H,
            :title => new MenuTitle(title),
            :titleItemHeight => TITLE_H
        });
    }
}

//! Menu header: clock, then the menu name in spaced uppercase.
class MenuTitle extends WatchUi.Drawable {

    hidden var _title as String;

    function initialize(title as String) {
        Drawable.initialize({});
        _title = title;
    }

    function draw(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth() / 2;
        Theme.text(dc, cx, dc.getHeight() - 62, Theme.label(), Theme.GREY, Theme.clock(), Graphics.TEXT_JUSTIFY_CENTER);
        Theme.text(dc, cx, dc.getHeight() - 38, Theme.title(), Theme.IVORY, _title, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.LINE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - 90, dc.getHeight() - 2, cx + 90, dc.getHeight() - 2);
    }
}

//! One row: optional module icon, name, subtitle (focused only), right value.
//! icon: module id 0..5, or ICON_* for non-module rows, or -1 for none.
class RowItem extends WatchUi.CustomMenuItem {

    const ICON_NONE = -1;
    const ICON_PLAY = 10;
    const ICON_HISTORY = 11;
    const ICON_SETTINGS = 12;

    var name as String;
    var sub;
    var value;
    var valueOn as Boolean = false;
    hidden var _icon as Number;

    function initialize(id, name as String, sub, icon as Number, value) {
        CustomMenuItem.initialize(id, {});
        self.name = name;
        self.sub = sub;
        self.value = value;
        _icon = icon;
    }

    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var focused = isFocused();
        var midY = h / 2;
        var left = w * 22 / 100;

        if (focused) {
            dc.setColor(Theme.DEEP, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(w * 8 / 100, 6, w * 84 / 100, h - 12, 14);
            dc.setColor(Theme.MINT, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(w * 8 / 100, h / 2 - 18, 5, 36, 2);
        }
        var textX = left;
        if (_icon != ICON_NONE) {
            drawIcon(dc, left + 4, midY, focused ? 34 : 24, focused ? Theme.MINT : Theme.GREY);
            textX = left + 36;
        }
        var nameFont = focused ? Theme.title() : Theme.body();
        var nameColor = focused ? Theme.IVORY : Theme.GREY;
        var hasSub = focused && sub != null;
        var nameY = hasSub ? midY - 30 : midY - dc.getFontHeight(nameFont) / 2;
        var maxW = w * 84 / 100 - (textX - w * 8 / 100) - ((value != null) ? 70 : 16);
        Theme.text(dc, textX, nameY, nameFont, nameColor, Theme.fit(dc, name, nameFont, maxW), Graphics.TEXT_JUSTIFY_LEFT);
        if (hasSub) {
            Theme.text(dc, textX, midY + 4, Theme.label(), Theme.SAGE, Theme.fit(dc, sub, Theme.label(), maxW + 50),
                Graphics.TEXT_JUSTIFY_LEFT);
        }
        if (value != null) {
            Theme.text(dc, w * 86 / 100, midY - dc.getFontHeight(Theme.body()) / 2, Theme.body(),
                valueOn ? Theme.MINT : Theme.GREY, value, Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }

    hidden function drawIcon(dc as Graphics.Dc, x as Number, y as Number, s as Number, color as Number) as Void {
        if (_icon >= 0 && _icon < Models.CAT_COUNT) {
            Icons.draw(dc, _icon, x, y, s, color);
            return;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var h = s / 2;
        if (_icon == ICON_PLAY) {
            dc.fillPolygon([[x - h / 2, y - h * 2 / 3], [x + h * 2 / 3, y], [x - h / 2, y + h * 2 / 3]]);
        } else if (_icon == ICON_HISTORY) {
            // Bars of a weekly chart.
            var bw = s / 6;
            var hs = [h / 2, h, h * 3 / 4, h * 3 / 2];
            for (var i = 0; i < 4; i++) {
                dc.fillRectangle(x - h + i * (bw + 2), y + h * 3 / 4 - hs[i], bw, hs[i]);
            }
        } else if (_icon == ICON_SETTINGS) {
            dc.setPenWidth(2);
            dc.drawCircle(x, y, h * 2 / 3);
            dc.fillCircle(x, y, h / 4);
            dc.drawLine(x - h, y, x - h * 2 / 3, y);
            dc.drawLine(x + h * 2 / 3, y, x + h, y);
            dc.drawLine(x, y - h, x, y - h * 2 / 3);
            dc.drawLine(x, y + h * 2 / 3, x, y + h);
            dc.setPenWidth(1);
        }
    }
}
