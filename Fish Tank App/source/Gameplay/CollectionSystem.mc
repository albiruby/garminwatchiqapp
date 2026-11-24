import Toybox.Lang;
import Toybox.Time;

// Collect pillar: eggs and hatching, color variants, fish level and evolution, breeding,
// mystery finds and treasure chests.
// Egg = [type, kmLeft, secondsLeft, fixedSpecies (-1 random), variantHint]
module CollectionSystem {
    const EGG_NAME = ["Common Egg", "Rare Egg", "Mystery Egg", "Epic Egg", "Legendary Egg", "Bred Egg"];
    const EGG_KM = [3, 5, 8, 10, 15, 0];
    const EGG_HOURS = [12, 24, 36, 48, 72, 6];
    const EGG_PRICE_C = [40, 0, 0, 0, 0, 0];
    const EGG_PRICE_P = [0, 5, 0, 0, 0, 0];
    // rarity weights C/U/R/E/L per egg type
    const EGG_W = [[70, 25, 5, 0, 0], [0, 50, 40, 10, 0], [30, 30, 25, 12, 3],
                   [0, 0, 0, 80, 20], [0, 0, 0, 0, 100], [100, 0, 0, 0, 0]];
    const EGG_VARIANT = [4, 6, 10, 12, 15, 0];   // % chance of a color variant
    const BREED_COST = 50;
    const BREED_HOURS = 6;
    const EVOLVE_LEVEL = 5;
    const EVOLVE_HAPPY = 70;
    const EVOLVE_KM = 20;
    const EVOLVE_PEARLS = 2;

    function incubatorSlots(eng) {
        return eng.alv >= 3 ? 2 : 1;
    }

    function addEgg(eng, type, fixedSp, varHint) {
        var egg = [type, EGG_KM[type].toFloat(), EGG_HOURS[type] * 3600, fixedSp, varHint];
        if (eng.eggs.size() < incubatorSlots(eng)) { eng.eggs.add(egg); }
        else { eng.eggBag.add(egg); }
    }

    function eggReady(egg) {
        return egg[1] <= 0 || egg[2] <= 0;
    }

    // Running speeds up every incubating egg.
    function eggKm(eng, km) {
        for (var i = 0; i < eng.eggs.size(); i++) {
            eng.eggs[i][1] = eng.eggs[i][1] - km;
        }
    }

    function eggTime(eng, sec) {
        var ready = false;
        for (var i = 0; i < eng.eggs.size(); i++) {
            var was = eggReady(eng.eggs[i]);
            eng.eggs[i][2] = eng.eggs[i][2] - sec;
            if (!was && eggReady(eng.eggs[i])) { ready = true; }
        }
        if (ready) { eng.toast("An egg is ready to hatch!", 0xFFE9A0); }
    }

    // Moves bagged eggs into free incubator slots.
    function fillIncubator(eng) {
        while (eng.eggBag.size() > 0 && eng.eggs.size() < incubatorSlots(eng)) {
            eng.eggs.add(eng.eggBag[0]);
            eng.eggBag = eng.eggBag.slice(1, null);
        }
    }

    // Species that may appear right now (expedition region and distance gates).
    function available(eng, sp) {
        if (FishDatabase.REGION[sp] > ExpeditionSystem.unlocked(eng)) { return false; }
        var gate = FishDatabase.KM_GATE[sp];
        if (gate < 0) { return eng.stats["long"] >= 21100; }
        return eng.stats["km"] / 1000 >= gate;
    }

    function gateText(eng, sp) {
        if (FishDatabase.REGION[sp] > ExpeditionSystem.unlocked(eng)) {
            return "Explore " + ExpeditionSystem.NAME[FishDatabase.REGION[sp]];
        }
        var gate = FishDatabase.KM_GATE[sp];
        if (gate < 0) { return "Run a half marathon"; }
        return "Run " + gate.toString() + " km total";
    }

    function rollSpecies(eng, type) {
        var w = EGG_W[type];
        var total = 0;
        for (var i = 0; i < 5; i++) { total += w[i]; }
        var r = Util.rnd(total);
        var rar = 0;
        for (var i = 0; i < 5; i++) {
            if (r < w[i]) { rar = i; break; }
            r -= w[i];
        }
        // fall back to a lower rarity if nothing of this rarity is reachable yet
        while (rar >= 0) {
            var opts = [];
            for (var sp = 0; sp < FishDatabase.COUNT; sp++) {
                if (FishDatabase.RARITY[sp] == rar && FishDatabase.REGION[sp] <= ExpeditionSystem.unlocked(eng)) {
                    opts.add(sp);
                }
            }
            if (opts.size() > 0) { return opts[Util.rnd(opts.size())]; }
            rar -= 1;
        }
        return 0;
    }

