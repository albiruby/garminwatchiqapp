import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;

// Owns all game state and the per-frame simulation. Views only read from it; gameplay
// rules live in the *System modules.
class AquariumEngine {
    // ---- persistent ----
    var onboarded = false;
    var style = 0;
    var theme = 3;
    var coins = 50;
    var coinFrac = 0.0;
    var lv = 1;
    var xp = 0;
    var clean = 100.0;
    var fish;
    var decor;          // owned decoration ids
    var placed;         // decoration id per slot, -1 empty
    var food;
    var selFood = 0;
    var lastSeen = 0;
    var rewardDay = 0;
    var streak = 0;     // daily gift streak
    var dex;            // 0/1 per species
    var haptics = true;
    var pearls = 0;
    var keys = 0;
    var alv = 1;
    var tp = 0;         // training points (1 per km run)
    var installTime = 0;
    var nid = 1;
    var tx;             // reward ledger
    var stats;
    var stp;            // [day, step milestone mask]
    var ds;             // {day => steps}
    var quests;
    var ach;
    var league;
    var wk;             // consistency week
    var rc;             // [day, run coins paid]
    var dd;             // fallback daily distance [day, meters paid, coins]
    var eggs;           // incubator
    var eggBag;
    var breed;
    var mg;             // mini-game limits and bests per day
    var lowAnim = false;
    var tapFeed = true;
    var tutorial = 0;
    var expSeen = 0;

    // ---- runtime ----
    var renderer;
    var preview = null;          // demo fish shown during onboarding
    var foods;
    var bubbles;                 // [x, y, r, vy, phase]
    var parts;                   // [x, y, vx, vy, life, color, kind]
    var pops;                    // [x, y, text, life, color]
    var cards;                   // reward / info cards (RewardSystem.card)
    var toastText = null;
    var toastCol = 0xFFFFFF;
    var toastT = 0.0;
    var infoFish = null;
    var infoT = 0.0;
    var cleanT = -1.0;
    var cleanReward = false;
    var sceneDirty = true;
    var achDirty = false;
    var scanIt = null;
    var pendingRuns;
    var t = 0.0;
    var _minuteAcc = 0.0;
    var _bubbleAcc = 0.0;
    var _cleanBucket = 10;

    function initialize() {
        fish = [];
        decor = [];
        placed = [-1, -1, -1, -1, -1, -1];
        food = [0, 3, 1];
        foods = [];
        bubbles = [];
        parts = [];
        pops = [];
        cards = [];
        pendingRuns = [];
        tx = {};
        stats = SaveManager.newStats();
        dex = SaveManager.newDex();
        ach = SaveManager.newAch();
        stp = [0, 0];
        ds = {};
        quests = {};
        league = {};
        wk = {};
        rc = [0, 0];
        dd = [0, 0, 0];
        eggs = [];
        eggBag = [];
        breed = [];
        mg = {};
        renderer = CustomizationManager.renderer(0);
    }

    // ---- persistence ---------------------------------------------------------
    function load() {
        var d = Preview.ON ? null : SaveManager.load();
        if (d == null) { d = SaveManager.defaults(); }
        fromDict(d);
        if (Preview.ON) { applyPreview(); }
        renderer = CustomizationManager.renderer(style);

        var now = Time.now().value();
        if (onboarded && installTime == 0) { installTime = now; }
        if (!Preview.ON && onboarded && lastSeen > 0) {
            var el = now - lastSeen;
            if (el > 60) {
                var earned = advance(el);
                if (earned > 0) {
                    toast("+" + earned.toString() + " coins while away", 0xFFC93C);
                } else if (el > 6 * 3600) {
                    toast("Your fish missed you!", 0x7FE7FF);
                }
            }
        }
        lastSeen = now;
        _cleanBucket = (clean / 10).toNumber();
        HabitatSystem.refresh(self);
        if (onboarded && !Preview.ON) {
            RewardSystem.prune(self);
            periodic();
            ExpeditionSystem.check(self);
            if (rewardAvailable()) { claimReward(); }
            ActivitySystem.beginScan(self);
        }
    }

