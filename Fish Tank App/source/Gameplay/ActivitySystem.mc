import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.Time;
import Toybox.UserProfile;

// Move pillar. Runs are recorded with the watch's own Run app; FISH TANK reads them from
// the activity history when it opens and pays each run exactly once (ledger id "r<start>").
// Runs from the week the app was installed count too, also those from before the install:
// a 5 km run in the morning finishes "Run 5 km today" when the app is installed that night.
// Every counted run is logged per day (eng.rl) so run quests are judged by the day the run
// happened, not the day it was read. Daily steps feed Step Hunter milestones and the weekly
// consistency target; the watch's 7-day step history fills days the app was not opened.
module ActivitySystem {
    const STEP_MS = [3000, 5000, 8000, 10000];
    const STEP_COINS = [10, 15, 25, 40];
    const STEP_KEYS = [0, 0, 0, 1];
    const ACTIVE_STEPS = 8000;          // a day counts as active with a run or this many steps
    const KM_MS = [25, 50, 100, 250, 500];
    const KM_PEARLS = [2, 3, 5, 8, 12];
    const KM_KEYS = [1, 1, 1, 2, 3];
    const KM_EGG = [-1, 2, 3, 4, 4];    // CollectionSystem egg type, -1 none
    const RUN_CAP = 300;                // max run coins per calendar day
    const MIN_RUN_M = 1000;
    const MIN_RUN_S = 300;
    const WEEK_TARGET = 3;              // active days per week for the consistency streak
    const FALLBACK_M_PER_COIN = 200;
    const FALLBACK_CAP = 100;
    const FALLBACK_AFTER_DAYS = 3;      // no run from history this long after install -> fallback
    const FALLBACK_WEIGHT = 50;         // % of daily distance that counts as progress (it includes walking)
    const MAX_RUN_AGE_DAYS = 90;        // older history entries are ignored (ledger keeps 120 days)
    const SCAN_PER_TICK = 6;
    const FAST_PACE = 390;              // s/km: "Run under 6:30 /km" quests
    const BATCH_CARDS = 3;              // this many runs found at once share one summary card
    const LOG_DAYS = 14;                // days kept in the per-day run log

    function historySupported() {
        return (Toybox has :UserProfile) && (UserProfile has :getUserActivityHistory);
    }

    // First local day whose runs count: the Monday of the install week, so runs done earlier
    // that day or week (before the app was installed) still finish quests. 0 = no limit.
    function firstCountedDay(eng) {
        if (eng.installTime <= 0) { return 0; }
        var d0 = TimeUtil.dayOf(eng.installTime);
        return d0 - TimeUtil.weekday(d0);
    }

    // ---- per-day run log ----------------------------------------------------------
    // eng.rl = {day => [meters, runs, fastRuns]}; quests read it (QuestSystem.refreshRuns).
    function addLog(eng, day, meters, runs, fast) {
        var e = eng.rl.get(day);
        if (e == null) { e = [0, 0, 0]; }
        eng.rl.put(day, [e[0] + meters, e[1] + runs, e[2] + fast]);
        var ks = eng.rl.keys();
        var today = TimeUtil.today();
        for (var i = 0; i < ks.size(); i++) {
            if (today - ks[i] > LOG_DAYS) { eng.rl.remove(ks[i]); }
        }
    }

    // [meters, runs, fastRuns] for one day, or summed over that day's week.
    function logDay(eng, day) {
        var e = eng.rl.get(day);
        return e == null ? [0, 0, 0] : e;
    }

    function logWeek(eng, day) {
        var w = TimeUtil.weekOf(day);
        var out = [0, 0, 0];
        var ks = eng.rl.keys();
        for (var i = 0; i < ks.size(); i++) {
            if (TimeUtil.weekOf(ks[i]) != w) { continue; }
            var e = eng.rl[ks[i]];
            out = [out[0] + e[0], out[1] + e[1], out[2] + e[2]];
        }
        return out;
    }

    // Daily distance pays (coins and progress) when the watch cannot give us runs: no history
    // API, or no run has arrived from history several days after install. The first real run
    // switches it off for good.
    function fallbackMode(eng) {
        if (!historySupported()) { return true; }
        if (eng.stats["runs"] > 0 || eng.installTime <= 0) { return false; }
        return TimeUtil.today() - TimeUtil.dayOf(eng.installTime) >= FALLBACK_AFTER_DAYS;
    }

