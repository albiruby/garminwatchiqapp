import Toybox.Lang;
import Toybox.Test;

// Unit tests for the RESTORA Calculation Engine.
// Run: monkeyc ... --unit-test, then `monkeydo restora.prg fr165 /t`.

(:debug) const T_DAY = 86400;
(:debug) const T_NOW = 1795000000; // 2026-11-18 11:06:40 UTC
(:debug) const T_WIB = 25200;      // UTC+7

(:debug)
function rec(id, cat, start, dur, status, done, tot, tags, hrB, hrA) as Dictionary {
    var r = {
        "id" => id, "cat" => cat, "start" => start, "dur" => dur, "st" => status,
        "done" => done, "skip" => 0, "tot" => tot, "cyc" => 0, "t" => (tags == null ? {} : tags)
    };
    if (hrB != null) { r.put("hrB", hrB); }
    if (hrA != null) { r.put("hrA", hrA); }
    return r;
}

(:debug)
function near(a, b) as Boolean {
    return a != null && (a - b).abs() < 0.001;
}

// ---- MetricValidator ------------------------------------------------------

(:test)
function testValidatorPercentAndDivide(logger as Logger) as Boolean {
    Test.assertEqual(MetricValidator.percent(1, 3), 33);
    Test.assertEqual(MetricValidator.percent(2, 3), 67);
    Test.assertEqual(MetricValidator.percent(0, 10), 0);
    Test.assert(MetricValidator.percent(0, 0) == null);
    Test.assert(MetricValidator.percent(null, 5) == null);
    Test.assert(MetricValidator.safeDivide(1, 0) == null);
    Test.assert(near(MetricValidator.safeDivide(3, 2), 1.5));
    Test.assert(MetricValidator.validHr(24) == null);
    Test.assert(MetricValidator.validHr(251) == null);
    Test.assertEqual(MetricValidator.validHr(60), 60);
    Test.assert(MetricValidator.validScale100(101) == null);
    return true;
}

// ---- Heart rate -----------------------------------------------------------

(:test)
function testHeartRateDelta(logger as Logger) as Boolean {
    Test.assertEqual(HeartRateCalculator.delta(85, 74), 11);
    Test.assertEqual(HeartRateCalculator.delta(70, 78), -8);
    Test.assert(HeartRateCalculator.delta(null, 74) == null);
    Test.assert(HeartRateCalculator.delta(85, null) == null);
    Test.assert(HeartRateCalculator.delta(300, 74) == null); // invalid, not clamped
    return true;
}

(:test)
function testHeartRateSamples(logger as Logger) as Boolean {
    Test.assertEqual(HeartRateCalculator.average([70, null, 80, 999]), 75);
    Test.assert(HeartRateCalculator.average([]) == null);
    Test.assert(HeartRateCalculator.average(null) == null);
    Test.assertEqual(HeartRateCalculator.minimum([72, 65, null, 90]), 65);
    Test.assertEqual(HeartRateCalculator.maximum([72, 65, null, 90]), 90);
    Test.assert(HeartRateCalculator.maximum([null, 0]) == null);
    return true;
}

// ---- Breathing ------------------------------------------------------------

(:test)
function testBreathingCycles(logger as Logger) as Boolean {
    var len = BreathingCalculator.cycleLength([4, 2, 6, 0]);
    Test.assertEqual(len, 12);
    Test.assertEqual(BreathingCalculator.plannedCycles(300, len), 25);
    Test.assert(BreathingCalculator.plannedCycles(300, null) == null);
    Test.assert(BreathingCalculator.cycleLength([0, 0, 0, 0]) == null);
    Test.assert(near(BreathingCalculator.exhaleInhaleRatio([4, 0, 6, 0]), 1.5));
    Test.assert(BreathingCalculator.exhaleInhaleRatio([0, 0, 6, 0]) == null);
    Test.assertEqual(BreathingCalculator.completedCycles([4, 0, 6, 0], 35000), 3);
    return true;
}

(:test)
function testBreathingPhases(logger as Logger) as Boolean {
    var box = [4, 4, 4, 4];
    Test.assertEqual(BreathingCalculator.phaseAt(box, 0), 0);
    Test.assertEqual(BreathingCalculator.phaseAt(box, 4000), 1);
    Test.assertEqual(BreathingCalculator.phaseAt(box, 15999), 3);
    Test.assertEqual(BreathingCalculator.phaseAt(box, 16000), 0);
    // Zero-length hold is skipped: inhale -> exhale.
    Test.assertEqual(BreathingCalculator.phaseAt([4, 0, 6, 0], 4000), 2);
    Test.assertEqual(BreathingCalculator.phaseRemainingMs(box, 1500), 2500);
    return true;
}