    function fromDict(d) {
        onboarded = d["ob"];
        style = Util.clamp(d["st"], 0, 2);
        theme = Util.clamp(d["th"], 0, ThemeDatabase.COUNT - 1);
        coins = d["c"];
        coinFrac = d["cf"].toFloat();
        lv = d["lv"];
        xp = d["xp"];
        clean = d["cl"].toFloat();
        decor = d["dc"];
        placed = d["dp"];
        food = d["fd"];
        selFood = d["sf"];
        lastSeen = d["ls"];
        rewardDay = d["rd"];
        streak = d["sk"];
        dex = d["dx"];
        haptics = d["hp"];
        pearls = d["pl"];
        keys = d["ky"];
        alv = d["alv"];
        tp = d["tp"];
        installTime = d["it"];
        nid = d["nid"];
        tx = d["tx"];
        stats = d["stt"];
        stp = d["stp"];
        ds = d["ds"];
        quests = d["q"];
        ach = d["ach"];
        league = d["lg"];
        wk = d["wk"];
        rc = d["rc"];
        dd = d["dd"];
        eggs = d["egg"];
        eggBag = d["eb"];
        breed = d["brd"];
        mg = d["mg"];
        lowAnim = d["la"];
        tapFeed = d["tf"];
        tutorial = d["tu"];
        expSeen = d["exp"];
        fish = [];
        var fa = d["f"];
        for (var i = 0; i < fa.size(); i++) {
            var a = fa[i];
            if (a[0] >= 0 && a[0] < FishDatabase.COUNT) {
                var f = new FishEntity(a);
                if (f.id == 0) { f.id = nid; nid += 1; }
                fish.add(f);
            }
        }
    }

    function toDict() {
        var fa = [];
        for (var i = 0; i < fish.size(); i++) { fa.add(fish[i].toArr()); }
        return {
            "v" => SaveManager.VERSION, "ob" => onboarded, "st" => style, "th" => theme,
            "c" => coins, "cf" => coinFrac, "lv" => lv, "xp" => xp, "cl" => clean,
            "f" => fa, "dc" => decor, "dp" => placed, "fd" => food, "sf" => selFood,
            "ls" => lastSeen, "rd" => rewardDay, "sk" => streak, "dx" => dex, "hp" => haptics,
            "pl" => pearls, "ky" => keys, "alv" => alv, "tp" => tp, "it" => installTime,
            "nid" => nid, "tx" => tx, "stt" => stats, "stp" => stp, "ds" => ds, "q" => quests,
            "ach" => ach, "lg" => league, "wk" => wk, "rc" => rc, "dd" => dd, "egg" => eggs,
            "eb" => eggBag, "brd" => breed, "mg" => mg, "la" => lowAnim, "tf" => tapFeed,
            "tu" => tutorial, "exp" => expSeen
        };
    }

    function save() {
        if (Preview.ON || !onboarded) { return; }
        lastSeen = Time.now().value();
        SaveManager.save(toDict());
    }

    function resetAll() {
        SaveManager.clear();
        fromDict(SaveManager.defaults());
        foods = [];
        cards = [];
        infoFish = null;
        scanIt = null;
        setStyle(style);
        sceneDirty = true;
    }

    // ---- onboarding / customization -------------------------------------------
    function needsOnboarding() {
        return !onboarded;
    }

    function startPreview(th) {
        var p = FishDatabase.pool(th);
        preview = [];
        var n = 0;
        for (var i = 0; i < p.size() && n < 3; i++) {
            if (FishDatabase.REGION[p[i]] == 0 && FishDatabase.RARITY[p[i]] < 2) {
                preview.add(new FishEntity([p[i], 80, 80, 100, 20 + n * 30]));
                n++;
            }
        }
    }

