import Toybox.Lang;
import Toybox.WatchUi;

function balanceLine(e) {
    return e.coins.toString() + "c  " + e.pearls.toString() + " pearls  " + e.keys.toString() + " keys";
}

// ---- Main menu ---------------------------------------------------------------------
class MainScreen extends Screen {
    function initialize() {
        Screen.initialize();
    }

    function title() {
        return "FISH TANK";
    }

    function footer() {
        return balanceLine(Globals.engine);
    }

    function rows() {
        var e = Globals.engine;
        var q = QuestSystem.openCount(e);
        var ready = 0;
        for (var i = 0; i < e.eggs.size(); i++) { if (CollectionSystem.eggReady(e.eggs[i])) { ready++; } }
        return [
            ["Shop", "Fish, eggs, food, decor", IconKit.GRID, SpriteData.ICON_SHOP, null],
            ["Inventory", ready > 0 ? ready.toString() + " egg ready to hatch!" : "Eggs, keys, food", IconKit.GRID, SpriteData.ICON_BAG, ready > 0 ? 0xFFE9A0 : null],
            ["My Fish", e.fish.size().toString() + "/" + HabitatSystem.capacity(e).toString() + " in tank", IconKit.GRID, SpriteData.ICON_FISH, null],
            ["Quests", q > 0 ? q.toString() + " open" : "All done!", IconKit.GRID, SpriteData.ICON_QUEST, q > 0 ? 0x9BF08A : null],
            ["Events", eventLine(e), IconKit.GRID, SpriteData.ICON_STAR, e.events.size() > 0 ? EventSystem.UI[e.events[0][0]] : null],
            ["Activity", ActivitySystem.fmtKm(e.stats["km"]) + " km run", IconKit.GRID, SpriteData.ICON_SHOE, null],
            ["Expedition", ExpeditionSystem.NAME[ExpeditionSystem.unlocked(e)], IconKit.GRID, SpriteData.ICON_MAP, null],
            ["Games", "Bubble Pop, Dive, Racing", IconKit.GRID, SpriteData.ICON_GAME, null],
            ["Fishdex", e.dexCount().toString() + "/" + FishDatabase.COUNT.toString() + " discovered", IconKit.GRID, SpriteData.ICON_DEX, null],
            ["Trophies", AchievementSystem.unlockedCount(e).toString() + "/" + AchievementSystem.COUNT.toString() + " unlocked", IconKit.GRID, SpriteData.ICON_TROPHY, null],
            ["League", LeagueSystem.TIER_NAME[leagueTier(e)], IconKit.GRID, SpriteData.ICON_SHIELD, null],
            ["Build", "Place decorations", IconKit.GRID, SpriteData.ICON_BUILD, null],
            ["Profile", "LV " + e.lv.toString() + " " + ProgressionSystem.title(e.lv), IconKit.GRID, SpriteData.ICON_PROFILE, null],
            ["Settings", "Style, theme, controls", IconKit.GRID, SpriteData.ICON_GEAR, null]
        ];
    }

    function eventLine(e) {
        if (e.events.size() > 0) { return EventSystem.NAME[e.events[0][0]] + " is on!"; }
        return WeeklySystem.NAME[WeeklySystem.current(TimeUtil.weekOf(TimeUtil.today()))];
    }

    function leagueTier(e) {
        var t = e.league.get("t");
        return t == null ? 0 : t;
    }

