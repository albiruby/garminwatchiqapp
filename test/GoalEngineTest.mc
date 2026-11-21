import Toybox.Lang;
import Toybox.Test;

// Required progress points from the brief: 0, 1, 25, 50, 75, 99, 100, 150 %.
(:test)
function goalPercentagesAndStates(logger as Logger) as Boolean {
    var goal = 10000;
    // steps, percent, state, remaining, track, lap, segments(10)
    var cases = [
        [0,     0,   ActivityGoalEngine.STATE_START,     10000, 0.0,  0.0, 0],
        [100,   1,   ActivityGoalEngine.STATE_START,     9900,  0.01, 0.0, 0],
        [2500,  25,  ActivityGoalEngine.STATE_BUILDING,  7500,  0.25, 0.0, 2],
        [5000,  50,  ActivityGoalEngine.STATE_BUILDING,  5000,  0.5,  0.0, 5],
        [7500,  75,  ActivityGoalEngine.STATE_NEAR,      2500,  0.75, 0.0, 7],
        [9990,  99,  ActivityGoalEngine.STATE_NEAR,      10,    0.999, 0.0, 9],
        [10000, 100, ActivityGoalEngine.STATE_COMPLETED, 0,     1.0,  0.0, 10],
        [15000, 150, ActivityGoalEngine.STATE_OVER,      0,     1.0,  0.5, 10]
    ];
    for (var i = 0; i < cases.size(); i++) {
        var c = cases[i] as Array;
        var g = ActivityGoalEngine.evaluate(c[0] as Number, goal);
        logger.debug("steps=" + c[0] + " pct=" + g.percent + " state=" + g.state + " rem=" + g.remaining
            + " track=" + ActivityGoalEngine.trackFraction(g) + " lap=" + ActivityGoalEngine.lapFraction(g)
            + " seg=" + ActivityGoalEngine.filledSegments(g, 10));
        Test.assertEqual(g.percent, c[1]);
        Test.assertEqual(g.state, c[2]);
        Test.assertEqual(g.remaining, c[3]);
        Test.assert(near(ActivityGoalEngine.trackFraction(g), c[4] as Float));
        Test.assert(near(ActivityGoalEngine.lapFraction(g), c[5] as Float));
        Test.assertEqual(ActivityGoalEngine.filledSegments(g, 10), c[6]);
    }
    return true;
}

function near(a as Float, b as Float) as Boolean {
    var d = a - b;
    return d < 0.0005 && d > -0.0005;
}

// The percentage text is never clamped; the track stops at one lap of overshoot.
(:test)
function overachievementIsNotClamped(logger as Logger) as Boolean {
    var g = ActivityGoalEngine.evaluate(32500, 10000);
    Test.assertEqual(g.percent, 325);
    Test.assertEqual(g.state, ActivityGoalEngine.STATE_OVER);
    Test.assert(near(ActivityGoalEngine.trackFraction(g), 1.0));
    Test.assert(near(ActivityGoalEngine.lapFraction(g), 1.0));
    // just over: 10050 / 10000 floors to 100 % -> completed, not over
    Test.assertEqual(ActivityGoalEngine.evaluate(10050, 10000).state, ActivityGoalEngine.STATE_COMPLETED);
    Test.assertEqual(ActivityGoalEngine.evaluate(10100, 10000).state, ActivityGoalEngine.STATE_OVER);
    return true;
}

// The last segment / 100 % only shows once the goal is really reached.
(:test)
function noEarlyCompletion(logger as Logger) as Boolean {
    var g = ActivityGoalEngine.evaluate(9999, 10000);
    Test.assertEqual(g.percent, 99);
    Test.assertEqual(ActivityGoalEngine.filledSegments(g, 10), 9);
    Test.assertEqual(ActivityGoalEngine.filledSegments(g, 5), 4);
    Test.assert(ActivityGoalEngine.trackFraction(g) < 1.0);
    Test.assertEqual(g.remaining, 1);
    return true;
}

(:test)
function missingAndInvalidInputs(logger as Logger) as Boolean {
    var g = ActivityGoalEngine.evaluate(null, 10000);
    Test.assert(!g.valid);
    Test.assertEqual(g.state, ActivityGoalEngine.STATE_NONE);
    Test.assertEqual(ActivityGoalEngine.trackFraction(g), 0.0);

    // missing / zero / negative goal: value shown, no progress, no division by zero
    var targets = [null, 0, -500];
    for (var i = 0; i < targets.size(); i++) {
        g = ActivityGoalEngine.evaluate(4321, targets[i]);
        Test.assert(g.valid);
        Test.assert(!g.hasTarget);
        Test.assertEqual(g.state, ActivityGoalEngine.STATE_NONE);
        Test.assertEqual(ActivityGoalEngine.filledSegments(g, 10), 0);
        Test.assertEqual(ActivityGoalEngine.lapFraction(g), 0.0);
    }
    // negative value is treated as unavailable
    Test.assert(!ActivityGoalEngine.evaluate(-1, 10000).valid);
    return true;
}

// 100 x value would overflow a 32-bit Number above ~21.4 million.
(:test)
function largeValuesDoNotOverflow(logger as Logger) as Boolean {
    var g = ActivityGoalEngine.evaluate(2000000000, 1000000000);
    Test.assertEqual(g.percent, 200);
    Test.assertEqual(ActivityGoalEngine.filledSegments(g, 10), 10);
    g = ActivityGoalEngine.evaluate(99999, 100000);
    Test.assertEqual(g.percent, 99);
    return true;
}

(:test)
function distanceTargets(logger as Logger) as Boolean {
    Test.assert(ActivityGoalEngine.distanceTargetCm(0.0, true) == null);
    Test.assertEqual(ActivityGoalEngine.distanceTargetCm(8.0, true), 800000);
    Test.assertEqual(ActivityGoalEngine.distanceTargetCm(5.0, false), 804672);
    var g = ActivityGoalEngine.evaluate(400000, ActivityGoalEngine.distanceTargetCm(8.0, true));
    Test.assertEqual(g.percent, 50);
    return true;
}

// Track arc angles: 0 % at 240 deg, 100 % at -60 deg (300 deg sweep, clockwise).
(:test)
function trackAngles(logger as Logger) as Boolean {
    Test.assert(near(ProgressRenderer.angleAt(0.0), 240.0));
    Test.assert(near(ProgressRenderer.angleAt(0.5), 90.0));
    Test.assert(near(ProgressRenderer.angleAt(1.0), -60.0));
    Test.assertEqual(ProgressRenderer.norm(-60), 300);
    Test.assertEqual(ProgressRenderer.norm(720), 0);
    return true;
}
