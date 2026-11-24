import Toybox.Lang;

// Aquarium League: a personal weekly league (no server). Points come from running (10/km),
// active days (15), quests (20/50) and the tank rating at week end. The rival target follows
// your own 4-week average, scaled by tier. Beat it to promote; fall under 60% to drop a tier.
// State lg = {w week, s score, t tier, h [last 4 scores]}.
module LeagueSystem {
    const TIER_NAME = ["Bronze", "Silver", "Gold", "Coral", "Abyss"];
    const TIER_COLOR = [0xCD7F32, 0xC0C8D0, 0xFFC93C, 0xFF8BA8, 0x9A7BFF];
    const TIER_F = [0.8, 1.0, 1.15, 1.3, 1.5];
    const FLOOR = [150, 250, 400, 600, 850];
    const REWARD_C = [50, 80, 120, 180, 250];
    const REWARD_P = [0, 1, 2, 3, 5];

    function ensure(eng) {
        if (eng.league.get("w") == null) {
            eng.league = {"w" => TimeUtil.weekOf(TimeUtil.today()), "s" => 0, "t" => 0, "h" => []};
        }
    }

    function add(eng, pts) {
        if (eng.preview != null) { return; }
        ensure(eng);
        check(eng);
        eng.league["s"] = eng.league["s"] + pts;
    }

    function target(eng) {
        ensure(eng);
        var h = eng.league["h"];
        var t = eng.league["t"];
        var avg = 0;
        for (var i = 0; i < h.size(); i++) { avg += h[i]; }
        if (h.size() > 0) { avg = avg / h.size(); }
        var v = (avg * TIER_F[t]).toNumber();
        return v < FLOOR[t] ? FLOOR[t] : v;
    }

    // Week rollover: score the finished week, move tiers, pay the league reward.
    function check(eng) {
        ensure(eng);
        var w = TimeUtil.weekOf(TimeUtil.today());
        var lg = eng.league;
        if (lg["w"] == w) { return; }
        var score = lg["s"] + HabitatSystem.stars(eng) * 10;
        var tgt = target(eng);
        var t = lg["t"];
        var msg = "Stayed in " + TIER_NAME[t];
        if (score >= tgt && t < TIER_NAME.size() - 1) {
            t += 1;
            msg = "Promoted to " + TIER_NAME[t] + "!";
        } else if (score < tgt * 6 / 10 && t > 0) {
            t -= 1;
            msg = "Dropped to " + TIER_NAME[t];
        }
        var h = lg["h"];
        h.add(score);
        if (h.size() > 4) { h = h.slice(h.size() - 4, null); }
        var tx = "lg" + lg["w"].toString();
        eng.league = {"w" => w, "s" => 0, "t" => t, "h" => h};
        if (t > eng.stats["lgBest"]) { eng.stats["lgBest"] = t; }
        if (score > 0 && RewardSystem.grant(eng, tx, REWARD_C[t], REWARD_P[t], 0, 30)) {
            RewardSystem.card(eng, "LEAGUE RESULT", msg, [score.toString() + " / " + tgt.toString() + " pts",
                RewardSystem.summary(REWARD_C[t], REWARD_P[t], 0)], RewardSystem.IC_GRID, SpriteData.ICON_SHIELD, TIER_COLOR[t]);
            eng.achDirty = true;
        }
    }
}