    function pick(i, view) {
        if (i == 0) { Nav.push(new ShopScreen()); }
        else if (i == 1) { Nav.push(new InventoryScreen()); }
        else if (i == 2) { Nav.push(new MyFishScreen()); }
        else if (i == 3) { Nav.push(new QuestScreen()); }
        else if (i == 4) { Nav.push(new EventsScreen()); }
        else if (i == 5) { Nav.push(new ActivityScreen()); }
        else if (i == 6) { var v = new ExpeditionView(); Nav.pushView(v, new ExpeditionDelegate(v)); }
        else if (i == 7) { Nav.push(new GamesScreen()); }
        else if (i == 8) { Nav.pushGrid(new DexGrid()); }
        else if (i == 9) { Nav.pushGrid(new TrophyGrid()); }
        else if (i == 10) { Nav.push(new LeagueScreen()); }
        else if (i == 11) { Nav.toTank(); Globals.view.enterBuild(); }
        else if (i == 12) { Nav.push(new ProfileScreen()); }
        else { Nav.push(new SettingsScreen()); }
    }
}

// ---- Shop ---------------------------------------------------------------------------
class ShopScreen extends Screen {
    function initialize() {
        Screen.initialize();
    }

    function title() {
        return "SHOP";
    }

    function footer() {
        return balanceLine(Globals.engine);
    }

    function rows() {
        var e = Globals.engine;
        var nxt = e.alv < HabitatSystem.MAX_ALV ? "Upgrade to LV " + (e.alv + 1).toString() : "Max size";
        return [
            ["Fish", ThemeDatabase.NAME[e.theme], IconKit.GRID, SpriteData.ICON_FISH, null],
            ["Eggs", "Hatch a surprise", IconKit.EGG, 1, null],
            ["Food", "Pellets & treats", IconKit.GRID, SpriteData.ICON_FEED, null],
            ["Decor", "Plants, coral, ornaments", IconKit.DECOR, 1, null],
            ["Tank", nxt, IconKit.GRID, SpriteData.ICON_BUILD, null],
            ["Treasure Key", EconomySystem.KEY_PEARLS.toString() + " pearls each", IconKit.GRID, SpriteData.ICON_KEY, null]
        ];
    }

    function pick(i, view) {
        if (i == 0) { Nav.push(new ShopFishScreen()); }
        else if (i == 1) { Nav.push(new ShopEggScreen()); }
        else if (i == 2) { Nav.push(new ShopFoodScreen()); }
        else if (i == 3) { Nav.push(new ShopDecorScreen()); }
        else if (i == 4) { Nav.push(new ShopTankScreen()); }
        else {
            var why = Globals.engine.buyKey();
            view.flash(why == null ? "+1 treasure key" : why);
            view.refresh();
        }
    }
}

class ShopFishScreen extends Screen {
    var _pool;

    function initialize() {
        Screen.initialize();
        _pool = FishDatabase.pool(Globals.engine.theme);
    }

    function title() {
        var e = Globals.engine;
        return "FISH " + e.fish.size().toString() + "/" + HabitatSystem.capacity(e).toString();
    }

    function footer() {
        return balanceLine(Globals.engine);
    }

    function rows() {
        var e = Globals.engine;
        var out = [];
        for (var i = 0; i < _pool.size(); i++) {
            var sp = _pool[i];
            var rar = FishDatabase.RARITY[sp];
            var open = CollectionSystem.available(e, sp) && e.lv >= FishDatabase.unlockLevel(sp);
            var sub;
            if (!CollectionSystem.available(e, sp)) { sub = CollectionSystem.gateText(e, sp); }
            else if (e.lv < FishDatabase.unlockLevel(sp)) { sub = "Unlocks at LV " + FishDatabase.unlockLevel(sp).toString(); }
            else {
                var pr = e.fishPrice(sp);
                sub = FishDatabase.RARITY_NAME[rar] + " - " + pr.toString() + "c" + (pr < FishDatabase.price(sp) ? " SALE" : "");
                if (FishDatabase.pearlPrice(sp) > 0) { sub = sub + " + " + FishDatabase.pearlPrice(sp).toString() + "p"; }
            }
            var known = e.dex[sp] != 0;
            out.add([known || open ? FishDatabase.NAME[sp] : "???", sub,
                     known || open ? IconKit.FISH : IconKit.SHADOW, known || open ? [sp, false, 0] : sp,
                     open ? FishDatabase.RARITY_COLOR[rar] : 0x8EA3C0]);
        }
        return out;
    }

