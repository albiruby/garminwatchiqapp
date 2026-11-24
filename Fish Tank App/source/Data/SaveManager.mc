import Toybox.Application;
import Toybox.Lang;

// Whole game state lives in one versioned dictionary under a single Storage key.
//
// v1 keys: v, ob onboarded, st style, th theme, c coins, cf coin fraction, lv player level,
//   xp, cl cleanliness, f fish, dc owned decor, fd food stock, sf selected food, ls last seen,
//   rd last gift day, sk gift streak, dx FishDex, hp haptics
// v2 adds: pl pearls, ky keys, alv aquarium level, tp training points, it install time,
//   nid next fish id, dp placed decor per slot, tx reward ledger {id => day},
//   stt stats, stp step milestones, ds steps per day, q quests, ach achievements,
//   lg league, wk consistency week, rc run coins per day, dd fallback distance,
//   egg incubator, eb egg bag, brd breeding, mg mini-game limits, la low animation,
//   tf tap-to-feed, tu tutorial step, exp expedition regions announced
// v3 adds: evp event quest progress, bd birthday [month, day], race race day, lrc last race
//   reward day, hs Hijri date correction in days
// v3 (1.1) adds, filled in by migrate(): rl run log per day {day => [meters, runs, fastRuns]}
// Fish v2: [species, satiety, happiness, health, growth, fishXp, variant, evolved, raceSkill, id]
module SaveManager {
    const KEY = "tank";
    const VERSION = 3;

    function defaults() {
        return {
            "v" => VERSION, "ob" => false, "st" => 0, "th" => 3,
            "c" => 50, "cf" => 0.0, "lv" => 1, "xp" => 0, "cl" => 100.0,
            "f" => [], "dc" => [], "fd" => [0, 3, 1], "sf" => 0,
            "ls" => 0, "rd" => 0, "sk" => 0, "dx" => newDex(), "hp" => true,
            "pl" => 0, "ky" => 0, "alv" => 1, "tp" => 0, "it" => 0, "nid" => 1,
            "dp" => [-1, -1, -1, -1, -1, -1], "tx" => {}, "stt" => newStats(),
            "stp" => [0, 0], "ds" => {}, "q" => {}, "ach" => newAch(),
            "lg" => {}, "wk" => {}, "rc" => [0, 0], "dd" => [0, 0],
            "egg" => [], "eb" => [], "brd" => [], "mg" => {},
            "la" => false, "tf" => true, "tu" => 0, "exp" => 0,
            "evp" => {}, "bd" => [], "race" => 0, "lrc" => -999, "hs" => 0, "rl" => {}
        };
    }

    function newDex() {
        var a = new [FishDatabase.COUNT];
        for (var i = 0; i < a.size(); i++) { a[i] = 0; }
        return a;
    }

    function newAch() {
        var a = new [AchievementSystem.COUNT];
        for (var i = 0; i < a.size(); i++) { a[i] = 0; }
        return a;
    }

    function newStats() {
        return {"km" => 0, "runs" => 0, "dur" => 0, "long" => 0, "pace" => 0, "b5" => 0, "b10" => 0,
                "ac" => 0, "hatch" => 0, "evo" => 0, "breed" => 0, "var" => 0, "steps" => 0,
                "quests" => 0, "raceW" => 0, "bub" => 0, "dive" => 0, "streak" => 0, "lgBest" => 0,
                "evq" => 0, "rday" => 0, "yr" => {}, "tpm" => 0, "fkm" => 0, "rmax" => 0};
    }

