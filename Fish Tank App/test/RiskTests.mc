import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;

// Stand-in for UserProfile.UserActivity (same fields the scan reads).
class MockRun {
    var type;
    var startTime;
    var distance;
    var duration;

    function initialize(start, meters, secs) {
        type = 1;   // Activity.SPORT_RUNNING
        startTime = new Time.Moment(start);
        distance = meters;
        duration = new Time.Duration(secs);
    }
}

(:test)
function milestonesSurviveLedgerPruning(logger as Logger) as Boolean {
    var e = testEngine();
    e.stats["km"] = 30000;
    ActivitySystem.checkKm(e);
    var pearls = e.pearls;
    Test.assert(pearls > 0);
    // pretend the milestone was paid 400 days ago, then prune
    e.tx.put("km25", e.dayKey() - 400);
    e.tx.put("r1700000000", e.dayKey() - 400);
    RewardSystem.prune(e);
    Test.assert(e.tx.hasKey("km25"));          // permanent
    Test.assert(!e.tx.hasKey("r1700000000"));  // dated, pruned
    ActivitySystem.checkKm(e);
    Test.assertEqual(e.pearls, pearls);        // not paid again
    return true;
}

(:test)
function oldRunsAreIgnored(logger as Logger) as Boolean {
    var e = testEngine();
    e.installTime = 0;
    e.pendingRuns = [];
    var now = TimeUtil.now();
    ActivitySystem.consider(e, new MockRun(now - 100 * 86400, 5000, 1500));   // too old
    ActivitySystem.consider(e, new MockRun(now - 2 * 86400, 5000, 1500));     // fine
    ActivitySystem.consider(e, new MockRun(now - 86400, 500, 1500));          // too short
    Test.assertEqual(e.pendingRuns.size(), 1);
    return true;
}

(:test)
function fallbackDistanceDrivesProgress(logger as Logger) as Boolean {
    var e = testEngine();
    var day = TimeUtil.today();
    var coins = e.coins;
    ActivitySystem.creditDaily(e, day, 4000);          // 4 km today
    Test.assertEqual(e.coins, coins + 20);              // 200 m per coin
    Test.assertEqual(e.stats["km"], 2000);              // half counts as progress
    Test.assertEqual(e.stats["fkm"], 2000);
    Test.assertEqual(e.tp, 2);
    ActivitySystem.creditDaily(e, day, 4000);          // same reading: nothing new
    Test.assertEqual(e.coins, coins + 20);
    ActivitySystem.creditDaily(e, day, 100000);        // coins capped, progress continues
    // (total coins also rise from the expedition regions 50 km unlocks, so check the
    // activity-coin counter for the cap)
    Test.assertEqual(e.stats["ac"], ActivitySystem.FALLBACK_CAP);
    Test.assertEqual(e.stats["km"], 50000);
    Test.assert(ExpeditionSystem.unlocked(e) >= 2);    // progress reaches the expedition
    return true;
}

(:test)
function fallbackOffOnceRunsArrive(logger as Logger) as Boolean {
    var e = testEngine();
    e.installTime = TimeUtil.now() - 10 * 86400;
    if (ActivitySystem.historySupported()) {
        Test.assert(ActivitySystem.fallbackMode(e));     // 10 days, no runs
        e.stats["runs"] = 1;
        Test.assert(!ActivitySystem.fallbackMode(e));
        e.stats["runs"] = 0;
        e.installTime = TimeUtil.now() - 86400;          // only 1 day in
        Test.assert(!ActivitySystem.fallbackMode(e));
    }
    return true;
}

(:test)
function clockSetBackGivesNothing(logger as Logger) as Boolean {
    var e = testEngine();
    var today = TimeUtil.today();
    e.rewardDay = today + 3;                             // gift claimed "in the future"
    Test.assert(!e.rewardAvailable());
    e.league = {"w" => TimeUtil.weekOf(today) + 2, "s" => 123, "t" => 1, "h" => []};
    LeagueSystem.check(e);
    Test.assertEqual(e.league["s"], 123);                // no rollover backwards
    e.quests = {"d" => today + 5, "di" => [0, 1, 2], "dp" => [7, 7, 7], "w" => TimeUtil.weekOf(today) + 1, "wi" => [0, 1, 2], "wp" => [9, 9, 9]};
    QuestSystem.check(e);
    Test.assertEqual(e.quests["dp"][0], 7);              // progress kept
    return true;
}

(:test)
function splitSaveRoundTrip(logger as Logger) as Boolean {
    var e = testEngine();
    e.coins = 4321;
    e.tx.put("km50", 20000);
    e.stats["km"] = 55555;
    Test.assert(SaveManager.save(e.toDict()));
    var d = SaveManager.load();
    Test.assertEqual(d["c"], 4321);
    Test.assert(d["tx"].hasKey("km50"));
    Test.assertEqual(d["stt"]["km"], 55555);
    SaveManager.clear();
    Test.assert(SaveManager.load() == null);
    return true;
}

(:test)
function eggBagIsCapped(logger as Logger) as Boolean {
    var e = testEngine();
    for (var i = 0; i < 30; i++) { CollectionSystem.addEgg(e, 0, -1, 0); }
    Test.assertEqual(e.eggs.size(), CollectionSystem.incubatorSlots(e));
    Test.assertEqual(e.eggBag.size(), CollectionSystem.BAG_MAX);
    Test.assert(e.pearls > 0);
    return true;
}