    function finishOnboarding() {
        onboarded = true;
        preview = null;
        installTime = Time.now().value();
        var st = FishDatabase.starters(theme);
        fish = [];
        for (var i = 0; i < st.size(); i++) {
            var f = newFish(st[i], 0);
            f.sat = 70.0;
            f.gr = 10.0;
            fish.add(f);
        }
        coins = 50;
        food = [0, 3, 1];
        clean = 100.0;
        rewardDay = dayKey();
        streak = 1;
        tutorial = 0;
        addEgg0();
        sceneDirty = true;
        HabitatSystem.refresh(self);
        QuestSystem.check(self);
        LeagueSystem.ensure(self);
        ActivitySystem.checkWeek(self);
        save();
        toast("Welcome to your tank!", 0x7FE7FF);
    }

    // A starter egg so the hatching loop is visible from day one.
    function addEgg0() {
        eggs = [];
        eggBag = [];
        CollectionSystem.addEgg(self, 0, -1, 0);
    }

    function setStyle(s) {
        style = s;
        renderer = CustomizationManager.renderer(s);
        sceneDirty = true;
        var list = fishList();
        for (var i = 0; i < list.size(); i++) { FishMovement.pickTarget(list[i], self); }
    }

    function setTheme(th) {
        theme = th;
        sceneDirty = true;
        HabitatSystem.refresh(self);
    }

    function fishList() {
        return preview != null ? preview : fish;
    }

    function newFish(sp, variant) {
        var f = new FishEntity([sp, 60, 70, 100, 0, 0, variant, false, 0, nid]);
        nid += 1;
        markDex(sp);
        return f;
    }

    function fishById(id) {
        for (var i = 0; i < fish.size(); i++) { if (fish[i].id == id) { return fish[i]; } }
        return null;
    }

    function markDex(sp) {
        dex[sp] = 1;
        achDirty = true;
    }

    function dexCount() {
        var n = 0;
        for (var i = 0; i < dex.size(); i++) { if (dex[i] != 0) { n++; } }
        return n;
    }

    // Screenshot mode: a populated tank without touching the real save.
    function applyPreview() {
        onboarded = true;
        style = Preview.STYLE;
        theme = Preview.THEME;
        coins = 1240;
        pearls = 12;
        keys = 2;
        lv = 6;
        xp = 70;
        alv = 4;
        decor = [0, 1, 2, 4, 6, 13];
        placed = [0, 1, 4, 2, 6, -1];
        clean = 100.0;
        food = [0, 4, 2];
        tp = 9;
        tutorial = 4;
        stats["km"] = 42300;
        stats["runs"] = 11;
        stats["dur"] = 15300;
        stats["long"] = 12400;
        stats["pace"] = 338;
        stats["b5"] = 1620;
        stats["b10"] = 3460;
        stats["ac"] = 486;
        stats["steps"] = 14210;
        stats["hatch"] = 3;
        stats["quests"] = 9;
        var p = FishDatabase.pool(theme);
        var stages = [80, 45, 90, 10, 75];
        var vars = [0, 1, 0, 0, 2];
        fish = [];
        var n = 0;
        for (var i = 0; i < p.size() && n < 5; i++) {
            if (FishDatabase.REGION[p[i]] > 2) { continue; }
            var f = newFish(p[i], vars[n]);
            f.gr = stages[n].toFloat();
            f.hap = 85.0;
            f.fxp = 60.0 + n * 20;
            f.evo = n == 2;
            fish.add(f);
            n++;
        }
        for (var i = 0; i < 14; i++) { dex[(i * 5) % FishDatabase.COUNT] = 1; }
        for (var i = 0; i < 9; i++) { ach[i * 3] = 1; }
        eggs = [[2, 0.0, 0, -1, 0], [1, 2.4, 50000, -1, 0]];
        rewardDay = Preview.MODE == 3 ? dayKey() - 1 : dayKey();
        streak = 3;
        var day = TimeUtil.today();
        ds = {day => 7420};
        quests = {"d" => day, "di" => [0, 3, 6], "dp" => [2000, 1, 0],
                  "w" => TimeUtil.weekOf(day), "wi" => [0, 2, 5], "wp" => [6200, 2, 0]};
        league = {"w" => TimeUtil.weekOf(day), "s" => 320, "t" => 2, "h" => [380, 410, 290, 350]};
        wk = {"k" => TimeUtil.weekOf(day), "m" => 11, "s" => 2};
        expSeen = ExpeditionSystem.unlocked(self);
        HabitatSystem.refresh(self);
        if (Preview.MODE == 3) {
            claimReward();
        } else if (Preview.MODE == 4) {
            RewardSystem.card(self, "RUN REWARD", "+63 coins", ["5.2 km  -  28:14", "5:25 /km", "x1.2 bonus, 1st run of week +20"],
                RewardSystem.IC_GRID, SpriteData.ICON_SHOE, 0xFFC93C);
        }
    }