(:test)
function testBreathingConsistency(logger as Logger) as Boolean {
    Test.assertEqual(BreathingCalculator.averageCycleMs([0, 10000, 20000, 30000]), 10000);
    Test.assert(BreathingCalculator.averageCycleMs([0]) == null);
    Test.assertEqual(BreathingCalculator.cycleStdDevMs([0, 10000, 20000, 30000]), 0);
    Test.assertEqual(BreathingCalculator.cycleStdDevMs([0, 9000, 20000]), 1000);
    Test.assert(BreathingCalculator.cycleStdDevMs([0, 9000]) == null);
    return true;
}

// ---- Movement / circulation ----------------------------------------------

(:test)
function testCirculationAndMovement(logger as Logger) as Boolean {
    var r = rec("leg_relief_10", Models.CAT_CIRCULATE, T_NOW, 600, 0, 5, 5,
        {"br" => 120, "an" => 120, "el" => 300, "tr" => 60, "L" => 30, "R" => 30}, null, null);
    Test.assertEqual(CirculationCalculator.legElevationSeconds(r), 300);
    Test.assertEqual(CirculationCalculator.ankleMovementSeconds(r), 120);
    Test.assertEqual(CirculationCalculator.restorativeSeconds(r), 300);
    Test.assert(near(CirculationCalculator.movementToRestRatio(r), 0.4));
    Test.assertEqual(MovementCalculator.movementSeconds(r), 120);
    Test.assertEqual(MovementCalculator.leftRightBalance(30, 30), 50);
    Test.assert(MovementCalculator.leftRightBalance(0, 0) == null);

    var noRest = rec("x", Models.CAT_MOBILITY, T_NOW, 60, 0, 1, 1, {"st" => 60}, null, null);
    Test.assert(CirculationCalculator.movementToRestRatio(noRest) == null);
    return true;
}

// ---- Consistency ----------------------------------------------------------

(:test)
function testStreak(logger as Logger) as Boolean {
    var h = [
        rec("a", 0, T_NOW - 4 * T_DAY, 60, 0, 1, 1, null, null, null),
        rec("a", 0, T_NOW - 2 * T_DAY, 60, 0, 1, 1, null, null, null),
        rec("a", 0, T_NOW - 1 * T_DAY, 60, 1, 0, 1, null, null, null),
        rec("a", 0, T_NOW, 60, 0, 1, 1, null, null, null)
    ];
    Test.assertEqual(ConsistencyCalculator.dailyStreak(h, T_NOW, 0), 3);
    // Nothing yet today: streak still counts through yesterday.
    Test.assertEqual(ConsistencyCalculator.dailyStreak(h.slice(0, 3), T_NOW, 0), 2);
    Test.assertEqual(ConsistencyCalculator.dailyStreak([], T_NOW, 0), 0);
    return true;
}

(:test)
function testStreakTimezone(logger as Logger) as Boolean {
    // Local midnight in UTC+7 for the local day containing T_NOW.
    var localMidnight = RecordUtil.dayStart(RecordUtil.dayIndex(T_NOW, T_WIB), T_WIB);
    var h = [
        rec("a", 0, localMidnight - 1800, 60, 0, 1, 1, null, null, null), // 23:30 previous local day
        rec("a", 0, localMidnight + 1800, 60, 0, 1, 1, null, null, null)  // 00:30 today
    ];
    Test.assertEqual(ConsistencyCalculator.dailyStreak(h, localMidnight + 3600, T_WIB), 2);
    // Same instants in UTC fall on a single day.
    Test.assertEqual(RecordUtil.dayIndex(localMidnight - 1800, 0), RecordUtil.dayIndex(localMidnight + 1800, 0));
    return true;
}