    function rollVariant(pct) {
        var v = 0;
        if (Util.rnd(100) < pct) { v = 1 + Util.rnd(3); }
        if (Util.rnd(100) < pct / 2) { v = v | 4; }   // giant
        return v;
    }

    // Returns null on success, otherwise the reason.
    function hatch(eng, idx) {
        if (idx >= eng.eggs.size()) { return "No egg"; }
        var egg = eng.eggs[idx];
        if (!eggReady(egg)) { return "Not ready yet"; }
        if (eng.fish.size() >= HabitatSystem.capacity(eng)) { return "Tank full - expand it"; }
        var type = egg[0];
        var sp = egg[3] >= 0 ? egg[3] : rollSpecies(eng, type);
        var v = egg[4] > 0 ? egg[4] : rollVariant(EGG_VARIANT[type]);
        var f = eng.newFish(sp, v);
        f.y = 120.0;
        eng.fish.add(f);
        var a = eng.eggs;
        var out = [];
        for (var i = 0; i < a.size(); i++) { if (i != idx) { out.add(a[i]); } }
        eng.eggs = out;
        fillIncubator(eng);
        eng.stats["hatch"] = eng.stats["hatch"] + 1;
        if (v > 0) { eng.stats["var"] = eng.stats["var"] + 1; }
        QuestSystem.event(eng, QuestSystem.Q_HATCH, 1);
        HabitatSystem.refresh(eng);
        var rar = FishDatabase.RARITY[sp];
        var lines = [FishDatabase.RARITY_NAME[rar] + " - " + FishDatabase.HABITAT[FishDatabase.HAB[sp]]];
        if ((v & 3) > 0) { lines.add(SpriteData.VARIANT_NAME[v & 3] + " variant!"); }
        if ((v & 4) != 0) { lines.add("Giant size!"); }
        RewardSystem.card(eng, "HATCHED!", FishDatabase.NAME[sp], lines, RewardSystem.IC_FISH, [sp, false, v], FishDatabase.RARITY_COLOR[rar]);
        Util.buzz(eng, 200);
        eng.achDirty = true;
        eng.save();
        return null;
    }

    // ---- evolution -----------------------------------------------------------------
    function evolveReason(eng, f) {
        if (f.evo) { return "Already evolved"; }
        if (f.level() < EVOLVE_LEVEL) { return "Needs fish LV " + EVOLVE_LEVEL.toString(); }
        if (f.hap < EVOLVE_HAPPY) { return "Needs " + EVOLVE_HAPPY.toString() + "% happiness"; }
        if (eng.stats["km"] / 1000 < EVOLVE_KM) { return "Run " + EVOLVE_KM.toString() + " km total"; }
        if (eng.pearls < EVOLVE_PEARLS) { return "Needs " + EVOLVE_PEARLS.toString() + " pearls"; }
        return null;
    }

    function evolve(eng, f) {
        var why = evolveReason(eng, f);
        if (why != null) { return why; }
        eng.pearls -= EVOLVE_PEARLS;
        f.evo = true;
        eng.stats["evo"] = eng.stats["evo"] + 1;
        RewardSystem.card(eng, "EVOLVED!", f.name(), ["Grand fins and a brighter glow"], RewardSystem.IC_FISH,
            [f.sp, true, f.variant], 0xC77DFF);
        Util.buzz(eng, 250);
        eng.achDirty = true;
        eng.save();
        return null;
    }

    // ---- breeding --------------------------------------------------------------------
    function canPair(a, b) {
        return a.id != b.id && FishDatabase.HAB[a.sp] == FishDatabase.HAB[b.sp] &&
               a.stage() == 2 && b.stage() == 2 && a.hap >= 60 && b.hap >= 60;
    }

    function breedReason(eng, a) {
        if (eng.breed.size() > 0) { return "Already breeding"; }
        if (a.stage() != 2) { return "Must be an adult"; }
        if (a.hap < 60) { return "Needs 60% happiness"; }
        if (eng.coins < BREED_COST) { return "Needs " + BREED_COST.toString() + " coins"; }
        var any = false;
        for (var i = 0; i < eng.fish.size(); i++) { if (canPair(a, eng.fish[i])) { any = true; } }
        if (!any) { return "No happy adult partner of the same habitat"; }
        return null;
    }