    function pick(i, view) {
        var msg = Globals.engine.buyFish(_pool[i]);
        if (msg == null) { Nav.toTank(); }
        else { view.flash(msg); }
    }
}

class ShopEggScreen extends Screen {
    function initialize() {
        Screen.initialize();
    }

    function title() {
        return "EGGS";
    }

    function footer() {
        return balanceLine(Globals.engine);
    }

    function rows() {
        return [
            [CollectionSystem.EGG_NAME[0], CollectionSystem.EGG_PRICE_C[0].toString() + "c - mostly common", IconKit.EGG, 0, null],
            [CollectionSystem.EGG_NAME[1], CollectionSystem.EGG_PRICE_P[1].toString() + " pearls - rare or better", IconKit.EGG, 1, 0x4FA3FF]
        ];
    }

    function pick(i, view) {
        var why = Globals.engine.buyEgg(i);
        view.flash(why == null ? "Egg added - run to hatch it faster" : why);
    }
}

class ShopFoodScreen extends Screen {
    function initialize() {
        Screen.initialize();
    }

    function title() {
        return "FOOD";
    }

    function footer() {
        return balanceLine(Globals.engine);
    }

    function rows() {
        var e = Globals.engine;
        var out = [];
        for (var i = 1; i < ItemDatabase.FOOD_NAME.size(); i++) {
            out.add([ItemDatabase.FOOD_NAME[i] + " x" + ItemDatabase.FOOD_PACK_QTY[i].toString(),
                     e.foodPrice(i).toString() + "c - have " + e.food[i].toString(),
                     IconKit.GRID, SpriteData.ICON_FEED, ItemDatabase.FOOD_COLOR[i]]);
        }
        return out;
    }

    function pick(i, view) {
        var why = Globals.engine.buyFood(i + 1);
        view.flash(why == null ? "Bought!" : why);
        view.refresh();
    }
}

class ShopDecorScreen extends Screen {
    function initialize() {
        Screen.initialize();
    }

    function title() {
        return "DECOR";
    }

    function footer() {
        return balanceLine(Globals.engine);
    }

    function rows() {
        var e = Globals.engine;
        var out = [];
        for (var i = 0; i < ItemDatabase.DECOR_COUNT; i++) {
            var why = e.decorReason(i);
            var tag = ItemDatabase.DECOR_TAG[i];
            var sub = why == null ? ItemDatabase.DECOR_PRICE[i].toString() + "c" : why;
            if (why == null && tag > 0) { sub = sub + " - " + FishDatabase.SYN_NAME[tag]; }
            out.add([ItemDatabase.DECOR_NAME[i], sub, IconKit.DECOR, i, why == null || why.equals("Owned") ? null : 0x8EA3C0]);
        }
        return out;
    }

    function pick(i, view) {
        var why = Globals.engine.buyDecor(i);
        if (why == null) { Nav.toTank(); }
        else { view.flash(why); }
    }
}

class ShopTankScreen extends Screen {
    function initialize() {
        Screen.initialize();
    }

    function title() {
        return "TANK LV " + Globals.engine.alv.toString();
    }

    function footer() {
        return balanceLine(Globals.engine);
    }

    function rows() {
        var e = Globals.engine;
        var out = [];
        if (e.alv < HabitatSystem.MAX_ALV) {
            var n = e.alv;
            var why = HabitatSystem.upgradeReason(e);
            var cost = HabitatSystem.ALV_PRICE[n].toString() + "c";
            if (HabitatSystem.ALV_PEARLS[n] > 0) { cost = cost + " + " + HabitatSystem.ALV_PEARLS[n].toString() + "p"; }
            out.add(["Upgrade to LV " + (n + 1).toString(), why == null ? cost : why, IconKit.GRID, SpriteData.ICON_BUILD, why == null ? 0x7FE7FF : 0x8EA3C0]);
        }
        out.add(["Capacity", HabitatSystem.capacity(e).toString() + " fish", IconKit.GRID, SpriteData.ICON_FISH, null]);
        out.add(["Decor slots", HabitatSystem.slotCount(e).toString(), IconKit.DECOR, 0, null]);
        out.add(["Incubators", CollectionSystem.incubatorSlots(e).toString(), IconKit.EGG, 0, null]);
        return out;
    }