(:test)
function testCompletionAndShare(logger as Logger) as Boolean {
    var h = [
        rec("box_5", Models.CAT_BREATHE, T_NOW - 3000, 300, 0, 1, 1, null, null, null),
        rec("leg_relief_10", Models.CAT_CIRCULATE, T_NOW - 2000, 600, 0, 5, 5, null, null, null),
        rec("spine_6", Models.CAT_MOBILITY, T_NOW - 1000, 300, 1, 2, 3, null, null, null),
        rec("box_5", Models.CAT_BREATHE, T_NOW - 500, 0, 0, 1, 1, null, null, null)
    ];
    var from = T_NOW - T_DAY;
    var to = T_NOW + 1;
    Test.assertEqual(ConsistencyCalculator.completionRate(h, from, to), 75);
    Test.assert(ConsistencyCalculator.completionRate([], from, to) == null);
    var share = ConsistencyCalculator.moduleShare(h, from, to);
    Test.assertEqual(share[Models.CAT_BREATHE], 25);
    Test.assertEqual(share[Models.CAT_CIRCULATE], 50);
    Test.assertEqual(share[Models.CAT_MOBILITY], 25);
    Test.assertEqual(share[Models.CAT_SLEEP], 0);
    Test.assert(ConsistencyCalculator.moduleShare([], from, to)[0] == null);
    Test.assertEqual(ConsistencyCalculator.categoriesUsed(h, from, to), 3);
    Test.assertEqual(ConsistencyCalculator.sessionCompletion(h[2]), 67);
    Test.assertEqual(ConsistencyCalculator.routineConsistency(17, 20), 85);
    return true;
}

// ---- Trends / baseline ----------------------------------------------------

(:test)
function testTrends(logger as Logger) as Boolean {
    var h = [
        rec("box_5", 0, T_NOW - 3000, 300, 0, 1, 1, null, null, null),
        rec("leg_relief_10", 2, T_NOW - 2000, 600, 0, 5, 5, null, null, null),
        rec("leg_relief_10", 2, T_NOW - 1000, 590, 0, 5, 5, null, null, null)
    ];
    var from = T_NOW - T_DAY;
    var to = T_NOW + 1;
    Test.assertEqual(TrendCalculator.sessionCount(h, from, to), 3);
    Test.assertEqual(TrendCalculator.totalMinutes(h, from, to), 25); // 1490 s
    Test.assertEqual(TrendCalculator.averageSessionSeconds(h, from, to), 497);
    Test.assert(TrendCalculator.averageSessionSeconds([], from, to) == null);
    Test.assertEqual(TrendCalculator.mostUsedSession(h, from, to), "leg_relief_10");
    Test.assert(near(TrendCalculator.sessionsPerWeek(3, 14), 1.5));
    Test.assert(TrendCalculator.baseline([60, 62, null, 64], 5) == null);
    Test.assertEqual(TrendCalculator.baseline([60, 62, 64, 66, 68], 5), 64);
    Test.assertEqual(TrendCalculator.vsBaseline(70, 64), 6);
    Test.assert(TrendCalculator.vsBaseline(null, 64) == null);
    return true;
}

(:test)
function testHrBaselineWindow(logger as Logger) as Boolean {
    var h = [];
    for (var i = 0; i < 5; i++) {
        h.add(rec("a", 0, T_NOW - i * T_DAY, 60, 0, 1, 1, null, 60 + i * 2, null)); // 60..68
    }
    h.add(rec("a", 0, T_NOW - 20 * T_DAY, 60, 0, 1, 1, null, 100, null));      // outside 14 d
    h.add(rec("a", 0, T_NOW - T_DAY / 2, 60, 0, 1, 1, null, null, null));     // no reading
    Test.assertEqual(TrendCalculator.hrBeforeBaseline(h, T_NOW), 64);
    Test.assert(TrendCalculator.hrBeforeBaseline(h.slice(0, 4), T_NOW) == null);
    return true;
}

// ---- Sleep ----------------------------------------------------------------

(:test)
function testSleepEvening(logger as Logger) as Boolean {
    var today = RecordUtil.dayIndex(T_NOW, T_WIB);
    var d0 = RecordUtil.dayStart(today, T_WIB);
    var h = [
        rec("wind_down_5", Models.CAT_SLEEP, d0 + 21 * 3600, 300, 0, 2, 2, null, null, null),           // today 21:00
        rec("wind_down_5", Models.CAT_SLEEP, d0 - T_DAY + 22 * 3600, 290, 0, 2, 2, null, null, null),  // yesterday 22:00
        rec("box_5", Models.CAT_BREATHE, d0 - 2 * T_DAY + 8 * 3600, 300, 0, 1, 1, null, null, null)    // morning
    ];
    Test.assert(SleepCalculator.isEvening(h[0], T_WIB));
    Test.assert(!SleepCalculator.isEvening(h[2], T_WIB));
    Test.assertEqual(SleepCalculator.windDownSeconds(h, d0 - 7 * T_DAY, d0 + T_DAY), 590);
    Test.assertEqual(SleepCalculator.eveningSessionCount(h, d0 - 7 * T_DAY, d0 + T_DAY, T_WIB), 2);
    Test.assertEqual(SleepCalculator.eveningConsistency(h, d0 + 23 * 3600, T_WIB, 7), 29); // 2 of 7
    Test.assert(SleepCalculator.eveningConsistency(h, d0, T_WIB, 0) == null);
    return true;
}