    // ---- time ---------------------------------------------------------------
    function dayKey() {
        return TimeUtil.today();
    }

    function streakWeeks() {
        var s = wk.get("s");
        return s == null ? 0 : s;
    }

    // Fish swim livelier on a day you ran.
    function postRunGlow() {
        return rc[0] == TimeUtil.today() && rc[1] > 0;
    }

    // Applies `sec` seconds of decay and income. Returns whole coins earned.
    function advance(sec) {
        var h = sec / 3600.0;
        coinFrac += EconomySystem.income(fish, h);
        var whole = coinFrac.toNumber();
        coins += whole;
        coinFrac -= whole;
        setClean(HealthSystem.advance(fish, clean, HabitatSystem.placed(self).size() * 4, h));
        CollectionSystem.eggTime(self, sec);
        return whole;
    }

    // Everything that needs checking about once a minute.
    function periodic() {
        if (!onboarded || preview != null) { return; }
        ActivitySystem.checkWeek(self);
        QuestSystem.check(self);
        LeagueSystem.check(self);
        ActivitySystem.checkSteps(self);
        CollectionSystem.checkBreed(self);
        CollectionSystem.fillIncubator(self);
        HabitatSystem.refresh(self);
        achDirty = true;
    }

    function setClean(v) {
        clean = Util.clamp(v, 0.0, 100.0);
        var b = (clean / 10).toNumber();
        if (b != _cleanBucket) {
            _cleanBucket = b;
            sceneDirty = true;
        }
    }

    function addDirt(n) {
        if (preview == null) { setClean(clean - n); }
    }