    // Coins for one run: 100 m = 1 coin, x1.1 per consistency week (max x1.5), x1.5 for
    // 10 km+, +20 first run of the week, +10 pace PR, capped by what is left of RUN_CAP today.
    // Returns [coins, multiplier, flatBonus].
    // eventMul: run-coin multiplier from active events (Mods.runMul).
    function payout(meters, streakWeeks, firstOfWeek, isPr, paidToday, eventMul) {
        var sw = streakWeeks > 5 ? 5 : streakWeeks;
        var mul = (1.0 + 0.1 * sw) * eventMul;
        if (meters >= 10000) { mul = mul * 1.5; }
        var c = ((meters / 100) * mul).toNumber();
        var bonus = 0;
        if (firstOfWeek) { bonus += 20; }
        if (isPr) { bonus += 10; }
        c += bonus;
        var room = RUN_CAP - paidToday;
        if (room < 0) { room = 0; }
        if (c > room) { c = room; }
        return [c, mul, bonus];
    }

    // ---- run history scan (spread over ticks) ---------------------------------
    function beginScan(eng) {
        eng.scanIt = null;
        eng.pendingRuns = [];
        eng.scanLog = {};
        eng.scanFrom = firstCountedDay(eng);
        if (Preview.ON || !historySupported()) { return; }
        try {
            eng.scanIt = UserProfile.getUserActivityHistory();
        } catch (e) {
            eng.scanIt = null;
        }
    }

    function stepScan(eng) {
        if (eng.scanIt == null) { return; }
        for (var k = 0; k < SCAN_PER_TICK; k++) {
            var a = null;
            try {
                a = eng.scanIt.next();
            } catch (e) {
                a = null;
            }
            if (a == null) {
                eng.scanIt = null;
                finishScan(eng);
                return;
            }
            consider(eng, a);
        }
    }

    function consider(eng, a) {
        if (a.type == null || a.startTime == null || a.distance == null) { return; }
        if (a.type != Activity.SPORT_RUNNING) { return; }
        var st = a.startTime.value();
        if (TimeUtil.dayOf(st) < eng.scanFrom) { return; }
        if (st < TimeUtil.now() - MAX_RUN_AGE_DAYS * 86400) { return; }
        var dur = a.duration != null ? a.duration.value() : 0;
        if (a.distance < MIN_RUN_M || dur < MIN_RUN_S) { return; }
        // every counted run of the last days, paid or not, rebuilds the run log
        var day = TimeUtil.dayOf(st);
        if (eng.scanLog != null && TimeUtil.today() - day <= LOG_DAYS) {
            var e = eng.scanLog.get(day);
            if (e == null) { e = [0, 0, 0]; }
            var fast = dur * 1000 / a.distance <= FAST_PACE ? 1 : 0;
            eng.scanLog.put(day, [e[0] + a.distance, e[1] + 1, e[2] + fast]);
        }
        if (RewardSystem.done(eng, "r" + st.toString())) { return; }
        eng.pendingRuns.add([st, a.distance, dur]);
    }

    function finishScan(eng) {
        var runs = eng.pendingRuns;
        // oldest first, so streaks and "first run of the week" are judged in order
        for (var i = 1; i < runs.size(); i++) {
            var cur = runs[i];
            var j = i - 1;
            while (j >= 0 && runs[j][0] > cur[0]) {
                runs[j + 1] = runs[j];
                j--;
            }
            runs[j + 1] = cur;
        }
        // Many runs at once (first open, or after days away): one summary card, not a stack.
        var quiet = runs.size() >= BATCH_CARDS;
        var coins = 0;
        var meters = 0;
        var n = 0;
        var early = false;
        for (var i = 0; i < runs.size(); i++) {
            var paid = payRunQ(eng, runs[i][0], runs[i][1], runs[i][2], quiet);
            if (paid >= 0) {
                coins += paid;
                meters += runs[i][1];
                n += 1;
                if (eng.installTime > 0 && runs[i][0] < eng.installTime) { early = true; }
            }
        }
        if (quiet && n > 0) {
            var lines = [n.toString() + " runs  -  " + fmtKm(meters) + " km", "Quests and trophies updated"];
            if (early) { lines.add("Includes runs from before install"); }
            RewardSystem.card(eng, "RUNS FOUND", "+" + coins.toString() + " coins", lines,
                RewardSystem.IC_GRID, SpriteData.ICON_SHOE, 0xFFC93C);
        }
        eng.pendingRuns = [];
        mergeLog(eng);
        if (runs.size() > 0) {
            checkKm(eng);
            ExpeditionSystem.check(eng);
            eng.achDirty = true;
            eng.save();
        }
    }

