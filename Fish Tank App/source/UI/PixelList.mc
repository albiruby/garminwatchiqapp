import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// A screen supplies content to PixelListView. Rows are
// [label, sublabel, iconKind (IconKit), iconArg, labelColor]; a null sublabel is allowed.
class Screen {
    function initialize() {
    }

    function title() {
        return "";
    }

    // Small line at the bottom (balances, hints); null shows "i / n".
    function footer() {
        return null;
    }

    function rows() {
        return [];
    }

    function pick(i, view) {
    }

    function emptyText() {
        return "Nothing here yet";
    }
}

// Round-screen list in the game's pixel style: the selected row sits large in the middle,
// neighbours above and below. UP/DOWN or swipe to move, START or tap the middle to pick,
// tap above/below to move, BACK to return.
class PixelListView extends WatchUi.View {
    var screen;
    var rows;
    var sel = 0;
    var _flash = null;
    var _flashT = 0;
    var _timer = null;

    function initialize(s) {
        View.initialize();
        screen = s;
        rows = [];
    }

    function onShow() as Void {
        refresh();
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), 120, true);
    }

    function onHide() as Void {
        if (_timer != null) { _timer.stop(); }
    }

    function onTick() as Void {
        if (_flashT > 0) { _flashT -= 1; }
        // generate one missing fish sprite per tick for visible rows
        for (var k = -1; k <= 1; k++) {
            var i = sel + k;
            if (i >= 0 && i < rows.size() && !IconKit.warm(rows[i][2], rows[i][3])) { break; }
        }
        WatchUi.requestUpdate();
    }

    function refresh() {
        rows = screen.rows();
        if (sel >= rows.size()) { sel = rows.size() - 1; }
        if (sel < 0) { sel = 0; }
        WatchUi.requestUpdate();
    }

    function flash(text) {
        _flash = text;
        _flashT = 20;
        WatchUi.requestUpdate();
    }

    function move(d) {
        if (rows.size() == 0) { return; }
        sel = (sel + d + rows.size()) % rows.size();
        WatchUi.requestUpdate();
    }

    function pickSel() {
        if (sel < rows.size()) { screen.pick(sel, self); }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        UIKit.background(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cy = h / 2;
        UIKit.titlePill(dc, screen.title(), UIKit.ACCENT);

        if (rows.size() == 0) {
            UIKit.text(dc, w / 2, cy, UIKit.font(0), screen.emptyText(), UIKit.DIM, UIKit.CENTER);
        } else {
            if (sel > 0) { drawRow(dc, rows[sel - 1], cy - 86, false); }
            if (sel < rows.size() - 1) { drawRow(dc, rows[sel + 1], cy + 86, false); }
            drawRow(dc, rows[sel], cy, true);

            // scroll position
            if (rows.size() > 1) {
                var tx = w - 30;
                PixelKit.rect(dc, 0x1A2238, tx, cy - 50, 3, 100);
                var th = 100 / rows.size();
                if (th < 8) { th = 8; }
                var ty = cy - 50 + (100 - th) * sel / (rows.size() - 1);
                PixelKit.rect(dc, UIKit.ACCENT, tx, ty, 3, th);
            }
        }

        var foot = screen.footer();
        if (_flashT > 0 && _flash != null) {
            drawFlash(dc, _flash);
        } else {
            if (foot == null && rows.size() > 0) { foot = (sel + 1).toString() + " / " + rows.size().toString(); }
            if (foot != null) {
                UIKit.text(dc, w / 2, (h * 0.885).toNumber(), UIKit.font(0), UIKit.fit(dc, foot, UIKit.font(0), 236), UIKit.DIM, UIKit.CENTER);
            }
        }
    }

    function drawRow(dc, r, cy, big) {
        var w = dc.getWidth();
        var x0 = big ? 36 : 62;
        var x1 = w - (big ? 44 : 62);
        var hh = big ? 78 : 54;
        var y0 = cy - hh / 2;
        dc.setColor(big ? UIKit.PANEL_HI : UIKit.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x0, y0, x1 - x0, hh, 14);
        dc.setColor(big ? UIKit.ACCENT : UIKit.BORDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(big ? 2 : 1);
        dc.drawRoundedRectangle(x0, y0, x1 - x0, hh, 14);
        dc.setPenWidth(1);

        var tx = x0 + 16;
        if (r[2] != IconKit.NONE) {
            var ix = x0 + (big ? 36 : 28);
            var isFish = r[2] == IconKit.FISH || r[2] == IconKit.SHADOW;
            var s = isFish ? 2 : (big ? 3 : 2);
            IconKit.draw(dc, r[2], r[3], ix, cy, s);
            tx = x0 + (big ? 72 : 54);
        }
        var maxW = x1 - tx - 12;
        var col = r[4] == null ? 0xFFFFFF : r[4];
        if (big) {
            // Label: large font if it fits, otherwise the small one. Sublabel: up to two
            // lines. The block is centred vertically in the row.
            var f0 = UIKit.font(0);
            var lf = dc.getTextWidthInPixels(r[0], UIKit.font(1)) <= maxW ? UIKit.font(1) : f0;
            var subs = r[1] == null ? [] : UIKit.wrap(dc, r[1], f0, maxW, 2);
            var lh0 = dc.getFontHeight(f0);
            if (subs.size() > 1 && lf != f0 && dc.getFontHeight(lf) + 2 * lh0 > hh - 4) { lf = f0; }
            var lhl = dc.getFontHeight(lf);
            var total = lhl + subs.size() * (lh0 - 3);
            var y = cy - total / 2;
            UIKit.text(dc, tx, y + lhl / 2, lf, UIKit.fit(dc, r[0], lf, maxW), col, UIKit.LEFT);
            y += lhl;
            for (var i = 0; i < subs.size(); i++) {
                UIKit.text(dc, tx, y + (lh0 - 3) / 2, f0, subs[i], UIKit.DIM, UIKit.LEFT);
                y += lh0 - 3;
            }
        } else {
            UIKit.text(dc, tx, cy, UIKit.font(0), UIKit.fit(dc, r[0], UIKit.font(0), maxW), PixelKit.lerpColor(col, 0x0B1226, 0.3), UIKit.LEFT);
        }
    }

    function drawFlash(dc, s) {
        // one line near the bottom edge, or two lines moved up where the glass is wider
        var f = UIKit.font(0);
        var ls = UIKit.wrap(dc, s, f, 220, 2);
        var tw = 0;
        for (var i = 0; i < ls.size(); i++) {
            var lw = dc.getTextWidthInPixels(ls[i], f);
            if (lw > tw) { tw = lw; }
        }
        var w = tw + 24;
        var lh = dc.getFontHeight(f);
        var h = lh * ls.size() + 6;
        var cy = ls.size() > 1 ? (dc.getHeight() * 0.82).toNumber() : (dc.getHeight() * 0.86).toNumber();
        var x0 = dc.getWidth() / 2 - w / 2;
        dc.setColor(UIKit.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x0, cy - h / 2, w, h, 10);
        dc.setColor(UIKit.GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x0, cy - h / 2, w, h, 10);
        UIKit.lines(dc, dc.getWidth() / 2, cy - h / 2 + 3, f, ls, UIKit.GOLD);
    }
}

class PixelListDelegate extends WatchUi.BehaviorDelegate {
    var _v;

    function initialize(v) {
        BehaviorDelegate.initialize();
        _v = v;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var y = evt.getCoordinates()[1];
        var cy = 195;
        if (y < cy - 42) { _v.move(-1); }
        else if (y > cy + 42) { _v.move(1); }
        else { _v.pickSel(); }
        return true;
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_UP) { _v.move(1); return true; }
        if (d == WatchUi.SWIPE_DOWN) { _v.move(-1); return true; }
        if (d == WatchUi.SWIPE_RIGHT) { Nav.pop(); return true; }
        return false;
    }

    function onSelect() as Boolean {
        _v.pickSel();
        return true;
    }

    function onNextPage() as Boolean {
        _v.move(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _v.move(-1);
        return true;
    }

    function onBack() as Boolean {
        Nav.pop();
        return true;
    }
}

// Yes / No question in the same list style. `cb` is a Method invoked on Yes.
class ConfirmScreen extends Screen {
    var _q;
    var _cb;

    function initialize(question, cb) {
        Screen.initialize();
        _q = question;
        _cb = cb;
    }

    function title() {
        return "CONFIRM";
    }

    function footer() {
        return _q;
    }

    function rows() {
        return [["Yes", _q, IconKit.GRID, SpriteData.ICON_CHECK, 0x5EE36A],
                ["No", "Go back", IconKit.NONE, null, 0xFFFFFF]];
    }

    function pick(i, view) {
        Nav.pop();
        if (i == 0) { _cb.invoke(); }
    }
}

// ---- Grid (Fishdex, Trophy Room) ------------------------------------------------
class GridScreen {
    function initialize() {
    }

    function title() {
        return "";
    }

    function count() {
        return 0;
    }

    // Returns false if the cell still needs a sprite generated.
    function drawCell(dc, i, cx, cy, sel) {
        return true;
    }

    function caption(i) {
        return "";
    }

    function captionColor(i) {
        return 0xFFFFFF;
    }

    function pick(i, view) {
    }

    // Prepares at most one missing sprite among cells [from, from + n).
    function warmNext(from, n) {
    }
}

// 3 columns x 3 visible rows; the selected cell is outlined and named at the bottom.
class GridView extends WatchUi.View {
    const COLS = 3;
    const CELL = 72;
    var screen;
    var sel = 0;
    var _top = 0;
    var _timer = null;
    var _pending = false;

    function initialize(s) {
        View.initialize();
        screen = s;
    }

    function onShow() as Void {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), 120, true);
    }

    function onHide() as Void {
        if (_timer != null) { _timer.stop(); }
    }

    function onTick() as Void {
        if (_pending) {
            screen.warmNext(_top * COLS, COLS * 3);
            WatchUi.requestUpdate();
        }
    }

    function move(d) {
        var n = screen.count();
        if (n == 0) { return; }
        sel = (sel + d + n) % n;
        var row = sel / COLS;
        if (row < _top) { _top = row; }
        if (row > _top + 2) { _top = row - 2; }
        WatchUi.requestUpdate();
    }

    function cellAt(x, y) {
        var w = 390;
        for (var r = 0; r < 3; r++) {
            for (var c = 0; c < COLS; c++) {
                var cx = w / 2 + (c - 1) * (CELL + 6);
                var cy = 122 + r * (CELL + 4);
                if ((x - cx).abs() < CELL / 2 && (y - cy).abs() < CELL / 2) {
                    var i = (_top + r) * COLS + c;
                    return i < screen.count() ? i : -1;
                }
            }
        }
        return -1;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        UIKit.background(dc);
        var w = dc.getWidth();
        UIKit.titlePill(dc, screen.title(), UIKit.ACCENT);
        _pending = false;
        var n = screen.count();
        for (var r = 0; r < 3; r++) {
            for (var c = 0; c < COLS; c++) {
                var i = (_top + r) * COLS + c;
                if (i >= n) { continue; }
                var cx = w / 2 + (c - 1) * (CELL + 6);
                var cy = 122 + r * (CELL + 4);
                var isSel = i == sel;
                dc.setColor(isSel ? UIKit.PANEL_HI : UIKit.PANEL, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(cx - CELL / 2, cy - CELL / 2, CELL, CELL, 12);
                dc.setColor(isSel ? UIKit.ACCENT : UIKit.BORDER, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(isSel ? 2 : 1);
                dc.drawRoundedRectangle(cx - CELL / 2, cy - CELL / 2, CELL, CELL, 12);
                dc.setPenWidth(1);
                if (!screen.drawCell(dc, i, cx, cy, isSel)) { _pending = true; }
            }
        }
        // scroll position
        var rowsTotal = (n + COLS - 1) / COLS;
        if (rowsTotal > 3) {
            var tx = w - 30;
            PixelKit.rect(dc, 0x1A2238, tx, 140, 3, 110);
            var th = 110 * 3 / rowsTotal;
            var ty = 140 + (110 - th) * _top / (rowsTotal - 3);
            PixelKit.rect(dc, UIKit.ACCENT, tx, ty, 3, th);
        }
        if (n > 0) {
            var cap = UIKit.fit(dc, screen.caption(sel), UIKit.font(0), 220);
            UIKit.text(dc, w / 2, (dc.getHeight() * 0.885).toNumber(), UIKit.font(0), cap, screen.captionColor(sel), UIKit.CENTER);
        }
    }
}

class GridDelegate extends WatchUi.BehaviorDelegate {
    var _v;

    function initialize(v) {
        BehaviorDelegate.initialize();
        _v = v;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var c = evt.getCoordinates();
        var i = _v.cellAt(c[0], c[1]);
        if (i >= 0) {
            if (i == _v.sel) { _v.screen.pick(i, _v); }
            else { _v.sel = i; WatchUi.requestUpdate(); }
        }
        return true;
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_UP) { _v.move(3); return true; }
        if (d == WatchUi.SWIPE_DOWN) { _v.move(-3); return true; }
        if (d == WatchUi.SWIPE_LEFT) { _v.move(1); return true; }
        if (d == WatchUi.SWIPE_RIGHT) { Nav.pop(); return true; }
        return false;
    }

    function onSelect() as Boolean {
        _v.screen.pick(_v.sel, _v);
        return true;
    }

    function onNextPage() as Boolean {
        _v.move(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _v.move(-1);
        return true;
    }

    function onBack() as Boolean {
        Nav.pop();
        return true;
    }
}
