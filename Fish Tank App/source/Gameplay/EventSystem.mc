import Toybox.Lang;

// Seasonal events that repeat every year from the watch's date: no server, no updates.
// Fixed-date events use the calendar; Global Running Day follows a rule; Ramadan, Eid and
// Lunar New Year are computed (tabular Hijri calendar, mean lunar month).
// Each occurrence is identified by its start day, so rewards pay once per occurrence.
// Each event has a quest; finishing it gives an exclusive "edition" fish egg.
module EventSystem {
    const K_FIXED = 0;
    const K_RUNDAY = 1;     // first Wednesday of June
    const K_RAMADAN = 2;
    const K_EID = 3;
    const K_LNY = 4;
    const COUNT = 15;

    const NAME = ["New Year", "Valentine's Week", "Earth Day", "World Turtle Day", "Global Running Day",
                  "World Oceans Day", "Indonesia Day", "Haornas", "Batik Day", "Halloween",
                  "National Fish Day", "Year-End Festival", "Ramadan", "Eid al-Fitr", "Lunar New Year"];
    const DESC = ["Run coins x1.2 all week", "Breeding is half price and twice as fast", "The tank stays clean longer",
                  "More mystery finds on runs", "Run coins x2 today!", "Rare variants twice as likely, run coins x1.25",
                  "17 Aug: run coins x1.17", "National Sports Day: run coins x1.5", "Fish grow 50% faster",
                  "Deep-sea fish hatch from eggs", "Food packs half price", "More mystery finds, plus your year in review",
                  "Calm waters: the tank stays clean", "THR gift and more mystery finds", "Angpao gift and more mystery finds"];
    const KIND = [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 2, 3, 4];
    const MON = [1, 2, 4, 5, 6, 6, 8, 9, 9, 10, 11, 12, 0, 0, 0];
    const DAY = [1, 10, 20, 21, 0, 5, 14, 6, 30, 25, 18, 20, 0, 0, 0];
    const LEN = [7, 7, 7, 7, 1, 7, 7, 7, 7, 7, 7, 12, 30, 7, 7];
    const MOD = [-1, 7, 2, 3, -1, 6, -1, -1, 0, 5, 1, 3, 2, 3, 3];
    const RUN = [120, 100, 100, 100, 200, 125, 117, 150, 100, 100, 100, 100, 100, 100, 100];   // run coin %
    const GIFT = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, 88];                           // coins on start
    // event quest: [QuestSystem type, target]
    const QUEST = [[0, 10000], [6, 10], [4, 3], [1, 3], [1, 1], [0, 15000], [0, 17000], [1, 3],
                   [3, 10], [5, 3], [7, 1], [0, 20000], [1, 8], [6, 5], [3, 8]];
    // edition fish: species and its two edition colors (body, fins)
    const SPECIES = [4, 6, 21, 14, 17, 1, 7, 23, 20, 33, 8, 28, 22, 16, 19];
    const COL_A = [0xFFD84A, 0xFF6B9A, 0x48B04E, 0x2FD6C0, 0xFF8C2E, 0x2FD6C0, 0xE0303F, 0xFF8C2E,
                   0x8B5A2B, 0xFF8C2E, 0x2E9BFF, 0xFFFFFF, 0xC8D6FF, 0x2FA85A, 0xE0303F];
    const COL_B = [0xFFFFFF, 0xE0303F, 0x8BD45E, 0x1E9E8E, 0xFFD21F, 0x4F7BFF, 0xFFFFFF, 0xFFC93C,
                   0xFFC93C, 0x7A3AB0, 0xFFFFFF, 0xE0303F, 0xFFD84A, 0xFFD84A, 0xFFD21F];
    const UI = [0xFFC93C, 0xFF6B9A, 0x5EE36A, 0x2FD6C0, 0xFF8C2E, 0x4FA3FF, 0xE0303F, 0xFF9F43,
                0xC98A10, 0xFF8C2E, 0x7FE7FF, 0x9FE8FF, 0xFFD84A, 0x5EE36A, 0xE0303F];
    const QUEST_COINS = 60;
    const QUEST_PEARLS = 3;

    // ---- occurrences -------------------------------------------------------------
    // Start days of event `id` that fall in Gregorian year gy.
    function starts(eng, id, gy) {
        var k = KIND[id];
        if (k == K_FIXED) { return [CalendarUtil.daysFromCivil(gy, MON[id], DAY[id])]; }
        if (k == K_RUNDAY) { return [CalendarUtil.firstWeekday(gy, 6, 2)]; }
        if (k == K_LNY) { return [CalendarUtil.lunarNewYear(gy)]; }
        var out = [];
        var cands = CalendarUtil.hijriCandidates(gy);
        for (var i = 0; i < cands.size(); i++) {
            var s = CalendarUtil.islamicDays(cands[i], k == K_RAMADAN ? 9 : 10, 1) + eng.hijriShift;
            if (CalendarUtil.year(s) == gy && out.indexOf(s) < 0) { out.add(s); }
        }
        return out;
    }

    // [[id, startDay], ...] active on `day`.
    function activeOn(eng, day) {
        var out = [];
        var gy = CalendarUtil.year(day);
        for (var id = 0; id < COUNT; id++) {
            for (var y = gy - 1; y <= gy; y++) {
                var ss = starts(eng, id, y);
                for (var i = 0; i < ss.size(); i++) {
                    if (day >= ss[i] && day < ss[i] + LEN[id]) { out.add([id, ss[i]]); }
                }
            }
        }
        return out;
    }

    // Next `n` upcoming occurrences after today: [[id, startDay], ...] sorted by date.
    function upcoming(eng, today, n) {
        var gy = CalendarUtil.year(today);
        var all = [];
        for (var id = 0; id < COUNT; id++) {
            var best = -1;
            for (var y = gy; y <= gy + 1; y++) {
                var ss = starts(eng, id, y);
                for (var i = 0; i < ss.size(); i++) {
                    if (ss[i] > today && (best < 0 || ss[i] < best)) { best = ss[i]; }
                }
            }
            if (best > 0) { all.add([id, best]); }
        }
        for (var i = 1; i < all.size(); i++) {
            var cur = all[i];
            var j = i - 1;
            while (j >= 0 && all[j][1] > cur[1]) {
                all[j + 1] = all[j];
                j--;
            }
            all[j + 1] = cur;
        }
        return all.size() > n ? all.slice(0, n) : all;
    }

    // ---- daily refresh ----------------------------------------------------------------
    // Recomputes active events and modifiers; shows each event's opening card once.
    function refresh(eng) {
        var today = TimeUtil.today();
        eng.events = activeOn(eng, today);
        Mods.reset();
        var w = TimeUtil.weekOf(today);
        Mods.apply(WeeklySystem.MODS[WeeklySystem.current(w)]);
        Mods.spotlight = WeeklySystem.spotlight(w);
        var mul = 1.0;
        for (var i = 0; i < eng.events.size(); i++) {
            var id = eng.events[i][0];
            if (MOD[id] >= 0) { Mods.apply(MOD[id]); }
            mul = mul * RUN[id] / 100.0;
        }
        Mods.runMul = mul;
        if (!eng.onboarded || eng.preview != null || Preview.ON || eng.tutorialActive()) { return; }

        for (var i = 0; i < eng.events.size(); i++) {
            var id = eng.events[i][0];
            var start = eng.events[i][1];
            var tx = "es" + key(eng, id, start);
            if (RewardSystem.done(eng, tx)) { continue; }
            RewardSystem.grant(eng, tx, GIFT[id], 0, 0, 0);
            var q = QUEST[id];
            var lines = [DESC[id], "Quest: " + QuestSystem.label(q[0], q[1])];
            if (GIFT[id] > 0) { lines.add("Gift: +" + GIFT[id].toString() + " coins"); }
            RewardSystem.card(eng, "EVENT", NAME[id], lines, RewardSystem.IC_FISH, [SPECIES[id], false, edition(id)], UI[id]);
            if (id == 11) { yearReview(eng, today); }
        }
        WeeklySystem.refresh(eng, w);
        personal(eng, today);
    }

    // Variant bits for an event's edition fish (bits 3-6 = event id + 1).
    function edition(id) {
        return (id + 1) << 3;
    }

    function editionName(variant) {
        var e = (variant >> 3) & 15;
        return e == 0 ? null : NAME[e - 1] + " edition";
    }

    // Ledger / progress id of one occurrence. Ramadan and Eid are keyed by their date
    // before the user's Hijri correction, so changing the correction in Settings moves the
    // event but can never open it (gift, quest, edition egg) a second time.
    function key(eng, id, start) {
        var k = KIND[id];
        if (k == K_RAMADAN || k == K_EID) { start -= eng.hijriShift; }
        return id.toString() + "_" + start.toString();
    }

    // Run-coin multiplier of the events running on `day`.
    function runMulOn(eng, day) {
        var ev = activeOn(eng, day);
        var mul = 1.0;
        for (var i = 0; i < ev.size(); i++) { mul = mul * RUN[ev[i][0]] / 100.0; }
        return mul;
    }

    // Quest progress from gameplay (called through QuestSystem.event).
    function event(eng, type, amount) {
        eventOn(eng, type, amount, null);
    }

    // `day` (or null = today) is when it happened: a run read later only counts for events
    // that were running on the day of the run.
    function eventOn(eng, type, amount, day) {
        if (eng.preview != null || eng.events == null) { return; }
        for (var i = 0; i < eng.events.size(); i++) {
            var id = eng.events[i][0];
            var q = QUEST[id];
            if (q[0] != type) { continue; }
            var start = eng.events[i][1];
            if (day != null && (day < start || day >= start + LEN[id])) { continue; }
            var k = key(eng, id, start);
            var v = eng.evp.get(k);
            v = (v == null ? 0 : v) + amount;
            eng.evp.put(k, v);
            if (v >= q[1] && RewardSystem.grant(eng, "eq" + k, QUEST_COINS, QUEST_PEARLS, 0, 40)) {
                CollectionSystem.addEgg(eng, 5, SPECIES[id], edition(id));
                eng.stats["evq"] = eng.stats["evq"] + 1;
                RewardSystem.card(eng, "EVENT QUEST DONE", NAME[id],
                    [RewardSystem.summary(QUEST_COINS, QUEST_PEARLS, 0), "+ " + FishDatabase.NAME[SPECIES[id]] + " edition egg"],
                    RewardSystem.IC_EGG, 5, UI[id]);
                eng.achDirty = true;
            }
        }
    }

    function progress(eng, id, start) {
        var v = eng.evp.get(key(eng, id, start));
        return v == null ? 0 : v;
    }

    // Old progress entries are dropped after 400 days.
    function prune(eng, today) {
        var ks = eng.evp.keys();
        for (var i = 0; i < ks.size(); i++) {
            var k = ks[i];
            var cut = k.find("_");
            if (cut == null) { continue; }
            var start = k.substring(cut + 1, k.length()).toNumber();
            if (start != null && today - start > 400) { eng.evp.remove(k); }
        }
    }

    function yearReview(eng, today) {
        var y = CalendarUtil.year(today);
        var tx = "yr" + y.toString();
        if (RewardSystem.done(eng, tx)) { return; }
        RewardSystem.mark(eng, tx);
        var yr = eng.stats["yr"];
        var e = yr.get(y);
        var m = e == null ? 0 : e[0];
        var runs = e == null ? 0 : e[1];
        RewardSystem.card(eng, "YOUR " + y.toString(), ActivitySystem.fmtKm(m) + " km run",
            [runs.toString() + " runs", eng.dexCount().toString() + " species discovered", AchievementSystem.unlockedCount(eng).toString() + " trophies"],
            RewardSystem.IC_GRID, SpriteData.ICON_TROPHY, 0xFFC93C);
    }

    // ---- personal events -------------------------------------------------------------
    const RACE_MIN_LEAD = 7;       // a race must be set at least a week ahead
    const RACE_MIN_M = 5000;
    const RACE_COOLDOWN = 30;      // days between race rewards
    const TAPER_RUNS = 3;

    // Returns null when accepted, otherwise why not.
    function setRace(eng, day) {
        var today = TimeUtil.today();
        if (day < today + RACE_MIN_LEAD) { return "Pick a date at least 7 days ahead"; }
        if (day > today + 365) { return "Pick a date within a year"; }
        eng.race = day;
        eng.save();
        return null;
    }

    function setBirthday(eng, m, d) {
        if (eng.bday.size() == 2) { return "Birthday is already set"; }
        eng.bday = [m, d];
        eng.save();
        return null;
    }

    function personal(eng, today) {
        var c = CalendarUtil.civilFromDays(today);
        // Birthday: a 3-day window so a busy birthday is not missed.
        if (eng.bday.size() == 2) {
            var bd = CalendarUtil.daysFromCivil(c[0], eng.bday[0], eng.bday[1]);
            if (today >= bd && today < bd + 3 && RewardSystem.grant(eng, "bd" + c[0].toString(), 50, 5, 2, 30)) {
                CollectionSystem.addEgg(eng, 1, -1, 0);
                RewardSystem.card(eng, "HAPPY BIRTHDAY!", "+50 coins  +5 pearls  +2 keys", ["+ Rare Egg", "Your fish made you a cake"],
                    RewardSystem.IC_GRID, SpriteData.ICON_STAR, 0xFF8BEF);
            }
        }
        // Tank anniversary
        if (eng.installTime > 0) {
            var ic = CalendarUtil.civilFromDays(TimeUtil.dayOf(eng.installTime));
            var years = c[0] - ic[0];
            if (years > 0 && c[1] == ic[1] && c[2] == ic[2] && RewardSystem.grant(eng, "an" + c[0].toString(), 0, years * 2, 1, 30)) {
                RewardSystem.card(eng, "TANK ANNIVERSARY", years.toString() + " year" + (years > 1 ? "s" : "") + " together!",
                    [RewardSystem.summary(0, years * 2, 1)], RewardSystem.IC_GRID, SpriteData.ICON_TROPHY, 0x7FE7FF);
            }
        }
        // A race date that has passed is cleared.
        if (eng.race > 0 && today > eng.race + 1) { eng.race = 0; }
    }

    // Called for every paid run.
    function onRun(eng, day, meters) {
        if (eng.race <= 0) { return; }
        if (day >= eng.race - 7 && day < eng.race) {
            var k = "taper_" + eng.race.toString();
            var v = eng.evp.get(k);
            v = (v == null ? 0 : v) + 1;
            eng.evp.put(k, v);
            if (v >= TAPER_RUNS && RewardSystem.grant(eng, "tp" + eng.race.toString(), 20, 2, 0, 20)) {
                RewardSystem.card(eng, "RACE PREP DONE", "+20 coins  +2 pearls", ["Rest up - race in " + (eng.race - day).toString() + " days"],
                    RewardSystem.IC_GRID, SpriteData.ICON_SHOE, 0x5EE36A);
            }
        }
        if (day == eng.race && meters >= RACE_MIN_M && today() - eng.lastRace >= RACE_COOLDOWN) {
            if (RewardSystem.grant(eng, "race" + day.toString(), 100, 8, 2, 100)) {
                eng.lastRace = day;
                eng.stats["rday"] = eng.stats["rday"] + 1;
                CollectionSystem.addEgg(eng, 3, -1, 0);
                RewardSystem.card(eng, "RACE DAY HERO", ActivitySystem.fmtKm(meters) + " km raced!",
                    ["+100 coins  +8 pearls  +2 keys", "+ Epic Egg"], RewardSystem.IC_GRID, SpriteData.ICON_TROPHY, 0xFFC93C);
                eng.achDirty = true;
            }
        }
    }

    function today() {
        return TimeUtil.today();
    }
}
