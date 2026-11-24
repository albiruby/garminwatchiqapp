import Toybox.Lang;
import Toybox.Test;

// Failure modes that only show up after weeks of real use.

(:test)
function trimmedLedgerNeverRepaysARun(logger as Logger) as Boolean {
    var e = testEngine();
    var now = TimeUtil.now();
    var start = now - 60 * 86400;
    ActivitySystem.payRun(e, start, 5000, 1500);
    var runs = e.stats["runs"];
    // a ledger past MAX_ENTRIES is trimmed to 30 days, but run ids are kept longer
    for (var i = 0; i < 600; i++) { e.tx.put("x" + i.toString(), e.dayKey() - 40); }
    e.tx.put("r" + start.toString(), e.dayKey() - 60);
    RewardSystem.prune(e);
    Test.assert(e.tx.hasKey("r" + start.toString()));
    Test.assert(!e.tx.hasKey("x1"));
    // and even without the ledger entry, the paid-run mark keeps it from paying again
    e.tx.remove("r" + start.toString());
    e.scanFrom = 0;
    e.pendingRuns = [];
    ActivitySystem.consider(e, new MockRun(start, 5000, 1500));
    Test.assertEqual(e.pendingRuns.size(), 0);
    Test.assertEqual(e.stats["runs"], runs);
    return true;
}

(:test)
function markComesFromAnOldLedger(logger as Logger) as Boolean {
    var e = testEngine();
    var now = TimeUtil.now();
    e.tx.put("r" + (now - 5000).toString(), e.dayKey());
    e.tx.put("r" + (now - 9000).toString(), e.dayKey());
    e.tx.put("rw2900", e.dayKey());
    e.tx.put("race20000", e.dayKey());
    ActivitySystem.initMark(e);
    Test.assertEqual(e.stats["rmax"], now - 5000);
    return true;
}

(:test)
function fitEpochStartTimesAreShifted(logger as Logger) as Boolean {
    var e = testEngine();
    var now = TimeUtil.now();
    e.pendingRuns = [];
    e.scanFrom = 0;
    ActivitySystem.consider(e, new MockRun(now - 120 - ActivitySystem.FIT_EPOCH, 5000, 1500));
    Test.assertEqual(e.pendingRuns.size(), 1);
    Test.assertEqual(e.pendingRuns[0][0], now - 120);
    return true;
}

(:test)
function hijriCorrectionCannotReopenAnEvent(logger as Logger) as Boolean {
    var e = testEngine();
    e.hijriShift = 0;
    var k0 = EventSystem.key(e, 13, 20000);    // Eid
    e.hijriShift = 1;
    var k1 = EventSystem.key(e, 13, 20001);    // same Eid, moved a day by the setting
    Test.assert(k0.equals(k1));
    Test.assert(!EventSystem.key(e, 0, 20000).equals(EventSystem.key(e, 0, 20001)));
    return true;
}

(:test)
function quittingAGameStillUsesThePlay(logger as Logger) as Boolean {
    var e = testEngine();
    for (var i = 0; i < MiniGameRules.DAILY; i++) { Test.assert(e.startGame("td")); }
    Test.assert(!e.startGame("td"));          // the rounds left with BACK counted
    var c = e.coins;
    Test.assert(!e.finishGame("td", 50, 5, false));
    Test.assertEqual(e.coins, c);
    SaveManager.clear();
    return true;
}

(:test)
function damagedSaveLoadsWithDefaults(logger as Logger) as Boolean {
    var d = SaveManager.migrate({"v" => 3, "ob" => true, "c" => "lots", "f" => {}, "dp" => [1],
        "stt" => [], "fd" => [0],
        "q" => {"d" => 5, "di" => [99, 0, 1], "dp" => [0, 0, 0], "w" => 1, "wi" => [0, 1, 2], "wp" => [0, 0, 0]}});
    Test.assertEqual(d["c"], 50);
    Test.assert(d["f"] instanceof Array);
    Test.assertEqual(d["dp"].size(), 6);
    Test.assertEqual(d["fd"].size(), 3);
    Test.assert(d["stt"] instanceof Dictionary);
    var e = testEngine();
    e.fromDict(d);
    QuestSystem.check(e);
    Test.assert(e.quests["di"][0] < QuestSystem.DAILY.size());
    return true;
}

(:test)
function futureClockMarkersArePulledBack(logger as Logger) as Boolean {
    var e = testEngine();
    var today = TimeUtil.today();
    e.rewardDay = today + 30;
    e.quests = {"d" => today + 30, "di" => [0, 1, 2], "dp" => [0, 0, 0], "w" => TimeUtil.weekOf(today) + 5, "wi" => [0, 1, 2], "wp" => [0, 0, 0]};
    e.sanitizeClock(TimeUtil.now());
    Test.assertEqual(e.rewardDay, today);
    Test.assert(e.quests.get("d") == null);
    // one day ahead is normal clock jitter and stays (no second gift)
    e.rewardDay = today + 1;
    e.sanitizeClock(TimeUtil.now());
    Test.assertEqual(e.rewardDay, today + 1);
    return true;
}
