import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class MyFishScreen extends Screen {
    function initialize() {
        Screen.initialize();
    }

    function title() {
        var e = Globals.engine;
        return "MY FISH " + e.fish.size().toString() + "/" + HabitatSystem.capacity(e).toString();
    }

    function emptyText() {
        return "No fish - visit the Shop";
    }

    function rows() {
        var e = Globals.engine;
        var out = [];
        for (var i = 0; i < e.fish.size(); i++) {
            var f = e.fish[i];
            var sub = "LV " + f.level().toString() + " " + f.stageName() + " - joy " + f.hap.toNumber().toString() + "%";
            out.add([f.name() + (f.evo ? " +" : ""), sub, IconKit.FISH, [f.sp, f.evo, f.variant], FishDatabase.RARITY_COLOR[FishDatabase.RARITY[f.sp]]]);
        }
        return out;
    }

    function pick(i, view) {
        Nav.push(new FishProfileScreen(Globals.engine.fish[i].id));
    }
}

// Fish Profile: stats, personality, preferences and the actions you can take.
class FishProfileScreen extends Screen {
    var _id;
    var _actions;

    function initialize(id) {
        Screen.initialize();
        _id = id;
        _actions = [];
    }

    function fish() {
        return Globals.engine.fishById(_id);
    }

    function title() {
        var f = fish();
        return f == null ? "FISH" : f.name().toUpper();
    }

    function rows() {
        var e = Globals.engine;
        var f = fish();
        _actions = [];
        if (f == null) { return []; }
        var sp = f.sp;
        var rar = FishDatabase.RARITY[sp];
        var tag = FishDatabase.SYN[sp];
        var out = [
            [FishDatabase.RARITY_NAME[rar] + " " + FishDatabase.HABITAT[FishDatabase.HAB[sp]],
             (f.edition() > 0 ? EventSystem.NAME[f.edition() - 1] : SpriteData.VARIANT_NAME[f.colorVariant()]) + (f.giant() ? " giant" : "") + (f.evo ? " - evolved" : ""),
             IconKit.FISH, [sp, f.evo, f.variant], FishDatabase.RARITY_COLOR[rar]],
            ["Level " + f.level().toString(), f.stageName() + " - " + f.fxp.toNumber().toString() + " fish XP", IconKit.GRID, SpriteData.ICON_STAR, null],
            ["Fed " + f.sat.toNumber().toString() + "%  Joy " + f.hap.toNumber().toString() + "%", "Health " + f.hp.toNumber().toString() + "%", IconKit.GRID, SpriteData.ICON_HEART, null],
            [FishDatabase.PERS_NAME[FishDatabase.PERS[sp]], "Personality", IconKit.NONE, null, null],
            ["Loves " + ItemDatabase.FOOD_NAME[FishDatabase.FAV[sp]], "Favorite food: double joy", IconKit.GRID, SpriteData.ICON_FEED, ItemDatabase.FOOD_COLOR[FishDatabase.FAV[sp]]],
            [tag == 0 ? "No special habitat" : "Likes " + FishDatabase.SYN_NAME[tag], f.syn ? "Synergy active +15 joy" : "Add it for a joy bonus", IconKit.GRID, f.syn ? SpriteData.ICON_CHECK : SpriteData.ICON_WAVE, f.syn ? 0x5EE36A : null]
        ];
        var n = out.size();
        out.add(["Train for racing", "Skill " + f.rs.toString() + " - 1 training point (" + e.tp.toString() + ")", IconKit.GRID, SpriteData.ICON_SHOE, null]);
        _actions.add(n);
        var ev = CollectionSystem.evolveReason(e, f);
        out.add(["Evolve", ev == null ? CollectionSystem.EVOLVE_PEARLS.toString() + " pearls" : ev, IconKit.GRID, SpriteData.ICON_STAR, ev == null ? 0xC77DFF : 0x8EA3C0]);
        _actions.add(n + 1);
        var br = CollectionSystem.breedReason(e, f);
        out.add(["Breed", br == null ? CollectionSystem.BREED_COST.toString() + "c - eggs in " + CollectionSystem.BREED_HOURS.toString() + "h" : br, IconKit.EGG, 5, br == null ? 0xFF8BEF : 0x8EA3C0]);
        _actions.add(n + 2);
        out.add(["Release", "+" + EconomySystem.releaseValue(sp).toString() + " coins", IconKit.NONE, null, 0xFF5A5A]);
        _actions.add(n + 3);
        return out;
    }

