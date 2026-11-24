import Toybox.Lang;
import Toybox.Test;

function near(a as Number, b as Number, tol as Number) as Boolean {
    var d = a - b;
    return d <= tol && d >= -tol;
}

(:test)
function civilDateRoundTrip(logger as Logger) as Boolean {
    Test.assertEqual(CalendarUtil.daysFromCivil(1970, 1, 1), 0);
    Test.assertEqual(CalendarUtil.daysFromCivil(2000, 3, 1), 11017);
    var days = [0, 11016, 11017, 20515, 20683, 21914, 25000];
    for (var i = 0; i < days.size(); i++) {
        var c = CalendarUtil.civilFromDays(days[i]);
        Test.assertEqual(CalendarUtil.daysFromCivil(c[0], c[1], c[2]), days[i]);
    }
    var c2 = CalendarUtil.civilFromDays(CalendarUtil.daysFromCivil(2028, 2, 29));
    Test.assertEqual(c2[1], 2);
    Test.assertEqual(c2[2], 29);
    return true;
}

(:test)
function ramadanDatesMatchReality(logger as Logger) as Boolean {
    // 1 Ramadan: 2025-03-01, 2026-02-18, 2027-02-08 (within 2 days of the official start)
    Test.assert(near(CalendarUtil.islamicDays(1446, 9, 1), CalendarUtil.daysFromCivil(2025, 3, 1), 2));
    Test.assert(near(CalendarUtil.islamicDays(1447, 9, 1), CalendarUtil.daysFromCivil(2026, 2, 18), 2));
    Test.assert(near(CalendarUtil.islamicDays(1448, 9, 1), CalendarUtil.daysFromCivil(2027, 2, 8), 2));
    // Eid al-Fitr 2025-03-30/31
    Test.assert(near(CalendarUtil.islamicDays(1446, 10, 1), CalendarUtil.daysFromCivil(2025, 3, 30), 2));
    return true;
}

(:test)
function lunarNewYearMatchesReality(logger as Logger) as Boolean {
    Test.assert(near(CalendarUtil.lunarNewYear(2024), CalendarUtil.daysFromCivil(2024, 2, 10), 1));
    Test.assert(near(CalendarUtil.lunarNewYear(2025), CalendarUtil.daysFromCivil(2025, 1, 29), 1));
    Test.assert(near(CalendarUtil.lunarNewYear(2026), CalendarUtil.daysFromCivil(2026, 2, 17), 1));
    Test.assert(near(CalendarUtil.lunarNewYear(2027), CalendarUtil.daysFromCivil(2027, 2, 6), 1));
    Test.assert(near(CalendarUtil.lunarNewYear(2030), CalendarUtil.daysFromCivil(2030, 2, 3), 1));
    return true;
}

(:test)
function globalRunningDayIsFirstWednesday(logger as Logger) as Boolean {
    Test.assertEqual(CalendarUtil.firstWeekday(2026, 6, 2), CalendarUtil.daysFromCivil(2026, 6, 3));
    Test.assertEqual(CalendarUtil.firstWeekday(2027, 6, 2), CalendarUtil.daysFromCivil(2027, 6, 2));
    return true;
}

(:test)
function eventsActiveOnTheirDates(logger as Logger) as Boolean {
    var e = testEngine();
    var ids = [];
    var act = EventSystem.activeOn(e, CalendarUtil.daysFromCivil(2027, 8, 17));
    for (var i = 0; i < act.size(); i++) { ids.add(act[i][0]); }
    Test.assert(ids.indexOf(6) >= 0);                      // Indonesia Day
    act = EventSystem.activeOn(e, CalendarUtil.daysFromCivil(2027, 1, 1));
    ids = [];
    for (var i = 0; i < act.size(); i++) { ids.add(act[i][0]); }
    Test.assert(ids.indexOf(0) >= 0);                      // New Year
    Test.assert(ids.indexOf(11) < 0);                      // Year-End Festival ended on 31 Dec
    act = EventSystem.activeOn(e, CalendarUtil.daysFromCivil(2026, 12, 31));
    ids = [];
    for (var i = 0; i < act.size(); i++) { ids.add(act[i][0]); }
    Test.assert(ids.indexOf(11) >= 0);                     // Year-End Festival 20-31 Dec
    act = EventSystem.activeOn(e, CalendarUtil.daysFromCivil(2027, 7, 10));
    Test.assertEqual(act.size(), 0);                        // a quiet day
    return true;
}

