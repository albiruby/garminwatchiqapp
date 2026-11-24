import Toybox.Lang;

// Build pillar: aquarium level (capacity, decor slots, plants, swim room), decoration
// placement, habitat synergy and the 0-5 star aquarium rating.
module HabitatSystem {
    const MAX_ALV = 5;
    const CAP = [3, 4, 5, 6, 8];
    const ALV_PRICE = [0, 150, 400, 900, 1800];
    const ALV_PEARLS = [0, 0, 2, 5, 10];
    const ALV_PLAYER_LV = [1, 3, 5, 7, 9];
    const SYN_BONUS = 15.0;

    function capacity(eng) {
        return CAP[Util.clamp(eng.alv, 1, MAX_ALV) - 1];
    }

    function slotCount(eng) {
        return Util.clamp(eng.alv + 1, 2, ItemDatabase.SLOT_X.size());
    }

    function plantCount(eng) {
        return Util.clamp(2 + eng.alv, 3, 7);
    }

    // Extra swim room in px on each side as the tank grows.
    function room(eng) {
        return (eng.alv - 1) * 5;
    }

    function upgradeReason(eng) {
        if (eng.alv >= MAX_ALV) { return "Max size"; }
        var n = eng.alv;   // index of next level
        if (eng.lv < ALV_PLAYER_LV[n]) { return "Needs player LV " + ALV_PLAYER_LV[n].toString(); }
        if (eng.coins < ALV_PRICE[n]) { return "Needs " + ALV_PRICE[n].toString() + " coins"; }
        if (eng.pearls < ALV_PEARLS[n]) { return "Needs " + ALV_PEARLS[n].toString() + " pearls"; }
        return null;
    }

    function upgrade(eng) {
        var why = upgradeReason(eng);
        if (why != null) { return why; }
        var n = eng.alv;
        eng.coins -= ALV_PRICE[n];
        eng.pearls -= ALV_PEARLS[n];
        eng.alv += 1;
        eng.sceneDirty = true;
        CollectionSystem.fillIncubator(eng);
        RewardSystem.card(eng, "TANK EXPANDED", "Aquarium LV " + eng.alv.toString(),
            [capacity(eng).toString() + " fish  -  " + slotCount(eng).toString() + " decor slots"],
            RewardSystem.IC_GRID, SpriteData.ICON_BUILD, 0x7FE7FF);
        eng.addXp(30);
        eng.achDirty = true;
        refresh(eng);
        eng.save();
        return null;
    }

    // ---- decor --------------------------------------------------------------------
    function placed(eng) {
        var out = [];
        var n = slotCount(eng);
        for (var i = 0; i < n; i++) {
            if (eng.placed[i] >= 0) { out.add(eng.placed[i]); }
        }
        return out;
    }

    function isPlaced(eng, id) {
        var n = slotCount(eng);
        for (var i = 0; i < n; i++) { if (eng.placed[i] == id) { return true; } }
        return false;
    }

    function place(eng, slot, id) {
        for (var i = 0; i < eng.placed.size(); i++) {
            if (eng.placed[i] == id && id >= 0) { eng.placed[i] = -1; }
        }
        eng.placed[slot] = id;
        eng.sceneDirty = true;
        if (id >= 0) { QuestSystem.event(eng, QuestSystem.Q_DECOR, 1); }
        refresh(eng);
        eng.save();
    }

    function decorAvailable(eng, id) {
        return ItemDatabase.DECOR_REGION[id] <= ExpeditionSystem.unlocked(eng);
    }

    function randomUnownedDecor(eng) {
        var opts = [];
        for (var i = 0; i < ItemDatabase.DECOR_COUNT; i++) {
            if (eng.decor.indexOf(i) < 0 && decorAvailable(eng, i)) { opts.add(i); }
        }
        return opts.size() == 0 ? -1 : opts[Util.rnd(opts.size())];
    }

    // ---- synergy ------------------------------------------------------------------
    function hasTag(eng, tag) {
        var tt = ThemeDatabase.TAGS[eng.theme];
        for (var i = 0; i < tt.size(); i++) { if (tt[i] == tag) { return true; } }
        var p = placed(eng);
        for (var i = 0; i < p.size(); i++) { if (ItemDatabase.DECOR_TAG[p[i]] == tag) { return true; } }
        return false;
    }

    function synergyFor(eng, f) {
        var tag = FishDatabase.SYN[f.sp];
        if (tag == 0) { return false; }
        if (tag == 7) { return eng.fish.size() < capacity(eng); }
        return hasTag(eng, tag);
    }

    function refresh(eng) {
        var list = eng.fish;
        for (var i = 0; i < list.size(); i++) { list[i].syn = synergyFor(eng, list[i]); }
    }

    function synergyCount(eng) {
        var n = 0;
        for (var i = 0; i < eng.fish.size(); i++) { if (eng.fish[i].syn) { n++; } }
        return n;
    }

    // ---- rating -------------------------------------------------------------------
    // 1.5 clean + 1.5 happiness + 1.0 variety + 0.5 synergy + 0.5 decor = 5 stars.
    function rating(eng) {
        var n = eng.fish.size();
        if (n == 0) { return 0.0; }
        var hap = 0.0;
        var species = [];
        for (var i = 0; i < n; i++) {
            hap += eng.fish[i].hap;
            if (species.indexOf(eng.fish[i].sp) < 0) { species.add(eng.fish[i].sp); }
        }
        var r = 1.5 * eng.clean / 100.0;
        r += 1.5 * (hap / n) / 100.0;
        r += 1.0 * Util.clamp(species.size() / (capacity(eng) * 1.0), 0.0, 1.0);
        r += 0.5 * synergyCount(eng) / (n * 1.0);
        r += 0.5 * Util.clamp(placed(eng).size() / (slotCount(eng) * 1.0), 0.0, 1.0);
        return Util.clamp(r, 0.0, 5.0);
    }

    function stars(eng) {
        return (rating(eng) + 0.25).toNumber();
    }
}