    function pick(i, view) {
        var e = Globals.engine;
        var f = fish();
        if (f == null) { return; }
        var a = _actions.indexOf(i);
        if (a == 0) {
            if (e.tp <= 0) { view.flash("Run to earn training points"); return; }
            if (f.rs >= 20) { view.flash("Max skill"); return; }
            e.tp -= 1;
            f.rs += 1;
            e.save();
            view.flash("Race skill " + f.rs.toString());
            view.refresh();
        } else if (a == 1) {
            var why = CollectionSystem.evolve(e, f);
            if (why == null) { Nav.toTank(); } else { view.flash(why); }
        } else if (a == 2) {
            var why = CollectionSystem.breedReason(e, f);
            if (why != null) { view.flash(why); return; }
            Nav.push(new BreedScreen(f.id));
        } else if (a == 3) {
            if (e.fish.size() <= 1) { view.flash("Keep at least one fish"); return; }
            Nav.push(new ConfirmScreen("Release " + f.name() + "?", method(:doRelease)));
        }
    }

    function doRelease() as Void {
        var v = Globals.engine.releaseFish(_id);
        Globals.engine.toast("Released, +" + v.toString() + " coins", 0xFFC93C);
        Nav.toTank();
    }
}

class BreedScreen extends Screen {
    var _id;
    var _partners;

    function initialize(id) {
        Screen.initialize();
        _id = id;
        _partners = [];
    }

    function title() {
        return "PICK A PARTNER";
    }

    function rows() {
        var e = Globals.engine;
        var a = e.fishById(_id);
        _partners = [];
        var out = [];
        if (a == null) { return out; }
        for (var i = 0; i < e.fish.size(); i++) {
            var b = e.fish[i];
            if (CollectionSystem.canPair(a, b)) {
                _partners.add(b.id);
                out.add([b.name(), "Joy " + b.hap.toNumber().toString() + "% - " + SpriteData.VARIANT_NAME[b.colorVariant()], IconKit.FISH, [b.sp, b.evo, b.variant], null]);
            }
        }
        return out;
    }

    function pick(i, view) {
        var e = Globals.engine;
        CollectionSystem.startBreed(e, e.fishById(_id), e.fishById(_partners[i]));
        Nav.toTank();
    }
}

// ---- Fishdex ---------------------------------------------------------------------------------
class DexGrid extends GridScreen {
    function initialize() {
        GridScreen.initialize();
    }

    function title() {
        return "FISHDEX " + Globals.engine.dexCount().toString() + "/" + FishDatabase.COUNT.toString();
    }

    function count() {
        return FishDatabase.COUNT;
    }

    function drawCell(dc, i, cx, cy, sel) {
        var known = Globals.engine.dex[i] != 0;
        if (SpriteData.peek(i, false) == null) { return false; }   // generated by warmNext
        IconKit.draw(dc, known ? IconKit.FISH : IconKit.SHADOW, known ? [i, false, 0] : i, cx, cy - 4, 2);
        var rc = FishDatabase.RARITY_COLOR[FishDatabase.RARITY[i]];
        PixelKit.rect(dc, known ? rc : 0x23314F, cx - 14, cy + 24, 28, 3);
        return true;
    }

    function warmNext(from, n) {
        for (var i = from; i < from + n && i < FishDatabase.COUNT; i++) {
            if (!SpriteData.warmSpecies(i)) { return; }
        }
    }

    function caption(i) {
        if (Globals.engine.dex[i] == 0) { return "??? - " + FishDatabase.HABITAT[FishDatabase.HAB[i]]; }
        return FishDatabase.NAME[i];
    }

    function captionColor(i) {
        return Globals.engine.dex[i] != 0 ? FishDatabase.RARITY_COLOR[FishDatabase.RARITY[i]] : 0x8EA3C0;
    }

    function pick(i, view) {
        Nav.push(new DexDetailScreen(i));
    }
}

class DexDetailScreen extends Screen {
    var _sp;