    function tick(dt) {
        t += dt;
        _minuteAcc += dt;
        if (_minuteAcc >= 60.0) {
            advance(_minuteAcc);
            _minuteAcc = 0.0;
            periodic();
            save();
        }
        ActivitySystem.stepScan(self);
        if (achDirty) {
            achDirty = false;
            AchievementSystem.check(self);
        }

        var list = fishList();
        if (renderer != CustomizationManager.renderer(1)) { SpriteData.warm(list); }
        for (var i = 0; i < list.size(); i++) { FishMovement.update(list[i], self, dt); }
        FeedingSystem.update(self, dt);

        if (!lowAnim) {
            _bubbleAcc += dt;
            if (_bubbleAcc > 0.45 && bubbles.size() < 14) {
                _bubbleAcc = 0.0;
                bubbles.add([renderer.airX + Util.rf(-6.0, 6.0), renderer.floorY - 6.0, 1 + Util.rnd(2), Util.rf(28.0, 50.0), Util.rf(0.0, 6.0)]);
            }
            // shiny and evolved fish shed the odd sparkle
            if (Util.rnd(12) == 0 && list.size() > 0) {
                var f = list[Util.rnd(list.size())];
                if (f.colorVariant() == 1 || f.evo) {
                    particle(f.x + Util.rf(-12.0, 12.0), f.y + Util.rf(-8.0, 8.0), 0.0, -12.0, 0.6, 0xFFFFFF, 0);
                }
            }
        }
        var keepB = [];
        for (var i = 0; i < bubbles.size(); i++) {
            var b = bubbles[i];
            b[1] -= b[3] * dt;
            b[4] += dt * 3;
            b[0] += Math.sin(b[4]) * 0.5;
            if (b[1] > 40) { keepB.add(b); }
        }
        bubbles = keepB;

        var keepP = [];
        for (var i = 0; i < parts.size(); i++) {
            var p = parts[i];
            p[0] += p[2] * dt;
            p[1] += p[3] * dt;
            p[4] -= dt;
            if (p[4] > 0) { keepP.add(p); }
        }
        parts = keepP;

        var keepT = [];
        for (var i = 0; i < pops.size(); i++) {
            var p = pops[i];
            p[1] -= 18 * dt;
            p[3] -= dt;
            if (p[3] > 0) { keepT.add(p); }
        }
        pops = keepT;

        if (toastT > 0) { toastT -= dt; }
        if (infoT > 0) {
            infoT -= dt;
            if (infoT <= 0) { infoFish = null; }
        }

        if (cleanT >= 0) {
            cleanT += dt / 1.6;
            var sp = spongePos();
            particle(sp[0], sp[1], Util.rf(-30.0, 30.0), Util.rf(-40.0, 10.0), 0.6, 0xBFEFFF, 0);
            if (cleanT >= 1.0) { finishClean(); }
        }
    }

    // ---- tutorial ---------------------------------------------------------------
    // 0 feed, 1 clean, 2 running info (tap), 3 open menu, 4 done
    function tutorialActive() {
        return onboarded && preview == null && !Preview.ON && tutorial < 4;
    }

    function tutorialEvent(step) {
        if (tutorialActive() && tutorial == step) {
            tutorial += 1;
            if (tutorial == 4) {
                RewardSystem.grant(self, "tut", 30, 1, 1, 20);
                RewardSystem.card(self, "TUTORIAL DONE", "+30 coins  +1 pearl  +1 key",
                    ["Run with your Run app to earn more", "Check Quests every day"], RewardSystem.IC_GRID, SpriteData.ICON_STAR, 0x7FE7FF);
            }
            save();
        }
    }

    // ---- actions --------------------------------------------------------------
    function feedAt(x, y) {
        if (cleanT >= 0) { return; }
        FeedingSystem.drop(self, x, y);
    }

    function startClean() {
        if (cleanT >= 0) { return; }
        tutorialEvent(1);
        if (clean > 95) {
            toast("Already sparkling!", 0x7FE7FF);
            return;
        }
        cleanReward = clean < 60;
        cleanT = 0.0;
        foods = [];
        Util.buzz(self, 40);
    }

    function spongePos() {
        return [40 + cleanT * 310, 170 + Math.sin(cleanT * 14) * 70];
    }

    function finishClean() {
        cleanT = -1.0;
        setClean(100.0);
        sceneDirty = true;
        if (cleanReward) {
            coins += 3;
            pop(195, 150, "+3", 0xFFC93C);
            addXp(5);
        } else {
            addXp(2);
        }
        QuestSystem.event(self, QuestSystem.Q_CLEAN, 1);
        toast("Sparkling clean!", 0x7FE7FF);
        save();
    }

    function fishAt(x, y) {
        var list = fishList();
        for (var i = list.size() - 1; i >= 0; i--) {
            var f = list[i];
            var h = renderer.hitHalf(f);
            if ((x - f.x).abs() < h[0] + 8 && (y - f.y).abs() < h[1] + 8) { return f; }
        }
        return null;
    }