// ---- Engine facade --------------------------------------------------------

(:test)
function testSummarizeSession(logger as Logger) as Boolean {
    var r = rec("leg_relief_10", Models.CAT_CIRCULATE, T_NOW, 590, 0, 5, 5,
        {"br" => 120, "an" => 120, "el" => 300}, 85, 74);
    var m = CalculationEngine.summarizeSession(r);
    Test.assertEqual(m.get("hrChange").value, 11);
    Test.assertEqual(m.get("hrChange").source, MetricSource.CALCULATED);
    Test.assertEqual(m.get("hrBefore").source, MetricSource.MEASURED);
    Test.assertEqual(m.get("completion").value, 100);
    Test.assertEqual(m.get("elevation").value, 300);

    var noHr = rec("box_5", Models.CAT_BREATHE, T_NOW, 300, 0, 1, 1, {"br" => 300}, null, null);
    var m2 = CalculationEngine.summarizeSession(noHr);
    Test.assert(m2.get("hrChange").value == null);
    Test.assertEqual(m2.get("hrChange").display(), "--");
    Test.assert(m2.get("moveRest").value == null);
    return true;
}

(:test)
function testSummarizeWeek(logger as Logger) as Boolean {
    var h = [
        rec("box_5", 0, T_NOW - 8 * T_DAY, 300, 0, 1, 1, null, null, null), // outside window
        rec("box_5", 0, T_NOW - 6 * T_DAY, 300, 0, 1, 1, null, null, null),
        rec("leg_relief_10", 2, T_NOW - T_DAY, 600, 0, 5, 5, {"el" => 300}, null, null),
        rec("leg_relief_10", 2, T_NOW, 600, 1, 3, 5, {"el" => 120}, null, null)
    ];
    var m = CalculationEngine.summarizeWeek(h, T_NOW, 0);
    Test.assertEqual(m.get("sessions").value, 3);
    Test.assertEqual(m.get("minutes").value, 25);
    Test.assertEqual(m.get("categories").value, 2);
    Test.assertEqual(m.get("streak").value, 2);
    Test.assertEqual(m.get("completionRate").value, 67);
    Test.assertEqual(m.get("elevation").value, 7);    // 420 s
    Test.assertEqual(m.get("circulation").value, 20);
    Test.assert(m.get("hrBaseline").value == null); // no readings: never estimated

    var empty = CalculationEngine.summarizeWeek([], T_NOW, 0);
    Test.assertEqual(empty.get("sessions").value, 0);
    Test.assert(empty.get("completionRate").value == null);
    Test.assert(empty.get("avgSession").value == null);
    return true;
}

(:test)
function testHrvRmssd(logger as Logger) as Boolean {
    // alternating 800 / 820 ms: every successive difference is 20 ms -> RMSSD 20
    var rr = [];
    for (var i = 0; i < 60; i++) {
        rr.add((i % 2 == 0) ? 800 : 820);
    }
    Test.assertEqual(HrvCalculator.rmssd(rr), 20);
    // too few beats -> no value, never an estimate
    Test.assert(HrvCalculator.rmssd(rr.slice(0, 20)) == null);
    Test.assert(HrvCalculator.rmssd(null) == null);
    // artefacts (out of range, > 20 % jumps) are removed before the calculation
    var noisy = rr.slice(0, rr.size());
    noisy.add(250);
    noisy.add(2500);
    noisy.add(1400);
    Test.assertEqual(HrvCalculator.clean(noisy).size(), 60);
    // head / tail windows by summed time
    Test.assertEqual(HrvCalculator.head(rr, 1620).size(), 2);
    Test.assertEqual(HrvCalculator.tail(rr, 1620).size(), 2);
    return true;
}