    function initialize(sp) {
        Screen.initialize();
        _sp = sp;
    }

    function title() {
        return Globals.engine.dex[_sp] != 0 ? FishDatabase.NAME[_sp].toUpper() : "UNDISCOVERED";
    }

    function rows() {
        var e = Globals.engine;
        var sp = _sp;
        var known = e.dex[sp] != 0;
        var rar = FishDatabase.RARITY[sp];
        var out = [[FishDatabase.RARITY_NAME[rar], FishDatabase.HABITAT[FishDatabase.HAB[sp]],
                    known ? IconKit.FISH : IconKit.SHADOW, known ? [sp, false, 0] : sp, FishDatabase.RARITY_COLOR[rar]]];
        if (known) {
            var tag = FishDatabase.SYN[sp];
            out.add([FishDatabase.PERS_NAME[FishDatabase.PERS[sp]], "Personality", IconKit.NONE, null, null]);
            out.add(["Loves " + ItemDatabase.FOOD_NAME[FishDatabase.FAV[sp]], "Favorite food", IconKit.GRID, SpriteData.ICON_FEED, null]);
            out.add([tag == 0 ? "Any habitat" : FishDatabase.SYN_NAME[tag], "Habitat synergy", IconKit.GRID, SpriteData.ICON_WAVE, null]);
        }
        var how = CollectionSystem.available(e, sp) ? "Shop or eggs" : CollectionSystem.gateText(e, sp);
        out.add(["Where to find", how, IconKit.GRID, SpriteData.ICON_MAP, null]);
        return out;
    }
}

// ---- Trophy Room --------------------------------------------------------------------------
class TrophyGrid extends GridScreen {
    function initialize() {
        GridScreen.initialize();
    }

    function title() {
        return "TROPHIES " + AchievementSystem.unlockedCount(Globals.engine).toString() + "/" + AchievementSystem.COUNT.toString();
    }

    function count() {
        return AchievementSystem.COUNT;
    }

    function drawCell(dc, i, cx, cy, sel) {
        var got = Globals.engine.ach[i] != 0;
        if (got) {
            IconKit.draw(dc, IconKit.GRID, SpriteData.ICON_TROPHY, cx, cy - 6, 4);
        } else {
            IconKit.draw(dc, IconKit.GRID, SpriteData.ICON_LOCK, cx, cy - 6, 3);
        }
        PixelKit.rect(dc, got ? 0xFFC93C : 0x23314F, cx - 14, cy + 24, 28, 3);
        return true;
    }

    function caption(i) {
        return AchievementSystem.NAME[i];
    }

    function captionColor(i) {
        return Globals.engine.ach[i] != 0 ? 0xFFC93C : 0x8EA3C0;
    }

    function pick(i, view) {
        Nav.push(new TrophyDetailScreen(i));
    }
}

class TrophyDetailScreen extends Screen {
    var _i;

    function initialize(i) {
        Screen.initialize();
        _i = i;
    }

    function title() {
        return "TROPHY";
    }

    function rows() {
        var got = Globals.engine.ach[_i] != 0;
        return [[AchievementSystem.NAME[_i], AchievementSystem.DESC[_i], IconKit.GRID, got ? SpriteData.ICON_TROPHY : SpriteData.ICON_LOCK, got ? 0xFFC93C : 0x8EA3C0],
                ["Reward", RewardSystem.summary(0, AchievementSystem.PEARLS[_i], 0), IconKit.GRID, SpriteData.ICON_PEARL, null]];
    }
}

// ---- Build mode decor picker -----------------------------------------------------------------
class DecorPickScreen extends Screen {
    var _slot;
    var _ids;

    function initialize(slot) {
        Screen.initialize();
        _slot = slot;
        _ids = [];
    }

    function title() {
        return "SLOT " + (_slot + 1).toString();
    }

    function footer() {
        return "Decor gives joy and habitat synergy";
    }