    function showInfo(f) {
        infoFish = f;
        infoT = 3.5;
        if (f.petCd <= 0) {
            f.petCd = 20.0;
            f.hap = Util.clamp(f.hap + 3, 0.0, 100.0);
            particle(f.x, f.y - 20, 0.0, -25.0, 1.0, 0xFF5A7A, 1);
            QuestSystem.event(self, QuestSystem.Q_PET, 1);
        }
    }

    // Returns null when the species can be bought, otherwise why not.
    function buyReason(sp) {
        if (!CollectionSystem.available(self, sp)) { return CollectionSystem.gateText(self, sp); }
        if (lv < FishDatabase.unlockLevel(sp)) { return "Unlocks at LV " + FishDatabase.unlockLevel(sp).toString(); }
        if (fish.size() >= HabitatSystem.capacity(self)) { return "Tank full - expand it"; }
        if (coins < FishDatabase.price(sp)) { return "Need " + (FishDatabase.price(sp) - coins).toString() + " more coins"; }
        if (pearls < FishDatabase.pearlPrice(sp)) { return "Need " + FishDatabase.pearlPrice(sp).toString() + " pearls"; }
        return null;
    }

    function buyFish(sp) {
        var why = buyReason(sp);
        if (why != null) { return why; }
        coins -= FishDatabase.price(sp);
        pearls -= FishDatabase.pearlPrice(sp);
        var f = newFish(sp, CollectionSystem.rollVariant(2));
        f.y = 100.0;
        fish.add(f);
        for (var k = 0; k < 6; k++) {
            particle(f.x, f.y, Util.rf(-40.0, 40.0), Util.rf(-40.0, 20.0), 0.8, FishDatabase.RARITY_COLOR[FishDatabase.RARITY[sp]], 0);
        }
        toast(FishDatabase.NAME[sp] + " joined the tank!", FishDatabase.RARITY_COLOR[FishDatabase.RARITY[sp]]);
        Util.buzz(self, 80);
        HabitatSystem.refresh(self);
        addXp(10);
        save();
        return null;
    }

    function releaseFish(id) {
        for (var i = 0; i < fish.size(); i++) {
            if (fish[i].id == id) {
                var v = EconomySystem.releaseValue(fish[i].sp);
                coins += v;
                if (infoFish == fish[i]) { infoFish = null; }
                if (breed.size() > 0 && (breed[0] == id || breed[1] == id)) { breed = []; }
                fish.remove(fish[i]);
                HabitatSystem.refresh(self);
                save();
                return v;
            }
        }
        return 0;
    }

    function buyFood(type) {
        var price = ItemDatabase.FOOD_PACK_PRICE[type];
        if (coins < price) { return "Need " + (price - coins).toString() + " more coins"; }
        coins -= price;
        food[type] += ItemDatabase.FOOD_PACK_QTY[type];
        save();
        return null;
    }

    function decorReason(id) {
        if (decor.indexOf(id) >= 0) { return "Owned"; }
        if (!HabitatSystem.decorAvailable(self, id)) { return "Explore " + ExpeditionSystem.NAME[ItemDatabase.DECOR_REGION[id]]; }
        if (lv < ItemDatabase.DECOR_LV[id]) { return "Unlocks at LV " + ItemDatabase.DECOR_LV[id].toString(); }
        if (coins < ItemDatabase.DECOR_PRICE[id]) { return "Need " + (ItemDatabase.DECOR_PRICE[id] - coins).toString() + " more coins"; }
        return null;
    }

    function buyDecor(id) {
        var why = decorReason(id);
        if (why != null) { return why; }
        coins -= ItemDatabase.DECOR_PRICE[id];
        decor.add(id);
        // drop it into the first free slot so the purchase shows right away
        var n = HabitatSystem.slotCount(self);
        for (var i = 0; i < n; i++) {
            if (placed[i] < 0) { HabitatSystem.place(self, i, id); break; }
        }
        toast(ItemDatabase.DECOR_NAME[id] + " added!", 0xFFC93C);
        addXp(8);
        achDirty = true;
        save();
        return null;
    }