(:test)
function upcomingIsSortedAndFuture(logger as Logger) as Boolean {
    var e = testEngine();
    var today = CalendarUtil.daysFromCivil(2027, 3, 15);
    var up = EventSystem.upcoming(e, today, 6);
    Test.assertEqual(up.size(), 6);
    for (var i = 0; i < up.size(); i++) {
        Test.assert(up[i][1] > today);
        if (i > 0) { Test.assert(up[i][1] >= up[i - 1][1]); }
    }
    return true;
}

(:test)
function editionBitsRoundTrip(logger as Logger) as Boolean {
    for (var id = 0; id < EventSystem.COUNT; id++) {
        var v = EventSystem.edition(id) | 4 | 1;              // with giant and shiny bits
        var f = new FishEntity([0, 50, 50, 100, 80, 0, v, false, 0, 1]);
        Test.assertEqual(f.edition(), id + 1);
        Test.assert(f.giant());
        Test.assertEqual(f.colorVariant(), 1);
    }
    return true;
}

(:test)
function eventQuestPaysOnceWithEditionEgg(logger as Logger) as Boolean {
    var e = testEngine();
    var start = CalendarUtil.daysFromCivil(2027, 8, 14);
    e.events = [[6, start]];                               // Indonesia Day: run 17 km
    var coins = e.coins;
    EventSystem.event(e, QuestSystem.Q_RUN_KM, 10000);
    Test.assertEqual(e.coins, coins);
    EventSystem.event(e, QuestSystem.Q_RUN_KM, 7000);
    Test.assertEqual(e.coins, coins + EventSystem.QUEST_COINS);
    EventSystem.event(e, QuestSystem.Q_RUN_KM, 5000);
    Test.assertEqual(e.coins, coins + EventSystem.QUEST_COINS);
    var egg = e.eggs.size() > 0 ? e.eggs[e.eggs.size() - 1] : e.eggBag[e.eggBag.size() - 1];
    Test.assertEqual(egg[3], EventSystem.SPECIES[6]);
    Test.assertEqual((egg[4] >> 3) & 15, 7);
    return true;
}

(:test)
function weeklyRotationCoversEverySpecies(logger as Logger) as Boolean {
    var e = testEngine();
    e.stats["km"] = 500000;                                // everything unlocked
    e.stats["long"] = 42000;
    var seen = {};
    for (var w = 0; w < FishDatabase.COUNT; w++) { seen.put(WeeklySystem.featured(e, w), true); }
    Test.assert(seen.size() >= 30);
    // the current changes week to week and covers all 7 kinds within 7 weeks
    var cur = {};
    for (var w = 100; w < 107; w++) { cur.put(WeeklySystem.current(w), true); }
    Test.assertEqual(cur.size(), 7);
    return true;
}

(:test)
function featuredFishIsDiscounted(logger as Logger) as Boolean {
    var e = testEngine();
    var sp = WeeklySystem.featured(e, TimeUtil.weekOf(TimeUtil.today()));
    Test.assertEqual(e.fishPrice(sp), FishDatabase.price(sp) * 70 / 100);
    return true;
}

(:test)
function eventMultiplierRaisesRunCoins(logger as Logger) as Boolean {
    Test.assertEqual(ActivitySystem.payout(5000, 0, false, false, 0, 2.0)[0], 100);
    Test.assertEqual(ActivitySystem.payout(5000, 0, false, false, 0, 1.5)[0], 75);
    return true;
}

(:test)
function raceDayRules(logger as Logger) as Boolean {
    var e = testEngine();
    var today = TimeUtil.today();
    Test.assert(EventSystem.setRace(e, today + 3) != null);     // too soon
    Test.assert(EventSystem.setRace(e, today + 400) != null);   // too far
    Test.assert(EventSystem.setRace(e, today + 10) == null);
    Test.assertEqual(e.race, today + 10);
    var pearls = e.pearls;
    EventSystem.onRun(e, today + 10, 3000);                     // too short: no reward
    Test.assertEqual(e.pearls, pearls);
    EventSystem.onRun(e, today + 10, 10000);
    Test.assertEqual(e.pearls, pearls + 8);
    Test.assertEqual(e.stats["rday"], 1);
    EventSystem.onRun(e, today + 10, 10000);                    // paid once
    Test.assertEqual(e.pearls, pearls + 8);
    return true;
}

(:test)
function birthdayLocksAfterSet(logger as Logger) as Boolean {
    var e = testEngine();
    Test.assert(EventSystem.setBirthday(e, 8, 17) == null);
    Test.assert(EventSystem.setBirthday(e, 1, 1) != null);
    Test.assertEqual(e.bday[0], 8);
    return true;
}