    function pick(i, view) {
        if (i != 0 || Globals.engine.alv >= HabitatSystem.MAX_ALV) { return; }
        var why = HabitatSystem.upgrade(Globals.engine);
        if (why == null) { Nav.toTank(); }
        else { view.flash(why); }
    }
}

// ---- Inventory -----------------------------------------------------------------------
class InventoryScreen extends Screen {
    var _map;

    function initialize() {
        Screen.initialize();
        _map = [];
    }

    function title() {
        return "INVENTORY";
    }

    function footer() {
        return "Tap an item to use it";
    }

    function rows() {
        var e = Globals.engine;
        var out = [];
        _map = [];
        for (var i = 0; i < e.eggs.size(); i++) {
            var egg = e.eggs[i];
            var sub;
            if (CollectionSystem.eggReady(egg)) { sub = "READY - tap to hatch"; }
            else {
                var km = egg[1] > 0 ? egg[1] : 0.0;
                var hrs = egg[2] > 0 ? (egg[2] + 3599) / 3600 : 0;
                sub = km.format("%.1f") + " km or " + hrs.toString() + "h left";
            }
            out.add([CollectionSystem.EGG_NAME[egg[0]], sub, IconKit.EGG, egg[0], CollectionSystem.eggReady(egg) ? 0xFFE9A0 : null]);
            _map.add([0, i]);
        }
        if (e.eggBag.size() > 0) {
            out.add(["Egg bag", e.eggBag.size().toString() + " waiting for an incubator", IconKit.EGG, e.eggBag[0][0], null]);
            _map.add([1, 0]);
        }
        out.add(["Treasure keys", e.keys.toString() + (e.keys > 0 ? " - tap to open a chest" : ""), IconKit.GRID, SpriteData.ICON_KEY, e.keys > 0 ? 0xFFC93C : null]);
        _map.add([2, 0]);
        out.add(["Pearls", e.pearls.toString(), IconKit.GRID, SpriteData.ICON_PEARL, null]);
        _map.add([1, 0]);
        out.add(["Coins", e.coins.toString(), IconKit.GRID, SpriteData.ICON_COIN, null]);
        _map.add([1, 0]);
        out.add(["Training points", e.tp.toString() + " - from running", IconKit.GRID, SpriteData.ICON_SHOE, null]);
        _map.add([1, 0]);
        for (var i = 0; i < ItemDatabase.FOOD_NAME.size(); i++) {
            var cnt = i == 0 ? "unlimited" : "x" + e.food[i].toString();
            var sub = (e.selFood == i ? "IN USE - " : "tap to use - ") + cnt;
            out.add([ItemDatabase.FOOD_NAME[i], sub, IconKit.GRID, SpriteData.ICON_FEED, ItemDatabase.FOOD_COLOR[i]]);
            _map.add([3, i]);
        }
        out.add(["Decorations", e.decor.size().toString() + " owned - tap to build", IconKit.DECOR, 4, null]);
        _map.add([4, 0]);
        return out;
    }

    function pick(i, view) {
        var e = Globals.engine;
        var m = _map[i];
        if (m[0] == 0) {
            var why = CollectionSystem.hatch(e, m[1]);
            if (why == null) { Nav.toTank(); } else { view.flash(why); }
        } else if (m[0] == 2) {
            var why = CollectionSystem.openChest(e);
            if (why == null) { Nav.toTank(); } else { view.flash(why); }
        } else if (m[0] == 3) {
            if (m[1] > 0 && e.food[m[1]] <= 0) { view.flash("None left - buy in Shop"); return; }
            e.selFood = m[1];
            e.save();
            view.refresh();
        } else if (m[0] == 4) {
            Nav.toTank();
            Globals.view.enterBuild();
        }
    }
}

