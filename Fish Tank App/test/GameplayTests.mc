import Toybox.Lang;
import Toybox.Test;

function testEngine() as AquariumEngine {
    var e = new AquariumEngine();
    e.fromDict(SaveManager.defaults());
    e.onboarded = true;
    return e;
}

(:test)
function decayNeverKillsFish(logger as Logger) as Boolean {
    var f = new FishEntity([0, 80, 80, 100, 10]);
    var c = HealthSystem.advance([f], 100.0, 0, 24.0 * 30);
    Test.assert(f.hp >= HealthSystem.HP_FLOOR);
    Test.assert(f.sat >= 0);
    Test.assert(c >= 0);
    return true;
}

(:test)
function wellFedFishStayHealthy(logger as Logger) as Boolean {
    var f = new FishEntity([0, 100, 50, 80, 10]);
    HealthSystem.advance([f], 100.0, 8, 1.0);
    Test.assert(f.hp > 80);
    Test.assert(f.gr > 10);
    return true;
}

(:test)
function synergyRaisesHappiness(logger as Logger) as Boolean {
    var a = HealthSystem.targetHappy(60.0, 80.0, 0, false);
    var b = HealthSystem.targetHappy(60.0, 80.0, 0, true);
    Test.assert(b > a);
    return true;
}

(:test)
function levelUpCarriesXp(logger as Logger) as Boolean {
    var r = ProgressionSystem.apply(1, 50, 20);
    Test.assertEqual(r[0], 2);
    Test.assertEqual(r[1], 10);
    Test.assertEqual(r[2], 1);
    var top = ProgressionSystem.apply(10, 0, 5000);
    Test.assertEqual(top[0], 10);
    return true;
}

(:test)
function migrateV1ToV2(logger as Logger) as Boolean {
    var v1 = {"v" => 1, "c" => 99, "dx" => 5, "lv" => 5, "dc" => [1, 3],
              "f" => [[0, 50.0, 60.0, 90.0, 40.0], [4, 70.0, 70.0, 100.0, 80.0]]};
    var d = SaveManager.migrate(v1);
    Test.assertEqual(d["c"], 99);
    Test.assertEqual(d["v"], SaveManager.VERSION);
    Test.assertEqual(d["dx"].size(), FishDatabase.COUNT);
    Test.assertEqual(d["dx"][0], 1);
    Test.assertEqual(d["dx"][1], 0);
    Test.assertEqual(d["dx"][2], 1);
    Test.assertEqual(d["f"][0].size(), 10);
    Test.assert(d["f"][0][9] != d["f"][1][9]);
    Test.assertEqual(d["dp"][0], 1);
    Test.assertEqual(d["alv"], 3);
    Test.assertEqual(d["ach"].size(), AchievementSystem.COUNT);
    return true;
}

(:test)
function incomeIsCapped(logger as Logger) as Boolean {
    var f = new FishEntity([0, 80, 100, 100, 80]);
    var a = EconomySystem.income([f], 12.0);
    var b = EconomySystem.income([f], 48.0);
    Test.assertEqual(a, b);
    Test.assert(a > 0);
    return true;
}

(:test)
function runPayoutRates(logger as Logger) as Boolean {
    // 5 km, no bonuses: 50 coins
    Test.assertEqual(ActivitySystem.payout(5000, 0, false, false, 0, 1.0)[0], 50);
    // first run of the week +20, pace PR +10
    Test.assertEqual(ActivitySystem.payout(5000, 0, true, true, 0, 1.0)[0], 80);
    // 10 km gets x1.5
    Test.assertEqual(ActivitySystem.payout(10000, 0, false, false, 0, 1.0)[0], 150);
    // consistency streak 2 weeks x1.2
    Test.assertEqual(ActivitySystem.payout(5000, 2, false, false, 0, 1.0)[0], 60);
    // daily cap
    Test.assertEqual(ActivitySystem.payout(30000, 5, true, true, 0, 1.0)[0], ActivitySystem.RUN_CAP);
    Test.assertEqual(ActivitySystem.payout(5000, 0, false, false, ActivitySystem.RUN_CAP - 10, 1.0)[0], 10);
    return true;
}

(:test)
function sameRunNeverPaidTwice(logger as Logger) as Boolean {
    var e = testEngine();
    var start = 1800000000;
    var before = e.coins;
    ActivitySystem.payRun(e, start, 5000, 1650);
    var after = e.coins;
    Test.assert(after > before);
    ActivitySystem.payRun(e, start, 5000, 1650);
    Test.assertEqual(e.coins, after);
    Test.assertEqual(e.stats["runs"], 1);
    Test.assertEqual(e.stats["km"], 5000);
    return true;
}

(:test)
function grantLedgerDedups(logger as Logger) as Boolean {
    var e = testEngine();
    Test.assert(RewardSystem.grant(e, "x1", 10, 1, 1, 0));
    Test.assert(!RewardSystem.grant(e, "x1", 10, 1, 1, 0));
    Test.assertEqual(e.pearls, 1);
    Test.assertEqual(e.keys, 1);
    return true;
}

