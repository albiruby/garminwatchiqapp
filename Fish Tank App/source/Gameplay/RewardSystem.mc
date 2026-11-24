import Toybox.Lang;

// Every reward goes through grant() with a transaction id. The id is recorded in the save's
// ledger ("tx") so a reward can never be paid twice, even if the app restarts mid-way.
// Reward cards are queued here and shown one by one on the tank screen.
module RewardSystem {
    const KEEP_DAYS = 120;
    const MAX_ENTRIES = 500;
    // Run ids ("r<start>", "rw<week>") stay longer than the history scan looks back
    // (ActivitySystem.MAX_RUN_AGE_DAYS), even when the ledger is trimmed hard.
    const RUN_KEEP_DAYS = 100;
    // One-time rewards that must never be paid again, so they are never pruned:
    // distance milestones, achievements, expedition regions, tutorial, tank anniversary.
    const PERMANENT = ["km", "a", "ex", "tut"];

    // Card icon kinds
    const IC_GRID = 0;     // arg = icon rows (SpriteData.ICON_*)
    const IC_FISH = 1;     // arg = [species, evolved, variant]
    const IC_EGG = 2;      // arg = egg type
    const IC_DECOR = 3;    // arg = decor id

    function done(eng, tx) {
        return eng.tx.hasKey(tx);
    }

    function mark(eng, tx) {
        eng.tx.put(tx, eng.dayKey());
        eng.txRev += 1;     // the ledger must be written on the next save
    }

    // Pays once per tx (null tx = always). Returns true when paid now.
    function grant(eng, tx, coins, pearls, keys, xp) {
        if (tx != null) {
            if (eng.tx.hasKey(tx)) { return false; }
            mark(eng, tx);
        }
        eng.coins += coins;
        eng.pearls += pearls;
        eng.keys += keys;
        if (xp > 0) { eng.addXp(xp); }
        return true;
    }

    function permanent(k) {
        for (var i = 0; i < PERMANENT.size(); i++) {
            var p = PERMANENT[i];
            if (k.length() >= p.length() && k.substring(0, p.length()).equals(p)) { return true; }
        }
        return false;
    }

    // Drops dated entries older than KEEP_DAYS. Runs older than
    // ActivitySystem.MAX_RUN_AGE_DAYS (< KEEP_DAYS) are ignored by the scan, so a pruned
    // run can never be paid again. Over MAX_ENTRIES, entries older than 30 days go too.
    function prune(eng) {
        var today = eng.dayKey();
        var keep = eng.tx.size() > MAX_ENTRIES ? 30 : KEEP_DAYS;
        var ks = eng.tx.keys();
        for (var i = 0; i < ks.size(); i++) {
            var d = eng.tx[ks[i]];
            var lim = (keep < RUN_KEEP_DAYS && runKey(ks[i])) ? RUN_KEEP_DAYS : keep;
            if (d != null && today - d > lim && !permanent(ks[i])) {
                eng.tx.remove(ks[i]);
                eng.txRev += 1;
            }
        }
    }

    // "r1732400000" (a paid run) or "rw2864" (first run of a week).
    function runKey(k) {
        if (k.length() < 2 || !k.substring(0, 1).equals("r")) { return false; }
        return "0123456789w".find(k.substring(1, 2)) != null;
    }

    function card(eng, title, big, lines, iconKind, iconArg, col) {
        if (eng.cards.size() >= 12) { return; }
        eng.cards.add({:t => title, :b => big, :l => lines, :i => iconKind, :a => iconArg, :c => col});
    }

    // "+52 coins  +2 pearls  +1 key" for card subtitles.
    function summary(coins, pearls, keys) {
        var s = "";
        if (coins > 0) { s = "+" + coins.toString() + " coins"; }
        if (pearls > 0) { s = s + (s.length() > 0 ? "  " : "") + "+" + pearls.toString() + " pearl" + (pearls > 1 ? "s" : ""); }
        if (keys > 0) { s = s + (s.length() > 0 ? "  " : "") + "+" + keys.toString() + " key" + (keys > 1 ? "s" : ""); }
        return s;
    }
}