// ---- Settings ------------------------------------------------------------------------
class SettingsScreen extends Screen {
    function initialize() {
        Screen.initialize();
    }

    function title() {
        return "SETTINGS";
    }

    function onOff(b) {
        return b ? "On" : "Off";
    }

    function rows() {
        var e = Globals.engine;
        return [
            ["Art Style", CustomizationManager.STYLE_NAME[e.style], IconKit.GRID, SpriteData.ICON_STAR, null],
            ["Aquarium Theme", ThemeDatabase.NAME[e.theme], IconKit.GRID, SpriteData.ICON_WAVE, null],
            ["Vibration", onOff(e.haptics), IconKit.NONE, null, null],
            ["Low Animation", onOff(e.lowAnim) + " - saves battery", IconKit.NONE, null, null],
            ["Tap Water to Feed", onOff(e.tapFeed), IconKit.NONE, null, null],
            ["Race Day", e.race > 0 ? CalendarUtil.fmtYear(e.race) : "Not set", IconKit.GRID, SpriteData.ICON_SHOE, null],
            ["Birthday", e.bday.size() == 2 ? e.bday[1].toString() + " " + CalendarUtil.MONTHS[e.bday[0] - 1] : "Not set", IconKit.GRID, SpriteData.ICON_STAR, null],
            ["Ramadan / Eid dates", "Shift " + (e.hijriShift > 0 ? "+" : "") + e.hijriShift.toString() + " days", IconKit.NONE, null, null],
            ["Replay Tutorial", "Show the basics again", IconKit.NONE, null, null],
            ["Reset Progress", "Start a new tank", IconKit.NONE, null, 0xFF5A5A]
        ];
    }

    function pick(i, view) {
        var e = Globals.engine;
        if (i == 0) { Nav.toTank(); Globals.view.enterPicker(Modes.STYLE, false); }
        else if (i == 1) { Nav.toTank(); Globals.view.enterPicker(Modes.THEME, false); }
        else if (i == 2) { e.haptics = !e.haptics; }
        else if (i == 3) { e.lowAnim = !e.lowAnim; Globals.view.applyTimer(); }
        else if (i == 4) { e.tapFeed = !e.tapFeed; }
        else if (i == 5) { var v = new DatePickerView(DatePick.RACE); Nav.pushView(v, new DatePickerDelegate(v)); return; }
        else if (i == 6) {
            if (e.bday.size() == 2) { view.flash("Birthday is set"); return; }
            var v = new DatePickerView(DatePick.BIRTHDAY); Nav.pushView(v, new DatePickerDelegate(v)); return;
        }
        else if (i == 7) { e.hijriShift = e.hijriShift >= 2 ? -2 : e.hijriShift + 1; EventSystem.refresh(e); }
        else if (i == 8) { e.tutorial = 0; Nav.toTank(); }
        else { Nav.push(new ConfirmScreen("Erase fish, coins and level?", method(:doReset))); return; }
        e.save();
        view.refresh();
    }

    function doReset() as Void {
        Globals.engine.resetAll();
        Nav.toTank();
    }
}

// ---- Profile ------------------------------------------------------------------------
class ProfileScreen extends Screen {
    function initialize() {
        Screen.initialize();
    }

    function title() {
        return "PROFILE";
    }

