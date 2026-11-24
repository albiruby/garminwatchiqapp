import Toybox.Lang;

// Trophy Room: 31 badges checked against stats after relevant events.
module AchievementSystem {
    const COUNT = 31;

    const A_RUNS = 0;
    const A_KM = 1;          // meters
    const A_STEPS = 2;
    const A_STREAK = 3;
    const A_DEX = 4;
    const A_HATCH = 5;
    const A_EVOLVE = 6;
    const A_BREED = 7;
    const A_VARIANT = 8;
    const A_RATING = 9;
    const A_DECOR = 10;
    const A_ALV = 11;
    const A_BUBBLE = 12;
    const A_DIVE = 13;
    const A_RACE = 14;
    const A_LEAGUE = 15;
    const A_LONG = 16;       // meters
    const A_QUESTS = 17;

    const NAME = ["First Splash", "Warm Up", "Pace Setter", "Half Way", "Centurion", "Ultra Tank",
                  "Ocean Crosser", "Regular", "Dedicated", "Step Hunter", "Step Master", "Consistent",
                  "Unstoppable", "Collector", "Curator", "Fishdex Master", "First Hatch", "Hatchery",
                  "Metamorph", "Matchmaker", "Rare Find", "Five Stars", "Interior Designer",
                  "Grand Aquarium", "Bubble Ace", "Deep Diver", "Champion", "Gold League",
                  "Abyss League", "Half Marathon", "Quest Hunter"];
    const DESC = ["Finish your first run", "Run 5 km in total", "Run 25 km in total", "Run 50 km in total",
                  "Run 100 km in total", "Run 250 km in total", "Run 500 km in total", "Complete 10 runs",
                  "Complete 50 runs", "10,000 steps in a day", "20,000 steps in a day", "2 consistent weeks",
                  "8 consistent weeks", "Discover 10 species", "Discover 20 species", "Discover all 36 species",
                  "Hatch an egg", "Hatch 10 eggs", "Evolve a fish", "Breed a pair", "Find a color variant",
                  "Reach a 5-star tank", "Own 8 decorations", "Max aquarium level", "Score 30 in Bubble Pop",
                  "Reach depth 5 in Treasure Dive", "Win 5 fish races", "Reach Gold league",
                  "Reach Abyss league", "Run 21.1 km in one go", "Complete 25 quests"];
    const TYPE = [0, 1, 1, 1, 1, 1, 1, 0, 0, 2, 2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 15, 16, 17];
    const TARGET = [1, 5000, 25000, 50000, 100000, 250000, 500000, 10, 50, 10000, 20000, 2, 8, 10, 20, 36,
                    1, 10, 1, 1, 1, 5, 8, 5, 30, 5, 5, 2, 4, 21100, 25];
    const PEARLS = [1, 1, 2, 2, 3, 5, 8, 1, 3, 1, 2, 2, 5, 2, 3, 8, 1, 3, 2, 2, 2, 3, 2, 5, 2, 2, 3, 3, 6, 5, 3];

    function value(eng, type) {
        var s = eng.stats;
        if (type == A_RUNS) { return s["runs"]; }
        if (type == A_KM) { return s["km"]; }
        if (type == A_STEPS) { return s["steps"]; }
        if (type == A_STREAK) { return s["streak"]; }
        if (type == A_DEX) { return eng.dexCount(); }
        if (type == A_HATCH) { return s["hatch"]; }
        if (type == A_EVOLVE) { return s["evo"]; }
        if (type == A_BREED) { return s["breed"]; }
        if (type == A_VARIANT) { return s["var"]; }
        if (type == A_RATING) { return HabitatSystem.stars(eng); }
        if (type == A_DECOR) { return eng.decor.size(); }
        if (type == A_ALV) { return eng.alv; }
        if (type == A_BUBBLE) { return s["bub"]; }
        if (type == A_DIVE) { return s["dive"]; }
        if (type == A_RACE) { return s["raceW"]; }
        if (type == A_LEAGUE) { return s["lgBest"]; }
        if (type == A_LONG) { return s["long"]; }
        return s["quests"];
    }

    function check(eng) {
        if (eng.preview != null || Preview.ON) { return; }
        for (var i = 0; i < COUNT; i++) {
            if (eng.ach[i] != 0) { continue; }
            if (value(eng, TYPE[i]) >= TARGET[i]) {
                eng.ach[i] = 1;
                if (RewardSystem.grant(eng, "a" + i.toString(), 0, PEARLS[i], 0, 25)) {
                    RewardSystem.card(eng, "ACHIEVEMENT", NAME[i], [DESC[i], RewardSystem.summary(0, PEARLS[i], 0)],
                        RewardSystem.IC_GRID, SpriteData.ICON_TROPHY, 0xFFC93C);
                }
            }
        }
    }

    function unlockedCount(eng) {
        var n = 0;
        for (var i = 0; i < COUNT; i++) { if (eng.ach[i] != 0) { n++; } }
        return n;
    }
}