    // The history holds every run of the last days, including ones paid by an older version
    // that kept no log: take the larger value per day so the log is complete either way.
    function mergeLog(eng) {
        var h = eng.scanLog;
        eng.scanLog = null;
        if (h == null) { return; }
        var ks = h.keys();
        var changed = false;
        for (var i = 0; i < ks.size(); i++) {
            var a = h[ks[i]];
            var b = logDay(eng, ks[i]);
            var m = [a[0] > b[0] ? a[0] : b[0], a[1] > b[1] ? a[1] : b[1], a[2] > b[2] ? a[2] : b[2]];
            if (m[0] != b[0] || m[1] != b[1] || m[2] != b[2]) {
                eng.rl.put(ks[i], m);
                changed = true;
            }
        }
        if (changed) { QuestSystem.refreshRuns(eng); }
    }

    function payRun(eng, start, meters, dur) {
        return payRunQ(eng, start, meters, dur, false);
    }

    // Pays one run. `quiet` skips its own card (finishScan shows a summary). Returns the
    // coins paid, or -1 when the run was already paid.
    function payRunQ(eng, start, meters, dur, quiet) {
        var tx = "r" + start.toString();
        if (RewardSystem.done(eng, tx)) { return -1; }
        var day = TimeUtil.dayOf(start);
        var week = TimeUtil.weekOf(day);
        checkWeek(eng);
        var paidToday = eng.rc[0] == day ? eng.rc[1] : 0;
        var firstOfWeek = !RewardSystem.done(eng, "rw" + week.toString());
        var st = eng.stats;
        var pace = dur * 1000 / meters;                // seconds per km
        var isPr = st["pace"] > 0 && pace < st["pace"];
        var p = payout(meters, eng.streakWeeks(), firstOfWeek, isPr, paidToday, Mods.runMul);
        var coins = p[0];

        RewardSystem.grant(eng, tx, coins, 0, 0, meters / 100);
        if (firstOfWeek) { RewardSystem.mark(eng, "rw" + week.toString()); }
        eng.rc = [day, paidToday + coins];

        st["runs"] = st["runs"] + 1;
        st["dur"] = st["dur"] + dur;
        st["ac"] = st["ac"] + coins;
        if (meters > st["long"]) { st["long"] = meters; }
        if (st["pace"] == 0 || pace < st["pace"]) { st["pace"] = pace; }
        if (meters >= 5000 && (st["b5"] == 0 || pace * 5 < st["b5"])) { st["b5"] = pace * 5; }
        if (meters >= 10000 && (st["b10"] == 0 || pace * 10 < st["b10"])) { st["b10"] = pace * 10; }

        var fast = pace <= FAST_PACE;
        addLog(eng, day, 0, 1, fast ? 1 : 0);   // meters are logged by credit()
        credit(eng, day, meters);
        var ye = st["yr"].get(CalendarUtil.year(day));
        ye[1] = ye[1] + 1;
        EventSystem.onRun(eng, day, meters);
        QuestSystem.runEvent(eng, day, QuestSystem.Q_RUNS, 1);
        if (fast) { QuestSystem.runEvent(eng, day, QuestSystem.Q_PACE, 1); }
        markActive(eng, day);

        if (!quiet) { runCard(eng, start, meters, dur, pace, p, coins, firstOfWeek, isPr); }
        // a small chance of a mystery find on every run
        if (Util.rnd(100) < Mods.mystery) { CollectionSystem.mystery(eng, "m" + start.toString()); }
        return coins;
    }

    function runCard(eng, start, meters, dur, pace, p, coins, firstOfWeek, isPr) {
        var lines = [fmtKm(meters) + " km  -  " + fmtTime(dur), fmtPace(pace) + " /km"];
        // bonus groups separated by two spaces so the card wraps between them
        var extra = "";
        if (p[1] > 1.001) { extra = "Bonus x" + p[1].format("%.2f"); }
        if (firstOfWeek) { extra = extra + (extra.length() > 0 ? "  " : "") + "+20 first run"; }
        if (isPr) { extra = extra + (extra.length() > 0 ? "  " : "") + "+10 pace PR"; }
        if (coins < (meters / 100)) { extra = "Daily run cap reached"; }
        if (extra.length() > 0) { lines.add(extra); }
        // a run from before the install is "found", not just rewarded
        var title = (eng.installTime > 0 && start < eng.installTime) ? "RUN FOUND" : "RUN REWARD";
        RewardSystem.card(eng, title, "+" + coins.toString() + " coins", lines, RewardSystem.IC_GRID, SpriteData.ICON_SHOE, 0xFFC93C);
    }

    // ---- steps ------------------------------------------------------------------
    function todaySteps() {
        if (!(Toybox has :ActivityMonitor)) { return null; }
        var info = ActivityMonitor.getInfo();
        if (info == null) { return null; }
        return info;
    }

