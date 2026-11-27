import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Events hub: what is on now, this week's current, personal dates and the year ahead.
class EventsScreen extends Screen {
    var _acts;

    function initialize() {
        Screen.initialize();
        _acts = [];
        EventSystem.refresh(Globals.engine);
    }

    function title() {
        return "EVENTS";
    }

    function footer() {
        return "Repeats every year";
    }

    function daysText(n) {
        if (n <= 0) { return "today"; }
        if (n == 1) { return "tomorrow"; }
        return "in " + n.toString() + " days";
    }

    function rows() {
        var e = Globals.engine;
        var today = TimeUtil.today();
        var w = TimeUtil.weekOf(today);
        var out = [];
        _acts = [];

        for (var i = 0; i < e.events.size(); i++) {
            var id = e.events[i][0];
            var start = e.events[i][1];
            var q = EventSystem.QUEST[id];
            var p = EventSystem.progress(e, id, start);
            var done = RewardSystem.done(e, "eq" + EventSystem.key(e, id, start));
            var left = start + EventSystem.LEN[id] - today;
            var prog = q[0] == QuestSystem.Q_RUN_KM ? ActivitySystem.fmtKm(p) + "/" + ActivitySystem.fmtKm(q[1]) + " km"
                                                   : p.toString() + "/" + q[1].toString();
            var sub = done ? "Quest done - " + left.toString() + "d left" : QuestSystem.label(q[0], q[1]) + " " + prog;
            out.add([EventSystem.NAME[id], sub, IconKit.FISH, [EventSystem.SPECIES[id], false, EventSystem.edition(id)], EventSystem.UI[id]]);
            _acts.add([0, id]);
        }

        var c = WeeklySystem.current(w);
        out.add([WeeklySystem.NAME[c], WeeklySystem.DESC[c], IconKit.GRID, SpriteData.ICON_WAVE, 0x7FE7FF]);
        _acts.add([1, 0]);
        var fsp = WeeklySystem.featured(e, w);
        out.add([FishDatabase.NAME[fsp], "Featured -" + WeeklySystem.DISCOUNT.toString() + "%: " + WeeklySystem.price(e, fsp).toString() + "c",
                 IconKit.FISH, [fsp, false, 0], null]);
        _acts.add([2, 0]);
        var vsp = WeeklySystem.visitor(w);
        var vsub = WeeklySystem.visitorDone(e, w) ? "Stayed - it left you an egg"
                 : "Run " + ActivitySystem.fmtKm(WeeklySystem.weekMeters(e)) + "/" + ActivitySystem.fmtKm(WeeklySystem.VISIT_KM) + " km this week";
        out.add(["Visitor: " + FishDatabase.NAME[vsp], vsub, IconKit.FISH, [vsp, false, 0], FishDatabase.RARITY_COLOR[FishDatabase.RARITY[vsp]]]);
        _acts.add([1, 0]);
        out.add(["Spotlight: " + WeeklySystem.spotlightName(w), "Double coins this week", IconKit.GRID, SpriteData.ICON_GAME, null]);
        _acts.add([3, 0]);

        out.add(["Race Day", e.race > 0 ? CalendarUtil.fmtYear(e.race) + " - " + daysText(e.race - today) : "Not set - tap to set",
                 IconKit.GRID, SpriteData.ICON_SHOE, e.race > 0 ? 0xFFC93C : null]);
        _acts.add([4, 0]);
        var bd = e.bday.size() == 2 ? e.bday[1].toString() + " " + CalendarUtil.MONTHS[e.bday[0] - 1] : "Not set - tap to set";
        out.add(["Birthday", bd, IconKit.GRID, SpriteData.ICON_STAR, null]);
        _acts.add([5, 0]);
        if (e.installTime > 0) {
            out.add(["Tank anniversary", CalendarUtil.fmt(TimeUtil.dayOf(e.installTime)), IconKit.GRID, SpriteData.ICON_TROPHY, null]);
            _acts.add([1, 0]);
        }

        var up = EventSystem.upcoming(e, today, 6);
        for (var i = 0; i < up.size(); i++) {
            var id = up[i][0];
            out.add([EventSystem.NAME[id], CalendarUtil.fmt(up[i][1]) + " - " + daysText(up[i][1] - today),
                     IconKit.FISH, [EventSystem.SPECIES[id], false, EventSystem.edition(id)], 0x8EA3C0]);
            _acts.add([6, id]);
        }
        return out;
    }

    function pick(i, view) {
        var a = _acts[i];
        var e = Globals.engine;
        if (a[0] == 0 || a[0] == 6) {
            view.flash(EventSystem.DESC[a[1]]);
        } else if (a[0] == 2) {
            Nav.push(new ShopFishScreen());
        } else if (a[0] == 3) {
            Nav.push(new GamesScreen());
        } else if (a[0] == 4) {
            var v = new DatePickerView(DatePick.RACE);
            Nav.pushView(v, new DatePickerDelegate(v));
        } else if (a[0] == 5) {
            if (e.bday.size() == 2) { view.flash("Birthday is set"); return; }
            var v = new DatePickerView(DatePick.BIRTHDAY);
            Nav.pushView(v, new DatePickerDelegate(v));
        }
    }
}

// Pixel date picker: UP/DOWN (or tap above/below, or swipe) changes the highlighted field,
// START or a tap in the middle moves to the next field and confirms on the last one.
module DatePick {
    const RACE = 0;
    const BIRTHDAY = 1;
}

class DatePickerView extends WatchUi.View {
    var kind;
    var vals;       // [day, month, year]
    var field = 0;
    var msg = null;