    function rows() {
        var e = Globals.engine;
        var need = ProgressionSystem.need(e.lv);
        var t = e.league.get("t") == null ? 0 : e.league["t"];
        return [
            [ProgressionSystem.title(e.lv), "LV " + e.lv.toString() + (e.lv >= ProgressionSystem.MAX_LV ? " - max" : " - " + e.xp.toString() + "/" + need.toString() + " XP"), IconKit.GRID, SpriteData.ICON_PROFILE, 0x7FE7FF],
            ["Aquarium rating", HabitatSystem.rating(e).format("%.1f") + " / 5 stars", IconKit.GRID, SpriteData.ICON_STAR, 0xFFC93C],
            ["Aquarium LV " + e.alv.toString(), e.fish.size().toString() + "/" + HabitatSystem.capacity(e).toString() + " fish - " + HabitatSystem.synergyCount(e).toString() + " in synergy", IconKit.GRID, SpriteData.ICON_BUILD, null],
            ["League", LeagueSystem.TIER_NAME[t], IconKit.GRID, SpriteData.ICON_SHIELD, LeagueSystem.TIER_COLOR[t]],
            ["Expedition", ExpeditionSystem.NAME[ExpeditionSystem.unlocked(e)], IconKit.GRID, SpriteData.ICON_MAP, null],
            ["Distance", ActivitySystem.fmtKm(e.stats["km"]) + " km in " + e.stats["runs"].toString() + " runs", IconKit.GRID, SpriteData.ICON_SHOE, null],
            ["Fishdex", e.dexCount().toString() + "/" + FishDatabase.COUNT.toString(), IconKit.GRID, SpriteData.ICON_DEX, null],
            ["Trophies", AchievementSystem.unlockedCount(e).toString() + "/" + AchievementSystem.COUNT.toString(), IconKit.GRID, SpriteData.ICON_TROPHY, null]
        ];
    }
}

// ---- Quests -----------------------------------------------------------------------------
class QuestScreen extends Screen {
    function initialize() {
        Screen.initialize();
        QuestSystem.check(Globals.engine);
    }

    function title() {
        return "QUESTS";
    }

    function footer() {
        var e = Globals.engine;
        var m = e.wk.get("m");
        var days = m == null ? 0 : ActivitySystem.bits(m);
        return "Active days " + days.toString() + "/" + ActivitySystem.WEEK_TARGET.toString();
    }

    function progress(type, v, target) {
        if (type == QuestSystem.Q_RUN_KM) { return ActivitySystem.fmtKm(v) + "/" + ActivitySystem.fmtKm(target) + " km"; }
        if (type == QuestSystem.Q_STEPS) { return Util.thousands(v) + "/" + Util.thousands(target); }
        return v.toString() + "/" + target.toString();
    }

    function rows() {
        var e = Globals.engine;
        var q = e.quests;
        var out = [];
        if (q.get("di") == null) { return out; }
        for (var d = 0; d < 2; d++) {
            var daily = d == 0;
            for (var i = 0; i < 3; i++) {
                var t = daily ? QuestSystem.DAILY[q["di"][i]] : QuestSystem.WEEKLY[q["wi"][i]];
                var v = q[daily ? "dp" : "wp"][i];
                if (v > t[1]) { v = t[1]; }
                var done = QuestSystem.isDone(e, daily, i);
                var reward = t[2].toString() + "c";
                if (!daily && t[3] > 0) { reward = reward + " +key"; }
                if (!daily && t[4] > 0) { reward = reward + " +" + t[4].toString() + "p"; }
                var sub = (daily ? "Today " : "Week ") + (done ? "- done!" : progress(t[0], v, t[1]) + " - " + reward);
                out.add([QuestSystem.label(t[0], t[1]), sub, IconKit.GRID, done ? SpriteData.ICON_CHECK : SpriteData.ICON_QUEST, done ? 0x5EE36A : null]);
            }
        }
        return out;
    }
}

// ---- Activity Journal ------------------------------------------------------------------
class ActivityScreen extends Screen {
    function initialize() {
        Screen.initialize();
    }

    function title() {
        return "ACTIVITY";
    }