    function checkSteps(eng) {
        if (Preview.ON) { return; }
        var info = todaySteps();
        if (info == null || info.steps == null) { return; }
        var steps = info.steps;
        var day = TimeUtil.today();
        if (eng.stp[0] != day) { eng.stp = [day, 0]; }
        var prev = eng.ds.get(day);
        if (prev == null || steps > prev) { eng.ds.put(day, steps); }
        pruneDays(eng.ds, day);
        if (steps > eng.stats["steps"]) { eng.stats["steps"] = steps; }
        QuestSystem.event(eng, QuestSystem.Q_STEPS, 0);

        var mask = eng.stp[1];
        var gotC = 0;
        var gotK = 0;
        var reached = 0;
        for (var i = 0; i < STEP_MS.size(); i++) {
            if (steps >= STEP_MS[i] && (mask & (1 << i)) == 0) {
                mask = mask | (1 << i);
                if (RewardSystem.grant(eng, "s" + day.toString() + "_" + i.toString(), STEP_COINS[i], 0, STEP_KEYS[i], 5)) {
                    gotC += STEP_COINS[i];
                    gotK += STEP_KEYS[i];
                    reached = STEP_MS[i];
                }
            }
        }
        eng.stp = [day, mask];
        if (gotC > 0) {
            RewardSystem.card(eng, "STEP HUNTER", RewardSystem.summary(gotC, 0, gotK),
                [Util.thousands(reached) + " steps today"], RewardSystem.IC_GRID, SpriteData.ICON_STEPS, 0x5EE36A);
            eng.achDirty = true;
        }
        if (steps >= ACTIVE_STEPS) { markActive(eng, day); }

        if (info.distance != null && fallbackMode(eng)) { creditDaily(eng, day, info.distance / 100); }
    }

    // Distance credit shared by runs and the fallback: total distance, year log, weekly
    // visitor, training points, fish XP, eggs, running quests and league points.
    function credit(eng, day, meters) {
        var st = eng.stats;
        st["km"] = st["km"] + meters;
        var yr = st["yr"];
        var y = CalendarUtil.year(day);
        var ye = yr.get(y);
        yr.put(y, ye == null ? [meters, 0] : [ye[0] + meters, ye[1]]);
        WeeklySystem.onRun(eng, day, meters);
        st["tpm"] = st["tpm"] + meters;
        while (st["tpm"] >= 1000) {
            st["tpm"] = st["tpm"] - 1000;
            eng.tp += 1;
        }
        var km = meters / 1000.0;
        for (var i = 0; i < eng.fish.size(); i++) { eng.fish[i].fxp += km * 3; }
        CollectionSystem.eggKm(eng, km);
        addLog(eng, day, meters, 0, 0);
        QuestSystem.runEvent(eng, day, QuestSystem.Q_RUN_KM, meters);
        LeagueSystem.add(eng, meters / 100);
    }

    // Fallback: today's distance from the activity monitor, in 200 m units. Coins up to
    // FALLBACK_CAP a day; progress at FALLBACK_WEIGHT % because it includes walking.
    function creditDaily(eng, day, meters) {
        if (eng.dd[0] != day) { eng.dd = [day, 0, 0]; }
        var done = eng.dd[1];
        var coinsToday = eng.dd.size() > 2 ? eng.dd[2] : 0;
        var units = (meters - done) / FALLBACK_M_PER_COIN;
        if (units <= 0) { return; }
        var c = units;
        if (c + coinsToday > FALLBACK_CAP) { c = FALLBACK_CAP - coinsToday; }
        if (c < 0) { c = 0; }
        eng.coins += c;
        eng.dd = [day, done + units * FALLBACK_M_PER_COIN, coinsToday + c];
        var progress = units * FALLBACK_M_PER_COIN * FALLBACK_WEIGHT / 100;
        eng.stats["fkm"] = eng.stats["fkm"] + progress;
        eng.stats["ac"] = eng.stats["ac"] + c;
        credit(eng, day, progress);
        if (c > 0) { eng.pop(195, 140, "+" + c.toString(), 0xFFC93C); }
        checkKm(eng);
        ExpeditionSystem.check(eng);
        eng.achDirty = true;
    }

