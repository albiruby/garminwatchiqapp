import Toybox.Lang;

// "Arus Minggu Ini" (this week's current): every Monday a new set, picked from the week
// number so every player gets the same week without a server.
//   1. Current: one gentle modifier (7 kinds)
//   2. Featured fish: 30% off in the shop
//   3. Visitor: a rare fish swims in your tank; run 10 km this week and it leaves an egg
//   4. Spotlight: one mini-game pays double coins
// The three layers cycle with different lengths (7, 36, 3), so combinations rarely repeat.
module WeeklySystem {
    const NAME = ["Warm Current", "Plankton Bloom", "Clear Water", "Treasure Tide", "Fast Current", "Deep Current", "Full Moon"];
    const DESC = ["Fish grow 50% faster", "Food packs half price", "The tank stays clean longer",
                  "More mystery finds on runs", "Fish Racing pays double", "Deep-sea fish hatch from eggs",
                  "Rare variants twice as likely"];
    const MODS = [0, 1, 2, 3, 4, 5, 6];
    const GAMES = ["bp", "td", "fr"];
    const GAME_NAME = ["Bubble Pop", "Treasure Dive", "Fish Racing"];
    const DISCOUNT = 30;          // % off the featured fish
    const VISIT_KM = 10000;       // meters to run this week to keep the visitor

    function current(w) {
        return (w * 3 + 1) % 7;
    }

    function spotlight(w) {
        return GAMES[w % 3];
    }

    function spotlightName(w) {
        return GAME_NAME[w % 3];
    }

    // Cycles through all 36 species (step 5 is coprime with 36), skipping ones the player
    // cannot buy yet (region or distance gate) and legendaries.
    function featured(eng, w) {
        var start = (w * 7) % FishDatabase.COUNT;
        for (var i = 0; i < FishDatabase.COUNT; i++) {
            var sp = (start + i * 5) % FishDatabase.COUNT;
            if (FishDatabase.RARITY[sp] < 4 && CollectionSystem.available(eng, sp)) { return sp; }
        }
        return 0;
    }

    // A rare-or-better species, any region: the visitor is a teaser of what's out there.
    function visitor(w) {
        var rare = [];
        for (var i = 0; i < FishDatabase.COUNT; i++) {
            if (FishDatabase.RARITY[i] >= 2) { rare.add(i); }
        }
        return rare[(w * 5 + 2) % rare.size()];
    }

    function price(eng, sp) {
        var p = FishDatabase.price(sp);
        if (sp == featured(eng, TimeUtil.weekOf(TimeUtil.today()))) { p = p * (100 - DISCOUNT) / 100; }
        return p;
    }

    function weekMeters(eng) {
        var m = eng.wk.get("km");
        return m == null ? 0 : m;
    }

    function visitorDone(eng, w) {
        return RewardSystem.done(eng, "vis" + w.toString());
    }

    // Weekly opening card and the visitor fish.
    function refresh(eng, w) {
        if (eng.visitor == null || eng.visitor.sp != visitor(w)) {
            eng.visitor = visitorDone(eng, w) ? null : new FishEntity([visitor(w), 100, 100, 100, 80, 0, 0, false, 0, 0]);
        }
        var tx = "wk" + w.toString();
        if (RewardSystem.done(eng, tx)) { return; }
        RewardSystem.mark(eng, tx);
        var c = current(w);
        RewardSystem.card(eng, "THIS WEEK'S CURRENT", NAME[c],
            [DESC[c], "Featured: " + FishDatabase.NAME[featured(eng, w)] + " -" + DISCOUNT.toString() + "%",
             "Visitor: " + FishDatabase.NAME[visitor(w)]],
            RewardSystem.IC_GRID, SpriteData.ICON_WAVE, 0x7FE7FF);
    }

    // Called after each paid run that falls in the current week.
    function onRun(eng, day, meters) {
        var w = TimeUtil.weekOf(TimeUtil.today());
        if (TimeUtil.weekOf(day) != w) { return; }
        eng.wk.put("km", weekMeters(eng) + meters);
        if (weekMeters(eng) >= VISIT_KM && !visitorDone(eng, w)) {
            RewardSystem.grant(eng, "vis" + w.toString(), 0, 1, 0, 30);
            var sp = visitor(w);
            CollectionSystem.addEgg(eng, 5, sp, 0);
            eng.visitor = null;
            RewardSystem.card(eng, "THE VISITOR STAYS", FishDatabase.NAME[sp], ["It left you an egg  +1 pearl", "10 km this week - well run!"],
                RewardSystem.IC_FISH, [sp, false, 0], FishDatabase.RARITY_COLOR[FishDatabase.RARITY[sp]]);
        }
    }
}
