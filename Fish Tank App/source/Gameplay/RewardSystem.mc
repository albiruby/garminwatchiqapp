import Toybox.Lang;

// Every reward goes through grant() with a transaction id. The id is recorded in the save's
// ledger ("tx") so a reward can never be paid twice, even if the app restarts mid-way.
// Reward cards are queued here and shown one by one on the tank screen.
module RewardSystem {
    const KEEP_DAYS = 120;

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

    // Drops ledger entries older than KEEP_DAYS (run ids are also bounded by install time).
    function prune(eng) {
        var today = eng.dayKey();
        var ks = eng.tx.keys();
        for (var i = 0; i < ks.size(); i++) {
            var d = eng.tx[ks[i]];
            if (d != null && today - d > KEEP_DAYS) { eng.tx.remove(ks[i]); }
        }
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