    function rows() {
        var e = Globals.engine;
        _ids = [-1];
        var out = [["Empty slot", e.placed[_slot] < 0 ? "Current" : "Remove decoration", IconKit.NONE, null, 0x8EA3C0]];
        for (var i = 0; i < e.decor.size(); i++) {
            var id = e.decor[i];
            _ids.add(id);
            var where = "Available";
            if (e.placed[_slot] == id) { where = "In this slot"; }
            else if (HabitatSystem.isPlaced(e, id)) { where = "Move here"; }
            var tag = ItemDatabase.DECOR_TAG[id];
            if (tag > 0) { where = where + " - " + FishDatabase.SYN_NAME[tag]; }
            out.add([ItemDatabase.DECOR_NAME[id], where, IconKit.DECOR, id, null]);
        }
        return out;
    }

    function pick(i, view) {
        HabitatSystem.place(Globals.engine, _slot, _ids[i]);
        Nav.pop();
    }
}

// ---- Expedition map ----------------------------------------------------------------------------
class ExpeditionView extends WatchUi.View {
    // node positions down the round screen (zig-zag trail)
    const NX = [195, 120, 270, 130, 250];
    const NY = [300, 248, 196, 144, 96];
    var sel;

    function initialize() {
        View.initialize();
        sel = ExpeditionSystem.unlocked(Globals.engine);
    }

    function move(d) {
        sel = Util.clamp(sel + d, 0, 4);
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var e = Globals.engine;
        UIKit.background(dc);
        UIKit.titlePill(dc, "EXPEDITION", UIKit.ACCENT);
        var u = ExpeditionSystem.unlocked(e);
        // dotted trail
        for (var i = 0; i < 4; i++) {
            var col = i < u ? 0x7FE7FF : 0x2A4A7A;
            for (var k = 1; k < 8; k++) {
                var x = NX[i] + (NX[i + 1] - NX[i]) * k / 8;
                var y = NY[i] + (NY[i + 1] - NY[i]) * k / 8;
                PixelKit.rect(dc, col, x - 2, y - 2, 4, 4);
            }
        }
        for (var i = 0; i < 5; i++) {
            var open = i <= u;
            var r = i == sel ? 20 : 15;
            dc.setColor(open ? ExpeditionSystem.COLOR[i] : 0x1A2238, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(NX[i], NY[i], r);
            dc.setColor(i == sel ? 0xFFFFFF : UIKit.BORDER, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawCircle(NX[i], NY[i], r);
            dc.setPenWidth(1);
            IconKit.draw(dc, IconKit.GRID, open ? SpriteData.ICON_WAVE : SpriteData.ICON_LOCK, NX[i], NY[i], 2);
        }
        // details of the selected region
        var km = e.stats["km"] / 1000.0;
        var need = ExpeditionSystem.KM[sel];
        var line2 = sel <= u ? ExpeditionSystem.DESC[sel] : km.format("%.1f") + " / " + need.toString() + " km";
        var by = (dc.getHeight() * 0.86).toNumber();
        dc.setColor(UIKit.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(95, by - 26, 200, 50, 12);
        dc.setColor(ExpeditionSystem.COLOR[sel], Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(95, by - 26, 200, 50, 12);
        UIKit.text(dc, 195, by - 10, UIKit.font(0), ExpeditionSystem.NAME[sel], ExpeditionSystem.COLOR[sel], UIKit.CENTER);
        UIKit.text(dc, 195, by + 11, UIKit.font(0), UIKit.fit(dc, line2, UIKit.font(0), 184), UIKit.DIM, UIKit.CENTER);
    }
}

class ExpeditionDelegate extends WatchUi.BehaviorDelegate {
    var _v;

    function initialize(v) {
        BehaviorDelegate.initialize();
        _v = v;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var c = evt.getCoordinates();
        for (var i = 0; i < 5; i++) {
            var dx = c[0] - _v.NX[i];
            var dy = c[1] - _v.NY[i];
            if (dx * dx + dy * dy < 26 * 26) { _v.sel = i; WatchUi.requestUpdate(); }
        }
        return true;
    }

    function onNextPage() as Boolean {
        _v.move(-1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _v.move(1);
        return true;
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        var d = evt.getDirection();
        if (d == WatchUi.SWIPE_UP) { _v.move(1); return true; }
        if (d == WatchUi.SWIPE_DOWN) { _v.move(-1); return true; }
        if (d == WatchUi.SWIPE_RIGHT) { Nav.pop(); return true; }
        return false;
    }

    function onBack() as Boolean {
        Nav.pop();
        return true;
    }
}