    function footer() {
        return ActivitySystem.fallbackMode(Globals.engine) ? "Counting daily distance" : "Runs from your Run app";
    }

    function rows() {
        var e = Globals.engine;
        var s = e.stats;
        var today = e.ds.get(TimeUtil.today());
        var nextMs = "All step milestones done";
        for (var i = 0; i < ActivitySystem.STEP_MS.size(); i++) {
            if (today == null || today < ActivitySystem.STEP_MS[i]) {
                nextMs = Util.thousands(ActivitySystem.STEP_MS[i]) + " steps: +" + ActivitySystem.STEP_COINS[i].toString() + "c";
                break;
            }
        }
        var nextKm = "All milestones done";
        for (var i = 0; i < ActivitySystem.KM_MS.size(); i++) {
            if (s["km"] / 1000 < ActivitySystem.KM_MS[i]) { nextKm = ActivitySystem.KM_MS[i].toString() + " km: +" + ActivitySystem.KM_PEARLS[i].toString() + " pearls"; break; }
        }
        var td = ActivitySystem.logDay(e, TimeUtil.today());
        var tw = ActivitySystem.logWeek(e, TimeUtil.today());
        return [
            ["This week", ActivitySystem.fmtKm(tw[0]) + " km - " + tw[1].toString() + " run" + (tw[1] == 1 ? "" : "s"), IconKit.GRID, SpriteData.ICON_SHOE, 0x7FE7FF],
            ["Today", ActivitySystem.fmtKm(td[0]) + " km - " + td[1].toString() + " run" + (td[1] == 1 ? "" : "s"), IconKit.GRID, SpriteData.ICON_SHOE, null],
            ["Total distance", ActivitySystem.fmtKm(s["km"]) + " km", IconKit.GRID, SpriteData.ICON_SHOE, 0x7FE7FF],
            ["Next milestone", nextKm, IconKit.GRID, SpriteData.ICON_TROPHY, null],
            ["Runs", s["runs"].toString() + " - " + ActivitySystem.fmtTime(s["dur"]) + " total", IconKit.GRID, SpriteData.ICON_SHOE, null],
            ["Steps today", (today == null ? "0" : Util.thousands(today)), IconKit.GRID, SpriteData.ICON_STEPS, null],
            ["Step goal", nextMs, IconKit.GRID, SpriteData.ICON_STEPS, null],
            ["Longest run", ActivitySystem.fmtKm(s["long"]) + " km", IconKit.GRID, SpriteData.ICON_TROPHY, null],
            ["Best pace", ActivitySystem.fmtPace(s["pace"]) + " /km", IconKit.GRID, SpriteData.ICON_STAR, null],
            ["Best 5K", s["b5"] > 0 ? ActivitySystem.fmtTime(s["b5"]) : "--", IconKit.GRID, SpriteData.ICON_STAR, null],
            ["Best 10K", s["b10"] > 0 ? ActivitySystem.fmtTime(s["b10"]) : "--", IconKit.GRID, SpriteData.ICON_STAR, null],
            ["Best step day", Util.thousands(s["steps"]), IconKit.GRID, SpriteData.ICON_STEPS, null],
            ["Consistency", e.streakWeeks().toString() + " week streak - run bonus x" + (1.0 + 0.1 * (e.streakWeeks() > 5 ? 5 : e.streakWeeks())).format("%.1f"), IconKit.GRID, SpriteData.ICON_STAR, null],
            ["Coins from activity", s["ac"].toString() + "c", IconKit.GRID, SpriteData.ICON_COIN, 0xFFC93C],
            ["Daily distance credit", s["fkm"] > 0 ? ActivitySystem.fmtKm(s["fkm"]) + " km (50%)" : "Off - runs come from history",
             IconKit.GRID, SpriteData.ICON_STEPS, null],
            ["How it works", "100 m = 1 coin, max 300/day", IconKit.NONE, null, 0x8EA3C0]
        ];
    }
}

