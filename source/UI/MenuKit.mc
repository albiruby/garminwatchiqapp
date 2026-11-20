import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Custom-drawn menus: Roboto Condensed, icons, chevrons, RESTORA palette.
//!
//! 390-px units. Rows are 88 px. A foreground mask blacks out y < 62,
//! y > 316 and everything outside r164, so a list shows the title (when at the
//! top) or the focused row with one neighbour each side, and never a row
//! half-cut by the bezel.
module MenuKit {

    const ITEM_H = 88;
    const TITLE_H = 140;
    const BAND_TOP = 62;
    const BAND_BOTTOM = 316;

    function newMenu(title as String, sub, logo as Boolean) as WatchUi.CustomMenu {
        return new WatchUi.CustomMenu(ITEM_H, Theme.BG, {
            :focusItemHeight => ITEM_H,
            :title => new MenuTitle(title, sub, logo),
            :titleItemHeight => TITLE_H,
            :foreground => new MenuMask()
        });
    }
}

//! Black bands top/bottom plus everything outside the safe circle.
class MenuMask extends WatchUi.Drawable {

    function initialize() {
        Drawable.initialize({});
    }

    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, Theme.px(dc, MenuKit.BAND_TOP));
        var bottom = Theme.px(dc, MenuKit.BAND_BOTTOM);
        dc.fillRectangle(0, bottom, w, h - bottom);
        var r = Theme.px(dc, Theme.SAFE_MENU);
        var pen = w / 2 - r + 4;
        dc.setPenWidth(pen);
        dc.drawCircle(Theme.cx(dc), Theme.cy(dc), r + pen / 2);
        dc.setPenWidth(1);
    }
}

//! Header: optional leaf logo, title, optional small uppercase subtitle.
class MenuTitle extends WatchUi.Drawable {

    hidden var _title as String;
    hidden var _sub;
    hidden var _logo as Boolean;

    function initialize(title as String, sub, logo as Boolean) {
        Drawable.initialize({});
        _title = title;
        _sub = sub;
        _logo = logo;
    }

    function draw(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth() / 2;
        if (_logo) {
            Icons.draw(dc, Models.CAT_RECOVER, cx, Theme.px(dc, 82), Theme.px(dc, 24), Theme.GREEN);
        }
        Theme.text(dc, cx, Theme.px(dc, _logo ? 96 : 84), Theme.title(), Theme.WHITE, _title, Graphics.TEXT_JUSTIFY_CENTER);
        if (_sub != null) {
            Theme.text(dc, cx, Theme.px(dc, _logo ? 123 : 113), Theme.label(), Theme.GREY, _sub, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

//! One row: optional icon, name, subtitle, and a chevron or a value on the right.
class RowItem extends WatchUi.CustomMenuItem {

    static const ICON_NONE = -1;

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

    // Row geometry (390-px units): focused surface x 48..342, icon at x 84,
    // text at x 116 (84 without icon), chevron/value ends at x 324.
    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var focused = isFocused();
        var midY = h / 2;
        var textX = Theme.px(dc, (_icon != ICON_NONE) ? 116 : 84);
        var rightX = Theme.px(dc, 324);

        if (focused) {
            var x0 = Theme.px(dc, 48);
            dc.setColor(Theme.SURFACE, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x0, Theme.px(dc, 6), w - 2 * x0, h - Theme.px(dc, 12), Theme.px(dc, 12));
            dc.setColor(Theme.GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x0, midY - Theme.px(dc, 18), Theme.px(dc, 4), Theme.px(dc, 36), 2);
        }
        if (_icon != ICON_NONE) {
            Icons.draw(dc, _icon, Theme.px(dc, 84), midY, Theme.px(dc, 26), focused ? Theme.GREEN : Theme.SOFT);
        }
        var right = rightX - Theme.px(dc, 12);
        if (value != null) {
            right = rightX - dc.getTextWidthInPixels(value, Theme.body()) - Theme.px(dc, 10);
        }
        var nameFont = focused ? Theme.title() : Theme.body();
        Theme.text(dc, textX, midY - dc.getFontHeight(nameFont) + Theme.px(dc, 4), nameFont,
            focused ? Theme.WHITE : Theme.SOFT, Theme.fit(dc, name, nameFont, right - textX), Graphics.TEXT_JUSTIFY_LEFT);
        if (sub != null) {
            Theme.text(dc, textX, midY + Theme.px(dc, 6), Theme.small(), Theme.GREY,
                Theme.fit(dc, sub, Theme.small(), right - textX), Graphics.TEXT_JUSTIFY_LEFT);
        }
        if (value != null) {
            Theme.text(dc, rightX, midY - dc.getFontHeight(Theme.body()) / 2, Theme.body(),
                valueOn ? Theme.GREEN : Theme.GREY, value, Graphics.TEXT_JUSTIFY_RIGHT);
        } else {
            Icons.draw(dc, Icons.CHEVRON, rightX - Theme.px(dc, 4), midY, Theme.px(dc, 12), Theme.GREY);
        }
    }
}
