import Toybox.Lang;
import Toybox.Test;

// Runs that happened before the app was installed, or that are read on a later day.

// Daily quests 0-2 are "Run 2 km", "Run 3 km" and "Go for 1 run"; weekly 0 is "Run 10 km".
function runQuestEngine(installTime) as AquariumEngine {
    var e = testEngine();
    e.installTime = installTime;
    var day = TimeUtil.today();
    e.quests = {"d" => day, "di" => [0, 1, 2], "dp" => [0, 0, 0],
                "w" => TimeUtil.weekOf(day), "wi" => [0, 2, 3], "wp" => [0, 0, 0]};
    e.scanFrom = ActivitySystem.firstCountedDay(e);
    e.scanLog = {};
    e.pendingRuns = [];
    return e;
}

(:test)
function runBeforeInstallFinishesTodaysQuests(logger as Logger) as Boolean {
    var now = TimeUtil.now();
    var e = runQuestEngine(now);                       // installed "tonight"
    ActivitySystem.consider(e, new MockRun(now - 120, 5000, 1500));   // ran 5 km earlier
    Test.assertEqual(e.pendingRuns.size(), 1);
    var coins = e.coins;
    ActivitySystem.finishScan(e);
    Test.assert(e.coins > coins);                       // paid once
    Test.assert(QuestSystem.isDone(e, true, 0));        // run 2 km
    Test.assert(QuestSystem.isDone(e, true, 1));        // run 3 km
    Test.assert(QuestSystem.isDone(e, true, 2));        // 1 run
    Test.assertEqual(e.quests["wp"][0], 5000);          // weekly run 10 km: 5 of 10
    Test.assert(!QuestSystem.isDone(e, false, 0));
    Test.assertEqual(ActivitySystem.logDay(e, TimeUtil.today())[0], 5000);
    return true;
}

(:test)
function runBeforeInstallWeekIsIgnored(logger as Logger) as Boolean {
    var now = TimeUtil.now();
    var e = runQuestEngine(now);
    ActivitySystem.consider(e, new MockRun(now - 8 * 86400, 5000, 1500));   // last week
    Test.assertEqual(e.pendingRuns.size(), 0);
    return true;
}

(:test)
function runReadLaterCountsForItsOwnDay(logger as Logger) as Boolean {
    var now = TimeUtil.now();
    var e = runQuestEngine(now - 10 * 86400);
    ActivitySystem.payRun(e, now - 86400, 5000, 1500);  // yesterday's run, read today
    Test.assertEqual(e.quests["dp"][0], 0);             // today's "run 2 km" still open
    Test.assert(!QuestSystem.isDone(e, true, 2));
    Test.assertEqual(ActivitySystem.logDay(e, TimeUtil.today() - 1)[1], 1);
    return true;
}

(:test)
function paidRunsRebuildTheLog(logger as Logger) as Boolean {
    var now = TimeUtil.now();
    var e = runQuestEngine(now - 10 * 86400);
    var start = now - 60;
    e.tx.put("r" + start.toString(), TimeUtil.today());   // paid by an older version, no log
    ActivitySystem.consider(e, new MockRun(start, 3200, 1100));
    Test.assertEqual(e.pendingRuns.size(), 0);
    ActivitySystem.finishScan(e);
    Test.assertEqual(e.stats["runs"], 0);               // the run is not paid again
    Test.assertEqual(ActivitySystem.logDay(e, TimeUtil.today())[0], 3200);
    Test.assert(QuestSystem.isDone(e, true, 1));        // run 3 km now shows as done
    return true;
}

(:test)
function manyRunsShareOneCard(logger as Logger) as Boolean {
    var now = TimeUtil.now();
    var e = runQuestEngine(now - 10 * 86400);
    for (var i = 0; i < 4; i++) {
        ActivitySystem.consider(e, new MockRun(now - 600 - i * 3600, 2000, 700));
    }
    e.cards = [];
    ActivitySystem.finishScan(e);
    var runCards = 0;
    for (var i = 0; i < e.cards.size(); i++) {
        var t = e.cards[i][:t];
        if (t.equals("RUN REWARD") || t.equals("RUN FOUND") || t.equals("RUNS FOUND")) { runCards++; }
    }
    Test.assertEqual(runCards, 1);
    Test.assertEqual(e.stats["runs"], 4);
    return true;
}