// ---- Games -------------------------------------------------------------------------------
class GamesScreen extends Screen {
    function initialize() {
        Screen.initialize();
    }

    function title() {
        return "GAMES";
    }

    function footer() {
        return MiniGameRules.DAILY.toString() + " rewarded plays a day";
    }

    function sub(game, best) {
        var left = Globals.engine.gamesLeft(game);
        var s = (left > 0 ? left.toString() + " plays left" : "Practice only") + best;
        return game.equals(Mods.spotlight) ? "2x COINS - " + s : s;
    }

    function rows() {
        var s = Globals.engine.stats;
        return [
            ["Bubble Pop", sub("bp", " - best " + s["bub"].toString()), IconKit.GRID, SpriteData.ICON_WAVE, null],
            ["Treasure Dive", sub("td", " - depth " + s["dive"].toString()), IconKit.GRID, SpriteData.ICON_CHEST, null],
            ["Fish Racing", sub("fr", " - " + s["raceW"].toString() + " wins"), IconKit.GRID, SpriteData.ICON_FISH, null]
        ];
    }

    function pick(i, view) {
        if (i == 0) { var v = new BubblePopView(); Nav.pushView(v, new MiniGameDelegate(v)); }
        else if (i == 1) { var v = new TreasureDiveView(); Nav.pushView(v, new MiniGameDelegate(v)); }
        else {
            if (Globals.engine.fish.size() == 0) { view.flash("No fish to race"); return; }
            Nav.push(new RacePickScreen());
        }
    }
}

class RacePickScreen extends Screen {
    function initialize() {
        Screen.initialize();
    }

    function title() {
        return "PICK A RACER";
    }

    function footer() {
        return Globals.engine.tp.toString() + " training points - train in My Fish";
    }

    function rows() {
        var e = Globals.engine;
        var out = [];
        for (var i = 0; i < e.fish.size(); i++) {
            var f = e.fish[i];
            out.add([f.name(), "Speed " + FishRace.racerSpeed(f).format("%.0f") + " - skill " + f.rs.toString(),
                     IconKit.FISH, [f.sp, f.evo, f.variant], null]);
        }
        return out;
    }

    function pick(i, view) {
        Nav.pop();
        var v = new FishRaceView(Globals.engine.fish[i]);
        Nav.pushView(v, new MiniGameDelegate(v));
    }
}

// ---- League --------------------------------------------------------------------------------
class LeagueScreen extends Screen {
    function initialize() {
        Screen.initialize();
        LeagueSystem.ensure(Globals.engine);
        LeagueSystem.check(Globals.engine);
    }

    function title() {
        return "LEAGUE";
    }

    function footer() {
        return "Resets every Monday";
    }

    function rows() {
        var e = Globals.engine;
        var lg = e.league;
        var t = lg["t"];
        var tgt = LeagueSystem.target(e);
        var s = lg["s"];
        var out = [
            [LeagueSystem.TIER_NAME[t] + " League", "Rival: your past weeks", IconKit.GRID, SpriteData.ICON_SHIELD, LeagueSystem.TIER_COLOR[t]],
            ["This week", s.toString() + " / " + tgt.toString() + " pts" + (s >= tgt ? " - promotion!" : ""), IconKit.GRID, SpriteData.ICON_STAR, s >= tgt ? 0x5EE36A : null],
            ["Week reward", RewardSystem.summary(LeagueSystem.REWARD_C[t], LeagueSystem.REWARD_P[t], 0), IconKit.GRID, SpriteData.ICON_CHEST, null],
            ["Points", "10/km, 15/active day, 20 per quest", IconKit.NONE, null, 0x8EA3C0]
        ];
        var h = lg["h"];
        for (var i = h.size() - 1; i >= 0; i--) {
            out.add(["Past week", h[i].toString() + " pts", IconKit.NONE, null, 0x8EA3C0]);
        }
        return out;
    }
}
