import Toybox.Lang;

// Daily (3) and weekly (3) quests drawn deterministically from the date, so the same day
// always shows the same quests. State q = {d, di, dp, w, wi, wp}.
module QuestSystem {
    const Q_RUN_KM = 0;      // target in meters
    const Q_RUNS = 1;
    const Q_STEPS = 2;
    const Q_FEED = 3;
    const Q_CLEAN = 4;
    const Q_GAME = 5;
    const Q_PET = 6;
    const Q_HATCH = 7;
    const Q_DECOR = 8;
    const Q_BUBBLE = 9;      // best Bubble Pop score
    const Q_RACE_WIN = 10;
    const Q_PACE = 11;       // runs under 6:30 /km

    // [type, target, coins, keys, pearls] (daily quests pay coins only)
    const DAILY = [[0, 2000, 30, 0, 0], [0, 3000, 40, 0, 0], [1, 1, 25, 0, 0], [2, 6000, 20, 0, 0], [2, 8000, 30, 0, 0],
                   [3, 3, 15, 0, 0], [4, 1, 15, 0, 0], [5, 1, 15, 0, 0], [6, 3, 10, 0, 0], [9, 20, 20, 0, 0],
                   [10, 1, 25, 0, 0], [11, 1, 35, 0, 0]];
    // [type, target, coins, keys, pearls]
    const WEEKLY = [[0, 10000, 120, 1, 0], [0, 15000, 180, 1, 2], [1, 3, 100, 1, 0], [2, 50000, 120, 1, 1],
                    [5, 5, 80, 0, 1], [7, 1, 100, 0, 1], [8, 2, 80, 1, 0], [10, 3, 120, 1, 1]];

    function check(eng) {
        var day = TimeUtil.today();
        var week = TimeUtil.weekOf(day);
        var q = eng.quests;
        if (q.get("d") == null || day > q["d"]) {
            q.put("d", day);
            q.put("di", pick(day * 31 + 7, DAILY.size()));
            q.put("dp", [0, 0, 0]);
        }
        if (q.get("w") == null || week > q["w"]) {
            q.put("w", week);
            q.put("wi", pick(week * 17 + 3, WEEKLY.size()));
            q.put("wp", [0, 0, 0]);
        }
        refreshSteps(eng);
        refreshRuns(eng);
    }

    function isRunType(type) {
        return type == Q_RUN_KM || type == Q_RUNS || type == Q_PACE;
    }

    function pick(seed, n) {
        var rng = new Rng(seed);
        var out = [];
        while (out.size() < 3) {
            var i = rng.next(n);
            if (out.indexOf(i) < 0) { out.add(i); }
        }
        return out;
    }

    function label(type, target) {
        if (type == Q_RUN_KM) { return "Run " + ActivitySystem.fmtKm(target) + " km"; }
        if (type == Q_RUNS) { return "Go for " + target.toString() + " run" + (target > 1 ? "s" : ""); }
        if (type == Q_STEPS) { return "Walk " + Util.thousands(target) + " steps"; }
        if (type == Q_FEED) { return "Feed your fish " + target.toString() + "x"; }
        if (type == Q_CLEAN) { return "Clean the tank"; }
        if (type == Q_GAME) { return "Play " + target.toString() + " mini-game" + (target > 1 ? "s" : ""); }
        if (type == Q_PET) { return "Pet your fish " + target.toString() + "x"; }
        if (type == Q_HATCH) { return "Hatch an egg"; }
        if (type == Q_DECOR) { return "Place " + target.toString() + " decorations"; }
        if (type == Q_BUBBLE) { return "Score " + target.toString() + " in Bubble Pop"; }
        if (type == Q_RACE_WIN) { return "Win " + target.toString() + " fish race" + (target > 1 ? "s" : ""); }
        return "Run under 6:30 /km";
    }

    // Steps are absolute: daily = today's steps, weekly = sum of the week's days.
    function refreshSteps(eng) {
        var q = eng.quests;
        var day = TimeUtil.today();
        var di = q["di"];
        var wi = q["wi"];
        var todaySteps = eng.ds.get(day);
        if (todaySteps == null) { todaySteps = 0; }
        var weekSum = 0;
        var w = TimeUtil.weekOf(day);
        var ks = eng.ds.keys();
        for (var i = 0; i < ks.size(); i++) {
            if (TimeUtil.weekOf(ks[i]) == w) { weekSum += eng.ds[ks[i]]; }
        }
        for (var i = 0; i < 3; i++) {
            if (DAILY[di[i]][0] == Q_STEPS) { setProgress(eng, true, i, todaySteps); }
            if (WEEKLY[wi[i]][0] == Q_STEPS) { setProgress(eng, false, i, weekSum); }
        }
    }