    function initialize(k) {
        View.initialize();
        kind = k;
        var e = Globals.engine;
        var c;
        if (k == DatePick.RACE) {
            c = CalendarUtil.civilFromDays(e.race > 0 ? e.race : TimeUtil.today() + 21);
        } else {
            c = [2000, 1, 1];
        }
        vals = [c[2], c[1], c[0]];
    }

    function fieldCount() {
        return kind == DatePick.RACE ? 3 : 2;
    }

    function daysInMonth(y, m) {
        var ny = m == 12 ? y + 1 : y;
        var nm = m == 12 ? 1 : m + 1;
        return CalendarUtil.daysFromCivil(ny, nm, 1) - CalendarUtil.daysFromCivil(y, m, 1);
    }

    function change(d) {
        msg = null;
        if (field == 0) {
            var dim = daysInMonth(vals[2], vals[1]);
            vals[0] = (vals[0] - 1 + d + dim) % dim + 1;
        } else if (field == 1) {
            vals[1] = (vals[1] - 1 + d + 12) % 12 + 1;
        } else {
            var y0 = CalendarUtil.year(TimeUtil.today());
            vals[2] = Util.clamp(vals[2] + d, y0, y0 + 1);
        }
        var dim2 = daysInMonth(vals[2], vals[1]);
        if (vals[0] > dim2) { vals[0] = dim2; }
        WatchUi.requestUpdate();
    }

    function next() {
        if (field < fieldCount() - 1) {
            field += 1;
            WatchUi.requestUpdate();
            return;
        }
        var e = Globals.engine;
        var err;
        if (kind == DatePick.RACE) {
            err = EventSystem.setRace(e, CalendarUtil.daysFromCivil(vals[2], vals[1], vals[0]));
        } else {
            err = EventSystem.setBirthday(e, vals[1], vals[0]);
        }
        if (err == null) {
            e.toast(kind == DatePick.RACE ? "Race day set - good luck!" : "Birthday saved", 0x5EE36A);
            Nav.pop();
        } else {
            msg = err;
            WatchUi.requestUpdate();
        }
    }

    function prev() {
        if (field > 0) {
            field -= 1;
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    function onUpdate(screenDc as Graphics.Dc) as Void {
        var dc = Scale.wrap(screenDc);
        UIKit.background(dc);
        UIKit.titlePill(dc, kind == DatePick.RACE ? "RACE DAY" : "BIRTHDAY", UIKit.ACCENT);
        var labels = ["DAY", "MONTH", "YEAR"];
        var n = fieldCount();
        var bw = 82;
        var gap = 10;
        var x0 = 195 - (n * bw + (n - 1) * gap) / 2;
        for (var i = 0; i < n; i++) {
            var x = x0 + i * (bw + gap);
            var sel = i == field;
            dc.setColor(sel ? UIKit.PANEL_HI : UIKit.PANEL, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, 150, bw, 80, 14);
            dc.setColor(sel ? UIKit.ACCENT : UIKit.BORDER, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(sel ? 2 : 1);
            dc.drawRoundedRectangle(x, 150, bw, 80, 14);
            dc.setPenWidth(1);
            var v = i == 1 ? CalendarUtil.MONTHS[vals[1] - 1] : vals[i].toString();
            UIKit.text(dc, x + bw / 2, 182, UIKit.font(i == 2 ? 1 : 2), v, 0xFFFFFF, UIKit.CENTER);
            UIKit.text(dc, x + bw / 2, 216, UIKit.font(0), labels[i], UIKit.DIM, UIKit.CENTER);
            if (sel) {
                dc.setColor(UIKit.ACCENT, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([[x + bw / 2 - 7, 140], [x + bw / 2 + 7, 140], [x + bw / 2, 132]]);
                dc.fillPolygon([[x + bw / 2 - 7, 240], [x + bw / 2 + 7, 240], [x + bw / 2, 248]]);
            }
        }
        var info;
        if (msg != null) {
            info = msg;
        } else if (kind == DatePick.RACE) {
            var d = CalendarUtil.daysFromCivil(vals[2], vals[1], vals[0]) - TimeUtil.today();
            info = d > 0 ? "Race in " + d.toString() + " days" : "Pick a future date";
        } else {
            info = "Set once: a gift every year";
        }
        UIKit.text(dc, 195, 280, UIKit.font(0), UIKit.fit(dc, info, UIKit.font(0), 260), msg != null ? UIKit.GOLD : UIKit.DIM, UIKit.CENTER);
        UIKit.text(dc, 195, 310, UIKit.font(0), field < n - 1 ? "START = NEXT" : "START = SAVE", UIKit.ACCENT, UIKit.CENTER);
    }
}

class DatePickerDelegate extends WatchUi.BehaviorDelegate {
    var _v;

    function initialize(v) {
        BehaviorDelegate.initialize();
        _v = v;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var c = Scale.canvas(evt.getCoordinates());
        var n = _v.fieldCount();
        // tapping a box selects it; above/below a box changes it
        var bw = 82;
        var x0 = 195 - (n * bw + (n - 1) * 10) / 2;
        for (var i = 0; i < n; i++) {
            var x = x0 + i * (bw + 10);
            if (c[0] >= x && c[0] <= x + bw) {
                if (i != _v.field) { _v.field = i; WatchUi.requestUpdate(); return true; }
                if (c[1] < 150) { _v.change(1); return true; }
                if (c[1] > 230) { _v.change(-1); return true; }
            }
        }
        _v.next();
        return true;
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_UP) { _v.change(1); return true; }
        if (d == WatchUi.SWIPE_DOWN) { _v.change(-1); return true; }
        return true;
    }

    function onSelect() as Boolean {
        _v.next();
        return true;
    }

    function onNextPage() as Boolean {
        _v.change(-1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _v.change(1);
        return true;
    }

    function onBack() as Boolean {
        if (!_v.prev()) { Nav.pop(); }
        return true;
    }
}