    function buyEgg(type) {
        if (coins < CollectionSystem.EGG_PRICE_C[type]) { return "Need " + CollectionSystem.EGG_PRICE_C[type].toString() + " coins"; }
        if (pearls < CollectionSystem.EGG_PRICE_P[type]) { return "Need " + CollectionSystem.EGG_PRICE_P[type].toString() + " pearls"; }
        coins -= CollectionSystem.EGG_PRICE_C[type];
        pearls -= CollectionSystem.EGG_PRICE_P[type];
        CollectionSystem.addEgg(self, type, -1, 0);
        save();
        return null;
    }

    function buyKey() {
        if (pearls < EconomySystem.KEY_PEARLS) { return "Need " + EconomySystem.KEY_PEARLS.toString() + " pearls"; }
        pearls -= EconomySystem.KEY_PEARLS;
        keys += 1;
        save();
        return null;
    }

    // ---- daily gift & progression -----------------------------------------------
    function rewardAvailable() {
        return onboarded && dayKey() != rewardDay;
    }

    function nextStreak() {
        return rewardDay == dayKey() - 1 ? streak + 1 : 1;
    }

    function claimReward() {
        if (!rewardAvailable()) { return; }
        var s = nextStreak();
        var amt = EconomySystem.daily(s, lv);
        streak = s;
        rewardDay = dayKey();
        RewardSystem.grant(self, "gift" + rewardDay.toString(), amt, s % 7 == 0 ? 1 : 0, 0, 10);
        var lines = ["Day " + streak.toString() + " streak"];
        if (s % 7 == 0) { lines.add("+1 pearl for a full week!"); }
        RewardSystem.card(self, "DAILY GIFT", "+" + amt.toString() + " coins", lines, RewardSystem.IC_DECOR, 1, 0xFFC93C);
        save();
    }

    function addXp(n) {
        if (preview != null) { return; }
        var r = ProgressionSystem.apply(lv, xp, n);
        var gained = r[2];
        lv = r[0];
        xp = r[1];
        if (gained > 0) {
            RewardSystem.card(self, "LEVEL UP", "LV " + lv.toString() + " - " + ProgressionSystem.title(lv),
                [ProgressionSystem.unlockText(lv)], RewardSystem.IC_GRID, SpriteData.ICON_STAR, 0x7FE7FF);
            Util.buzz(self, 200);
            achDirty = true;
        }
    }

    // ---- mini-game bookkeeping ------------------------------------------------------

    function gamesLeft(game) {
        var day = dayKey();
        if (mg.get("d") != day) { mg = {"d" => day}; }
        var used = mg.get(game);
        return MiniGameRules.DAILY - (used == null ? 0 : used);
    }

    // Records a finished game, pays coins only while daily plays remain.
    function finishGame(game, coinsWon, xpWon) {
        var left = gamesLeft(game);
        var used = mg.get(game);
        mg.put(game, (used == null ? 0 : used) + 1);
        QuestSystem.event(self, QuestSystem.Q_GAME, 1);
        if (left > 0) {
            coins += coinsWon;
            addXp(xpWon);
        }
        achDirty = true;
        save();
        return left > 0;
    }

    // ---- effects --------------------------------------------------------------
    function toast(text, col) {
        toastText = text;
        toastCol = col;
        toastT = 2.6;
    }

    function pop(x, y, text, col) {
        if (pops.size() < 8) { pops.add([x, y, text, 1.0, col]); }
    }

    function particle(x, y, vx, vy, life, col, kind) {
        if (lowAnim && kind == 0) { return; }
        if (parts.size() < 30) { parts.add([x, y, vx, vy, life, col, kind]); }
    }

    function foodCount() {
        return selFood == 0 ? -1 : food[selFood];
    }

    function avgSat() {
        if (fish.size() == 0) { return 100.0; }
        var s = 0.0;
        for (var i = 0; i < fish.size(); i++) { s += fish[i].sat; }
        return s / fish.size();
    }
}