    // Running quests are absolute too, read from the per-day run log (ActivitySystem.addLog):
    // daily = runs dated today, weekly = runs dated this week. A run counts for the day it
    // was run, whenever the app reads it, including runs from before the install.
    function refreshRuns(eng) {
        var q = eng.quests;
        if (q.get("di") == null || eng.preview != null) { return; }
        var day = TimeUtil.today();
        var dl = ActivitySystem.logDay(eng, day);
        var wl = ActivitySystem.logWeek(eng, day);
        var di = q["di"];
        var wi = q["wi"];
        for (var i = 0; i < 3; i++) {
            var td = DAILY[di[i]][0];
            if (isRunType(td)) { setProgress(eng, true, i, runValue(td, dl)); }
            var tw = WEEKLY[wi[i]][0];
            if (isRunType(tw)) { setProgress(eng, false, i, runValue(tw, wl)); }
        }
    }

    function runValue(type, log) {
        if (type == Q_RUN_KM) { return log[0]; }
        if (type == Q_RUNS) { return log[1]; }
        return log[2];
    }

    // A run (or fallback distance) dated `day`: event quests that cover that day, then the
    // daily and weekly quests from the run log.
    function runEvent(eng, day, type, amount) {
        EventSystem.eventOn(eng, type, amount, day);
        refreshRuns(eng);
    }

    function event(eng, type, amount) {
        EventSystem.event(eng, type, amount);
        if (eng.preview != null || eng.quests.get("di") == null) { return; }
        if (type == Q_STEPS) { refreshSteps(eng); return; }
        if (isRunType(type)) { refreshRuns(eng); return; }
        var q = eng.quests;
        for (var i = 0; i < 3; i++) {
            if (DAILY[q["di"][i]][0] == type) { bump(eng, true, i, type, amount); }
            if (WEEKLY[q["wi"][i]][0] == type) { bump(eng, false, i, type, amount); }
        }
    }

    function bump(eng, daily, i, type, amount) {
        var arr = eng.quests[daily ? "dp" : "wp"];
        var v = type == Q_BUBBLE ? (amount > arr[i] ? amount : arr[i]) : arr[i] + amount;
        setProgress(eng, daily, i, v);
    }

    function setProgress(eng, daily, i, v) {
        var q = eng.quests;
        var arr = q[daily ? "dp" : "wp"];
        if (v < arr[i]) { return; }
        arr[i] = v;
        var t = daily ? DAILY[q["di"][i]] : WEEKLY[q["wi"][i]];
        if (v < t[1]) { return; }
        var tx = (daily ? "qd" + q["d"].toString() : "qw" + q["w"].toString()) + "_" + i.toString();
        var keys = daily ? 0 : t[3];
        var pearls = daily ? 0 : t[4];
        if (RewardSystem.grant(eng, tx, t[2], pearls, keys, daily ? 15 : 40)) {
            eng.stats["quests"] = eng.stats["quests"] + 1;
            LeagueSystem.add(eng, daily ? 20 : 50);
            RewardSystem.card(eng, daily ? "DAILY QUEST" : "WEEKLY QUEST", RewardSystem.summary(t[2], pearls, keys),
                [label(t[0], t[1]) + " - done!"], RewardSystem.IC_GRID, SpriteData.ICON_QUEST, 0x9BF08A);
            eng.achDirty = true;
        }
    }

    function isDone(eng, daily, i) {
        var q = eng.quests;
        var t = daily ? DAILY[q["di"][i]] : WEEKLY[q["wi"][i]];
        return q[daily ? "dp" : "wp"][i] >= t[1];
    }

    function openCount(eng) {
        if (eng.quests.get("di") == null) { return 0; }
        var n = 0;
        for (var i = 0; i < 3; i++) {
            if (!isDone(eng, true, i)) { n++; }
            if (!isDone(eng, false, i)) { n++; }
        }
        return n;
    }
}