    // Steps of the past days from the watch's own 7-day history, so a week's step quest and
    // active days include days the app was not opened (or was not installed yet).
    // Runs once per app start.
    function backfillSteps(eng) {
        if (Preview.ON || !(Toybox has :ActivityMonitor) || !(ActivityMonitor has :getHistory)) { return; }
        var h = null;
        try {
            h = ActivityMonitor.getHistory();
        } catch (e) {
            h = null;
        }
        if (h == null) { return; }
        var today = TimeUtil.today();
        for (var i = 0; i < h.size(); i++) {
            var a = h[i];
            if (a == null || a.startOfDay == null || a.steps == null) { continue; }
            // midday of that date, so the day is right whichever midnight the watch reports
            var d = TimeUtil.dayOf(a.startOfDay.value() + 43200);
            if (d >= today || today - d > 7) { continue; }
            var prev = eng.ds.get(d);
            if (prev == null || a.steps > prev) { eng.ds.put(d, a.steps); }
            if (a.steps >= ACTIVE_STEPS) { markActive(eng, d); }
        }
        pruneDays(eng.ds, today);
        if (eng.quests.get("di") != null) { QuestSystem.refreshSteps(eng); }
    }

    function pruneDays(dict, today) {
        var ks = dict.keys();
        for (var i = 0; i < ks.size(); i++) {
            if (today - ks[i] > 14) { dict.remove(ks[i]); }
        }
    }

    // ---- consistency week -------------------------------------------------------
    function checkWeek(eng) {
        var w = TimeUtil.weekOf(TimeUtil.today());
        var wk = eng.wk;
        if (wk.get("k") == null) {
            eng.wk = {"k" => w, "m" => 0, "s" => 0};
            return;
        }
        if (w <= wk["k"]) { return; }   // forward only (clock set back: ignore)
        var s = wk["s"];
        if (bits(wk["m"]) >= WEEK_TARGET && wk["k"] == w - 1) { s += 1; }
        else { s = 0; }
        eng.wk = {"k" => w, "m" => 0, "s" => s};
        if (s > eng.stats["streak"]) { eng.stats["streak"] = s; }
    }

    function markActive(eng, day) {
        checkWeek(eng);
        var wk = eng.wk;
        if (TimeUtil.weekOf(day) != wk["k"]) { return; }
        var bit = 1 << TimeUtil.weekday(day);
        if ((wk["m"] & bit) != 0) { return; }
        wk["m"] = wk["m"] | bit;
        LeagueSystem.add(eng, 15);
        if (bits(wk["m"]) == WEEK_TARGET) {
            if (RewardSystem.grant(eng, "cs" + wk["k"].toString(), 30, 0, 1, 20)) {
                RewardSystem.card(eng, "CONSISTENCY", "+30 coins  +1 key",
                    [WEEK_TARGET.toString() + " active days this week", "Run bonus next week: x" + (1.0 + 0.1 * (wk["s"] + 1 > 5 ? 5 : wk["s"] + 1)).format("%.1f")],
                    RewardSystem.IC_GRID, SpriteData.ICON_STAR, 0x7FE7FF);
            }
        }
    }

    function bits(m) {
        var n = 0;
        for (var i = 0; i < 7; i++) {
            if ((m & (1 << i)) != 0) { n++; }
        }
        return n;
    }

    // ---- distance milestones ------------------------------------------------------
    function checkKm(eng) {
        var km = eng.stats["km"] / 1000;
        for (var i = 0; i < KM_MS.size(); i++) {
            if (km < KM_MS[i]) { continue; }
            if (RewardSystem.grant(eng, "km" + KM_MS[i].toString(), 0, KM_PEARLS[i], KM_KEYS[i], 50)) {
                var lines = [RewardSystem.summary(0, KM_PEARLS[i], KM_KEYS[i])];
                if (KM_EGG[i] >= 0) {
                    CollectionSystem.addEgg(eng, KM_EGG[i], -1, 0);
                    lines.add("+ " + CollectionSystem.EGG_NAME[KM_EGG[i]]);
                }
                RewardSystem.card(eng, "DISTANCE MILESTONE", KM_MS[i].toString() + " km total!", lines,
                    RewardSystem.IC_GRID, SpriteData.ICON_TROPHY, 0xFFC93C);
            }
        }
    }

    // ---- formatting ---------------------------------------------------------------
    function fmtKm(m) {
        return (m / 1000).toString() + "." + ((m % 1000) / 100).toString();
    }

    function fmtTime(sec) {
        var h = sec / 3600;
        var mn = (sec % 3600) / 60;
        var s = sec % 60;
        if (h > 0) { return h.toString() + ":" + mn.format("%02d") + ":" + s.format("%02d"); }
        return mn.toString() + ":" + s.format("%02d");
    }

    function fmtPace(secPerKm) {
        if (secPerKm <= 0) { return "--:--"; }
        return (secPerKm / 60).toString() + ":" + (secPerKm % 60).format("%02d");
    }
}
