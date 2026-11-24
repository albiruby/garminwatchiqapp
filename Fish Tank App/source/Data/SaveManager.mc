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
// Fish v2: [species, satiety, happiness, health, growth, fishXp, variant, evolved, raceSkill, id]
module SaveManager {
    const KEY = "tank";
    const VERSION = 2;

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
            "la" => false, "tf" => true, "tu" => 0, "exp" => 0
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
                "quests" => 0, "raceW" => 0, "bub" => 0, "dive" => 0, "streak" => 0, "lgBest" => 0};
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

        var def = defaults();
        var keys = def.keys();
        for (var i = 0; i < keys.size(); i++) {
            if (!d.hasKey(keys[i]) || d[keys[i]] == null) {
                d.put(keys[i], def[keys[i]]);
            }
        }
        // grow arrays that gained entries in later versions
        d.put("dx", padArray(d["dx"], FishDatabase.COUNT));
        d.put("ach", padArray(d["ach"], AchievementSystem.COUNT));
        var stt = d["stt"];
        var ds = newStats();
        var sk = ds.keys();
        for (var i = 0; i < sk.size(); i++) {
            if (!stt.hasKey(sk[i])) { stt.put(sk[i], 0); }
        }
        d.put("v", VERSION);
        return d;
    }

    function padArray(a, n) {
        if (a.size() >= n) { return a; }
        var out = new [n];
        for (var i = 0; i < n; i++) { out[i] = i < a.size() ? a[i] : 0; }
        return out;
    }

    function load() {
        var d = null;
        try {
            d = Application.Storage.getValue(KEY);
        } catch (e) {
            d = null;
        }
        if (d == null || !(d instanceof Dictionary)) {
            return null;
        }
        return migrate(d);
    }

    function save(d) {
        try {
            Application.Storage.setValue(KEY, d);
        } catch (e) {
            // Storage full or unavailable: keep playing, the next save retries.
        }
    }

    function clear() {
        Application.Storage.deleteValue(KEY);
    }
}