    function startBreed(eng, a, b) {
        if (!canPair(a, b) || eng.coins < BREED_COST) { return; }
        eng.coins -= BREED_COST;
        eng.breed = [a.id, b.id, Time.now().value() + BREED_HOURS * 3600];
        eng.toast("Breeding started - eggs in " + BREED_HOURS.toString() + "h", 0xFF8BEF);
        eng.save();
    }

    function checkBreed(eng) {
        if (eng.breed.size() < 3 || Time.now().value() < eng.breed[2]) { return; }
        var pa = eng.fishById(eng.breed[0]);
        var pb = eng.fishById(eng.breed[1]);
        eng.breed = [];
        if (pa == null || pb == null) { return; }
        var sp = Util.rnd(2) == 0 ? pa.sp : pb.sp;
        var hint = 0;
        var pv = (pa.variant > 0) ? pa.variant : pb.variant;
        if (pv > 0 && Util.rnd(100) < 40) { hint = pv; }
        else { hint = rollVariant(8); }
        addEgg(eng, 5, sp, hint);
        eng.stats["breed"] = eng.stats["breed"] + 1;
        RewardSystem.card(eng, "NEW EGG!", pa.name() + " + " + pb.name(), ["A bred egg is incubating"],
            RewardSystem.IC_EGG, 5, 0xFF8BEF);
        eng.achDirty = true;
    }

    // ---- mystery and chests --------------------------------------------------------
    function mystery(eng, tx) {
        if (RewardSystem.done(eng, tx)) { return; }
        RewardSystem.mark(eng, tx);
        var r = Util.rnd(100);
        if (r < 40) {
            eng.keys += 1;
            RewardSystem.card(eng, "MYSTERY FIND", "+1 treasure key", ["Something glinted in the sand"], RewardSystem.IC_GRID, SpriteData.ICON_KEY, 0xFFC93C);
        } else if (r < 75) {
            eng.pearls += 2;
            RewardSystem.card(eng, "MYSTERY FIND", "+2 pearls", ["A clam opened for you"], RewardSystem.IC_GRID, SpriteData.ICON_PEARL, 0xF4F0FF);
        } else {
            addEgg(eng, 2, -1, 0);
            RewardSystem.card(eng, "MYSTERY FIND", "Mystery Egg", ["Hatch it to see what's inside"], RewardSystem.IC_EGG, 2, 0xC77DFF);
        }
    }

    function openChest(eng) {
        if (eng.keys <= 0) { return "Needs a treasure key"; }
        eng.keys -= 1;
        var r = Util.rnd(100);
        if (r < 45) {
            var c = 40 + Util.rnd(81);
            eng.coins += c;
            RewardSystem.card(eng, "TREASURE CHEST", "+" + c.toString() + " coins", [], RewardSystem.IC_GRID, SpriteData.ICON_CHEST, 0xFFC93C);
        } else if (r < 65) {
            var p = 1 + Util.rnd(3);
            eng.pearls += p;
            RewardSystem.card(eng, "TREASURE CHEST", RewardSystem.summary(0, p, 0), [], RewardSystem.IC_GRID, SpriteData.ICON_PEARL, 0xF4F0FF);
        } else if (r < 80) {
            eng.food[2] += 3;
            eng.food[1] += 5;
            RewardSystem.card(eng, "TREASURE CHEST", "Food crate", ["+5 pellets  +3 bloodworms"], RewardSystem.IC_GRID, SpriteData.ICON_FEED, 0xFF8C2E);
        } else if (r < 92) {
            addEgg(eng, 2, -1, 0);
            RewardSystem.card(eng, "TREASURE CHEST", "Mystery Egg", ["Hatch it to see what's inside"], RewardSystem.IC_EGG, 2, 0xC77DFF);
        } else {
            var d = HabitatSystem.randomUnownedDecor(eng);
            if (d >= 0) {
                eng.decor.add(d);
                RewardSystem.card(eng, "TREASURE CHEST", ItemDatabase.DECOR_NAME[d], ["Rare decoration - place it in Build"], RewardSystem.IC_DECOR, d, 0x7FE7FF);
            } else {
                eng.coins += 150;
                RewardSystem.card(eng, "TREASURE CHEST", "+150 coins", [], RewardSystem.IC_GRID, SpriteData.ICON_CHEST, 0xFFC93C);
            }
        }
        Util.buzz(eng, 120);
        eng.save();
        return null;
    }
}
