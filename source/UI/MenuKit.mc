import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Custom-drawn menus so lists use Roboto Mono, module icons and the RESTORA
//! palette (native Menu2 cannot use custom fonts).
module MenuKit {

    // 390-px units. Rows are tall enough that only the focused row and one
    // neighbour on each side are visible; anything beyond the safe circle
    // (r160) is hidden by the MenuMask foreground, so no row is ever cut by
    // the bezel.
    const ITEM_H = 96;
    const FOCUS_H = 104;
    const TITLE_H = 116;

    function newMenu(title as String) as WatchUi.CustomMenu {
        return new WatchUi.CustomMenu(ITEM_H, Theme.BG, {
            :focusItemHeight => FOCUS_H,
            :title => new MenuTitle(title),
            :titleItemHeight => TITLE_H,
            :foreground => new MenuMask()
        });
    }
}

//! Black ring over everything outside the safe circle.
class MenuMask extends WatchUi.Drawable {

    function initialize() {
        Drawable.initialize({});
    }

    function draw(dc as Graphics.Dc) as Void {
        var r = Theme.px(dc, Theme.SAFE_MENU);
        var outer = dc.getWidth() / 2 + 2;
        var pen = outer - r + 2;
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pen);
        dc.drawCircle(Theme.cx(dc), Theme.cy(dc), r + pen / 2);
        dc.setPenWidth(1);
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
        Theme.text(dc, cx, Theme.px(dc, 42), Theme.label(), Theme.GREY, Theme.clock(), Graphics.TEXT_JUSTIFY_CENTER);
        Theme.text(dc, cx, Theme.px(dc, 63), Theme.title(), Theme.IVORY, _title, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.LINE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - Theme.px(dc, 80), Theme.px(dc, 108), cx + Theme.px(dc, 80), Theme.px(dc, 108));
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

    // Row geometry (390-px units): focused surface spans x 55..335 so its
    // corners stay inside r160 wherever the row sits; icon at x 94, text at
    // x 126, right value ends at x 304.
    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var focused = isFocused();
        var midY = h / 2;
        var iconX = Theme.px(dc, 94);
        var textX = iconX;
        var valueX = Theme.px(dc, 304);

        if (focused) {
            var x0 = Theme.px(dc, 55);
            dc.setColor(Theme.DEEP, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x0, Theme.px(dc, 8), w - 2 * x0, h - Theme.px(dc, 16), Theme.px(dc, 14));
            dc.setColor(Theme.MINT, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x0, midY - Theme.px(dc, 16), Theme.px(dc, 4), Theme.px(dc, 32), 2);
        }
        if (_icon != ICON_NONE) {
            drawIcon(dc, iconX, midY, Theme.px(dc, focused ? 28 : 20), focused ? Theme.MINT : Theme.GREY);
            textX = iconX + Theme.px(dc, 32);
        }
        var nameFont = focused ? Theme.title() : Theme.body();
        var hasSub = focused && sub != null;
        var nameY = hasSub ? midY - Theme.px(dc, 27) : midY - dc.getFontHeight(nameFont) / 2;
        var right = (value != null) ? valueX - dc.getTextWidthInPixels(value, Theme.body()) - Theme.px(dc, 10) : valueX;
        // Name too long to share its line with the value: value drops to the sub line.
        var valueOnSub = hasSub && value != null && dc.getTextWidthInPixels(name, nameFont) > right - textX;
        if (valueOnSub) {
            right = valueX;
        }
        var maxW = right - textX;
        Theme.text(dc, textX, nameY, nameFont, focused ? Theme.IVORY : Theme.GREY,
            Theme.fit(dc, name, nameFont, maxW), Graphics.TEXT_JUSTIFY_LEFT);
        if (hasSub) {
            var subMax = valueX - textX;
            if (valueOnSub) {
                subMax -= dc.getTextWidthInPixels(value, Theme.label()) + Theme.px(dc, 10);
            }
            Theme.text(dc, textX, midY + Theme.px(dc, 4), Theme.label(), Theme.SAGE,
                Theme.fit(dc, sub, Theme.label(), subMax), Graphics.TEXT_JUSTIFY_LEFT);
        }
        if (value != null) {
            if (valueOnSub) {
                Theme.text(dc, valueX, midY + Theme.px(dc, 4), Theme.label(), valueOn ? Theme.MINT : Theme.GREY,
                    value, Graphics.TEXT_JUSTIFY_RIGHT);
            } else {
                Theme.text(dc, valueX, nameY + (hasSub ? Theme.px(dc, 4) : 0), Theme.body(),
                    valueOn ? Theme.MINT : Theme.GREY, value, Graphics.TEXT_JUSTIFY_RIGHT);
            }
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
