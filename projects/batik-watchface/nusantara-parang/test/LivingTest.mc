import Toybox.Lang;
import Toybox.Test;

(:test)
function litCountBounds(logger as Logger) as Boolean {
    Test.assertEqual(Living.litCount(0, 8000, 100), 0);
    Test.assertEqual(Living.litCount(-5, 8000, 100), 0);
    Test.assertEqual(Living.litCount(500, 0, 100), 0);
    Test.assertEqual(Living.litCount(8000, 8000, 100), 100);
    Test.assertEqual(Living.litCount(20000, 8000, 100), 100);
    return true;
}

(:test)
function litCountHalfway(logger as Logger) as Boolean {
    Test.assertEqual(Living.litCount(4000, 8000, 100), 50);
    Test.assertEqual(Living.litCount(7999, 8000, 100), 99);
    // large step counts must not overflow
    Test.assertEqual(Living.litCount(1500000, 2000000, 300), 225);
    return true;
}

(:test)
function packRoundTrip(logger as Logger) as Boolean {
    var xs = [0, 1, 227, 466, -40, -1];
    for (var i = 0; i < xs.size(); i++) {
        for (var j = 0; j < xs.size(); j++) {
            var p = Living.pack(xs[i], xs[j]);
            Test.assertEqual(Living.unpackX(p), xs[i]);
            Test.assertEqual(Living.unpackY(p), xs[j]);
        }
    }
    return true;
}

// Living Pattern stages across a day, 120 units, goal 10,000 steps.
(:test)
function stagesAcrossDay(logger as Logger) as Boolean {
    var n = 120;
    var g = 10000;
    var expect = [
        // steps, bloom, awake
        [0,     0,   0],    // Dormant: nothing lit
        [2500,  30,  60],   // 25%: a quarter blooms, half is gilded
        [5000,  60,  120],  // 50%: half blooms, whole motif gilded
        [7500,  90,  120],
        [10000, 120, 120],  // Complete
        [14000, 120, 120]   // beyond goal stays complete
    ];
    for (var i = 0; i < expect.size(); i++) {
        var e = expect[i] as Array<Number>;
        var st = Living.stages(e[0], g, n);
        logger.debug("steps=" + e[0] + " bloom=" + st[0] + " awake=" + st[1]);
        Test.assertEqual(st[0], e[1]);
        Test.assertEqual(st[1], e[2]);
    }
    return true;
}

(:test)
function stagesMonotonic(logger as Logger) as Boolean {
    // More steps never un-light a unit, and awake is always >= bloom.
    var prev = [0, 0];
    for (var s = 0; s <= 12000; s += 37) {
        var st = Living.stages(s, 10000, 97);
        Test.assert(st[0] >= prev[0] && st[1] >= prev[1]);
        Test.assert(st[1] >= st[0]);
        prev = st;
    }
    return true;
}

(:test)
function stagesNoGoal(logger as Logger) as Boolean {
    // Goal not set yet (0): stays Dormant instead of dividing by zero.
    var st = Living.stages(5000, 0, 120);
    Test.assertEqual(st[0], 0);
    Test.assertEqual(st[1], 0);
    return true;
}

// Every slot choice maps to a native complication (press-and-hold target).
(:test)
function longPressTargets(logger as Logger) as Boolean {
    var counts = [11, 7, 7, 9];
    for (var s = 0; s < 4; s++) {
        for (var c = 0; c < counts[s]; c++) {
            var t = s == 0 ? Slots.leftTarget(c) : (s == 1 ? Slots.rightTarget(c) : (s == 2 ? Slots.topTarget(c) : Slots.bottomTarget(c)));
            Test.assert(t != null);
        }
    }
    return true;
}