(:test)
function questsAreDeterministic(logger as Logger) as Boolean {
    var a = QuestSystem.pick(20000 * 31 + 7, QuestSystem.DAILY.size());
    var b = QuestSystem.pick(20000 * 31 + 7, QuestSystem.DAILY.size());
    Test.assertEqual(a.size(), 3);
    for (var i = 0; i < 3; i++) { Test.assertEqual(a[i], b[i]); }
    Test.assert(a[0] != a[1] && a[1] != a[2] && a[0] != a[2]);
    return true;
}

(:test)
function eggsHatchFromRunning(logger as Logger) as Boolean {
    var e = testEngine();
    e.fish = [];
    CollectionSystem.addEgg(e, 0, -1, 0);
    Test.assert(!CollectionSystem.eggReady(e.eggs[0]));
    CollectionSystem.eggKm(e, 3.0);
    Test.assert(CollectionSystem.eggReady(e.eggs[0]));
    Test.assert(CollectionSystem.hatch(e, 0) == null);
    Test.assertEqual(e.fish.size(), 1);
    Test.assertEqual(e.eggs.size(), 0);
    Test.assertEqual(e.dex[e.fish[0].sp], 1);
    return true;
}

(:test)
function hatchRespectsRegions(logger as Logger) as Boolean {
    var e = testEngine();
    for (var i = 0; i < 40; i++) {
        var sp = CollectionSystem.rollSpecies(e, 4);   // legendary egg
        Test.assert(FishDatabase.REGION[sp] == 0);
    }
    return true;
}

(:test)
function breedingNeedsCompatibleAdults(logger as Logger) as Boolean {
    var a = new FishEntity([0, 80, 80, 100, 90, 0, 0, false, 0, 1]);
    var b = new FishEntity([1, 80, 80, 100, 90, 0, 0, false, 0, 2]);
    var c = new FishEntity([4, 80, 80, 100, 90, 0, 0, false, 0, 3]);
    var baby = new FishEntity([2, 80, 80, 100, 10, 0, 0, false, 0, 4]);
    Test.assert(CollectionSystem.canPair(a, b));
    Test.assert(!CollectionSystem.canPair(a, c));     // different habitat
    Test.assert(!CollectionSystem.canPair(a, baby));  // not adult
    Test.assert(!CollectionSystem.canPair(a, a));
    return true;
}

(:test)
function evolutionGates(logger as Logger) as Boolean {
    var e = testEngine();
    var f = new FishEntity([0, 80, 90, 100, 90, 200, 0, false, 0, 1]);
    e.fish = [f];
    Test.assert(CollectionSystem.evolveReason(e, f) != null);   // no km, no pearls
    e.stats["km"] = 25000;
    e.pearls = 5;
    Test.assert(CollectionSystem.evolveReason(e, f) == null);
    Test.assert(CollectionSystem.evolve(e, f) == null);
    Test.assert(f.evo);
    Test.assertEqual(e.pearls, 3);
    return true;
}

(:test)
function ratingStaysInRange(logger as Logger) as Boolean {
    var e = testEngine();
    Test.assertEqual(HabitatSystem.rating(e), 0.0);
    e.fish = [new FishEntity([0, 100, 100, 100, 90]), new FishEntity([1, 100, 100, 100, 90]), new FishEntity([2, 100, 100, 100, 90])];
    e.placed = [4, 9, -1, -1, -1, -1];
    e.theme = 0;
    HabitatSystem.refresh(e);
    var r = HabitatSystem.rating(e);
    Test.assert(r > 3.5 && r <= 5.0);
    Test.assert(e.fish[0].syn);                // clownfish + anemone
    return true;
}

(:test)
function leagueTargetHasFloor(logger as Logger) as Boolean {
    var e = testEngine();
    LeagueSystem.ensure(e);
    Test.assertEqual(LeagueSystem.target(e), LeagueSystem.FLOOR[0]);
    e.league["h"] = [1000, 1000];
    Test.assertEqual(LeagueSystem.target(e), 800);
    return true;
}

(:test)
function everySpriteBuilds(logger as Logger) as Boolean {
    for (var i = 0; i < FishDatabase.COUNT; i++) {
        var s = SpriteData.get(i, false);
        Test.assert(s[:runs].size() > 40);
        Test.assert(s[:runs].size() % 4 == 0);
    }
    Test.assert(SpriteData.get(0, true)[:runs].size() > 40);
    return true;
}

(:test)
function speciesTablesAligned(logger as Logger) as Boolean {
    var n = FishDatabase.COUNT;
    var arrs = [FishDatabase.NAME, FishDatabase.HAB, FishDatabase.RARITY, FishDatabase.SHAPE, FishDatabase.TAIL,
                FishDatabase.SPEED, FishDatabase.COLORS, FishDatabase.MARKS, FishDatabase.ACCENT, FishDatabase.PERS,
                FishDatabase.FAV, FishDatabase.SYN, FishDatabase.REGION, FishDatabase.KM_GATE];
    for (var i = 0; i < arrs.size(); i++) { Test.assertEqual(arrs[i].size(), n); }
    Test.assertEqual(FishDatabase.pool(3).size(), n);
    return true;
}