    function migrate(d) {
        var ver = d.get("v");
        if (ver == null) { ver = 0; }

        if (ver < 2) {
            // v1 FishDex was a 12-bit number
            var old = d.get("dx");
            if (old instanceof Number) {
                var dex = newDex();
                for (var i = 0; i < 12; i++) {
                    if ((old & (1 << i)) != 0) { dex[i] = 1; }
                }
                d.put("dx", dex);
            }
            // v1 fish had 5 fields
            var fa = d.get("f");
            var nid = 1;
            if (fa != null) {
                for (var i = 0; i < fa.size(); i++) {
                    var a = fa[i];
                    if (a.size() < 10) {
                        fa[i] = [a[0], a[1], a[2], a[3], a[4], 0, 0, false, 0, nid];
                        nid += 1;
                    }
                }
            }
            d.put("nid", nid);
            // v1 owned decor was shown in order; place the first ones into slots
            var dc = d.get("dc");
            var dp = [-1, -1, -1, -1, -1, -1];
            if (dc != null) {
                for (var i = 0; i < dc.size() && i < 2; i++) { dp[i] = dc[i]; }
            }
            d.put("dp", dp);
            // v1 level gave fish slots; give an equivalent aquarium level
            var lv = d.get("lv");
            if (lv != null) {
                var alv = 1;
                if (lv >= 5) { alv = 3; } else if (lv >= 2) { alv = 2; }
                d.put("alv", alv);
            }
        }

        // Missing values, and values of the wrong kind (a damaged or hand-edited save),
        // fall back to defaults: Monkey C cannot catch a type error, so one bad value would
        // otherwise crash the app on every start.
        var def = defaults();
        var keys = def.keys();
        for (var i = 0; i < keys.size(); i++) {
            var k = keys[i];
            var v = d.get(k);
            if (v == null || !sameKind(v, def[k])) {
                d.put(k, def[k]);
            } else if (def[k] instanceof Number && !(v instanceof Number)) {
                d.put(k, v.toNumber());
            }
        }
        // fixed-size arrays the code indexes directly
        d.put("dp", fitArray(d["dp"], 6, -1));
        d.put("fd", fitArray(d["fd"], 3, 0));
        d.put("rc", fitArray(d["rc"], 2, 0));
        d.put("stp", fitArray(d["stp"], 2, 0));
        if (d["dd"].size() < 2) { d.put("dd", [0, 0, 0]); }
        // grow arrays that gained entries in later versions
        d.put("dx", padArray(d["dx"], FishDatabase.COUNT));
        d.put("ach", padArray(d["ach"], AchievementSystem.COUNT));
        var stt = d["stt"];
        var ds = newStats();
        var sk = ds.keys();
        for (var i = 0; i < sk.size(); i++) {
            var v = stt.get(sk[i]);
            if (v == null || !sameKind(v, ds[sk[i]])) { stt.put(sk[i], ds[sk[i]]); }
        }
        d.put("v", VERSION);
        return d;
    }

    function sameKind(v, def) {
        if (def instanceof Dictionary) { return v instanceof Dictionary; }
        if (def instanceof Array) { return v instanceof Array; }
        if (def instanceof Boolean) { return v instanceof Boolean; }
        if (def instanceof String) { return v instanceof String; }
        return v instanceof Number || v instanceof Float || v instanceof Long || v instanceof Double;
    }

    // Exactly n entries: extra ones dropped, missing ones filled with `fill`.
    function fitArray(a, n, fill) {
        if (a.size() == n) { return a; }
        var out = new [n];
        for (var i = 0; i < n; i++) { out[i] = i < a.size() ? a[i] : fill; }
        return out;
    }

    function padArray(a, n) {
        if (a.size() >= n) { return a; }
        var out = new [n];
        for (var i = 0; i < n; i++) { out[i] = i < a.size() ? a[i] : 0; }
        return out;
    }

    // Storage values are limited to 32 KB each, so the growing parts of the save live
    // under their own keys. Older single-key saves still load (the parts are just missing).
    const PART_KEYS = ["tank_tx", "tank_x"];
    const PARTS = [["tx"], ["stt", "ds", "q", "lg", "wk", "evp", "egg", "eb", "mg", "ach", "dx", "rl"]];

    function load() {
        var d = null;
        try {
            d = Application.Storage.getValue(KEY);
            if (d != null && d instanceof Dictionary) {
                for (var i = 0; i < PART_KEYS.size(); i++) {
                    var p = Application.Storage.getValue(PART_KEYS[i]);
                    if (p != null && p instanceof Dictionary) {
                        var ks = p.keys();
                        for (var j = 0; j < ks.size(); j++) { d.put(ks[j], p[ks[j]]); }
                    }
                }
            }
        } catch (e) {
            d = null;
        }
        if (d == null || !(d instanceof Dictionary)) {
            return null;
        }
        return migrate(d);
    }

    // Returns false if anything could not be written (storage full).
    function save(d) {
        return saveParts(d, true);
    }

    // Writing storage is the slowest thing the app does, and the reward ledger is the
    // biggest part. `withTx` false keeps the stored ledger (it has not changed).
    function saveParts(d, withTx) {
        var core = {};
        var ks = d.keys();
        for (var i = 0; i < ks.size(); i++) { core.put(ks[i], d[ks[i]]); }
        try {
            for (var i = 0; i < PART_KEYS.size(); i++) {
                var part = {};
                var names = PARTS[i];
                for (var j = 0; j < names.size(); j++) {
                    if (d.hasKey(names[j])) {
                        part.put(names[j], d[names[j]]);
                        core.remove(names[j]);
                    }
                }
                if (i > 0 || withTx) { Application.Storage.setValue(PART_KEYS[i], part); }
            }
            Application.Storage.setValue(KEY, core);
        } catch (e) {
            return false;
        }
        return true;
    }

    function clear() {
        Application.Storage.deleteValue(KEY);
        for (var i = 0; i < PART_KEYS.size(); i++) { Application.Storage.deleteValue(PART_KEYS[i]); }
    }
}
