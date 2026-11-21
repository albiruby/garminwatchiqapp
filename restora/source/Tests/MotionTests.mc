import Toybox.Lang;
import Toybox.Test;

// Unit tests for the Motion & Animation Engine. Expected values come from
// tools/motion/motion_model.py (MotionGolden.mc), so the Monkey C engine is
// checked against the same model that produced the poses and previews.

(:debug)
function nearF(a, b, tol) as Boolean {
    return a != null && b != null && (a - b).abs() <= tol;
}

(:debug)
function sampleAt(id as String, tMs as Number, reduced as Boolean) as PoseSampler {
    var s = new PoseSampler(ExercisePoseData.forExercise(id));
    s.sample(tMs, reduced);
    return s;
}

// ---- Easing ---------------------------------------------------------------

(:test)
function testEasingEndpointsAndMonotonic(logger as Logger) as Boolean {
    var kinds = [Easing.LINEAR, Easing.IN_OUT_SINE, Easing.OUT_CUBIC, Easing.IN_OUT_QUAD];
    for (var i = 0; i < kinds.size(); i++) {
        Test.assert(nearF(Easing.apply(kinds[i], 0.0), 0.0, 0.0001));
        Test.assert(nearF(Easing.apply(kinds[i], 1.0), 1.0, 0.0001));
        Test.assert(nearF(Easing.apply(kinds[i], -2.0), 0.0, 0.0001));   // clamped
        Test.assert(nearF(Easing.apply(kinds[i], 3.0), 1.0, 0.0001));
        var prev = 0.0;
        for (var t = 1; t <= 20; t++) {
            var v = Easing.apply(kinds[i], t / 20.0);
            Test.assertMessage(v >= prev - 0.0001, "easing not monotonic");
            prev = v;
        }
    }
    Test.assert(nearF(Easing.apply(Easing.IN_OUT_SINE, 0.5), 0.5, 0.0001));
    Test.assert(nearF(Easing.apply(Easing.OUT_CUBIC, 0.5), 0.875, 0.0001));
    return true;
}

// ---- Skeleton / forward kinematics ---------------------------------------

(:test)
function testForwardKinematicsMatchesModel(logger as Logger) as Boolean {
    var def = ExercisePoseData.forExercise("calf_stretch");
    var j = Skeleton.newJointBuffer();
    Skeleton.fk(def[:poses][1], j);
    var g = [[Skeleton.J_HEEL_N, MotionGolden.CALF_HEEL_N], [Skeleton.J_WRIST_N, MotionGolden.CALF_WRIST_N],
             [Skeleton.J_KNEE_F, MotionGolden.CALF_KNEE_F], [Skeleton.J_HEAD, MotionGolden.CALF_HEAD]];
    for (var i = 0; i < g.size(); i++) {
        var idx = g[i][0];
        Test.assertMessage(nearF(j[2 * idx], g[i][1][0], 0.15), "x mismatch for joint " + idx);
        Test.assertMessage(nearF(j[2 * idx + 1], g[i][1][1], 0.15), "y mismatch for joint " + idx);
    }
    return true;
}

(:test)
function testCalfStretchConstraints(logger as Logger) as Boolean {
    var def = ExercisePoseData.forExercise("calf_stretch");
    var j = Skeleton.newJointBuffer();
    Skeleton.fk(def[:poses][1], j);
    Test.assertMessage(j[2 * Skeleton.J_HEEL_N + 1].abs() < 0.8, "rear heel must stay on the floor");
    Test.assertMessage((j[2 * Skeleton.J_WRIST_N] - def[:wallX]).abs() < 2.5, "hand must reach the wall");
    return true;
}

(:test)
function testMirroringIsSymmetric(logger as Logger) as Boolean {
    var cx = 195;
    var a = Skeleton.screenX(30.0, 10.0, 2.0, cx, false);
    var b = Skeleton.screenX(30.0, 10.0, 2.0, cx, true);
    Test.assert(nearF(a - cx, cx - b, 0.0001));
    Test.assert(nearF(a, 235.0, 0.0001));
    Test.assert(nearF(Skeleton.screenY(10.0, 0.0, 2.0, 100), 80.0, 0.0001));   // y up -> screen up
    return true;
}

// ---- Pose sampling ---------------------------------------------------------

(:test)
function testPoseInterpolationMatchesModel(logger as Logger) as Boolean {
    var s = sampleAt("cat_cow", 2000, false);
    Test.assert(nearF(s.pose[Skeleton.P_SPINE], MotionGolden.CC_2000_SPINE, 0.06));
    Test.assert(nearF(s.pose[Skeleton.P_HEAD], MotionGolden.CC_2000_HEAD, 0.06));
    Test.assertEqual(s.segment, MotionGolden.CC_2000_SEGMENT);
    Test.assertEqual(s.label(), "COW");
    return true;
}

(:test)
function testKeyframesAreExact(logger as Logger) as Boolean {
    var def = ExercisePoseData.forExercise("cat_cow");
    var start = sampleAt("cat_cow", 0, false);
    var mid = sampleAt("cat_cow", 4000, false);    // end of segment 0 = start of segment 1 = cow
    for (var q = 0; q < Skeleton.POSE_LEN; q++) {
        Test.assert(nearF(start.pose[q], def[:poses][0][q], 0.001));
        Test.assert(nearF(mid.pose[q], def[:poses][1][q], 0.001));
    }
    return true;
}

(:test)
function testRepetitionCounting(logger as Logger) as Boolean {
    var s = sampleAt("ankle_pumps", 5500, false);
    Test.assertEqual(s.reps, MotionGolden.AP_5500_REPS);
    Test.assert(nearF(s.pose[Skeleton.P_FTN], MotionGolden.AP_5500_FOOT, 0.06));
    Test.assertEqual(sampleAt("ankle_pumps", 1999, false).reps, 0);
    Test.assertEqual(sampleAt("ankle_pumps", 2000, false).reps, 1);
    Test.assertEqual(sampleAt("ankle_pumps", 60000, false).reps, 30);
    return true;
}

(:test)
function testHoldReachesAndStays(logger as Logger) as Boolean {
    var def = ExercisePoseData.forExercise("calf_stretch");
    var before = sampleAt("calf_stretch", 600, false);
    Test.assert(!before.holding);
    Test.assertEqual(before.label(), "SET UP");
    var times = [1200, 5000, 30000];
    for (var i = 0; i < times.size(); i++) {
        var s = sampleAt("calf_stretch", times[i], false);
        Test.assert(s.holding);
        Test.assertEqual(s.label(), "HOLD");
        Test.assertEqual(s.reps, 0);
        for (var q = 0; q < Skeleton.POSE_LEN; q++) {
            Test.assert(nearF(s.pose[q], def[:poses][1][q], 0.001));
        }
    }
    return true;
}

(:test)
function testReducedMotionSnapsToKeyPoses(logger as Logger) as Boolean {
    var def = ExercisePoseData.forExercise("cat_cow");
    var s = sampleAt("cat_cow", 2000, true);       // mid-transition, reduced: target pose (cow)
    for (var q = 0; q < Skeleton.POSE_LEN; q++) {
        Test.assert(nearF(s.pose[q], def[:poses][1][q], 0.001));
    }
    Test.assertEqual(s.reps, 0);
    return true;
}

(:test)
function testAnimationDataIsWellFormed(logger as Logger) as Boolean {
    var ids = ["calf_stretch", "cat_cow", "ankle_pumps"];
    for (var i = 0; i < ids.size(); i++) {
        var def = ExercisePoseData.forExercise(ids[i]);
        Test.assertMessage(def != null, "missing animation " + ids[i]);
        var poses = def[:poses];
        for (var p = 0; p < poses.size(); p++) {
            Test.assertEqual(poses[p].size(), Skeleton.POSE_LEN);
        }
        var seq = def[:seq];
        for (var k = 0; k < seq.size(); k++) {
            Test.assert(seq[k][0] >= 0 && seq[k][0] < poses.size());
            Test.assert(seq[k][1] >= 0 && seq[k][1] < poses.size());
            Test.assert(seq[k][2] > 0);
        }
        Test.assertMessage(ExerciseLibrary.get(ids[i]) != null, "animation without exercise " + ids[i]);
    }
    Test.assert(ExercisePoseData.forExercise("box") == null);   // breathing uses the ring, not a figure
    Test.assert(ExercisePoseData.forExercise(null) == null);
    return true;
}

// ---- Timer independence ---------------------------------------------------

(:test)
function testSessionTimingIndependentOfFrameRate(logger as Logger) as Boolean {
    // Same wall-clock span, ticked at 125 ms (animating) vs once (idle).
    var fast = new SessionEngine("leg_relief_10", SessionLibrary.get("leg_relief_10"), 0, true);
    var slow = new SessionEngine("leg_relief_10", SessionLibrary.get("leg_relief_10"), 0, true);
    fast.start(0);
    slow.start(0);
    for (var t = 125; t <= 250000; t += 125) {
        fast.tick(t);
    }
    slow.tick(250000);
    Test.assertEqual(fast.activeMs, slow.activeMs);
    Test.assertEqual(fast.stepIndex, slow.stepIndex);
    Test.assertEqual(fast.stepElapsedMs, slow.stepElapsedMs);
    Test.assertEqual(fast.completedCount, slow.completedCount);
    return true;
}

(:test)
function testPausedSessionFreezesAnimationTime(logger as Logger) as Boolean {
    var e = new SessionEngine("lower_body_8", SessionLibrary.get("lower_body_8"), 0, true);
    e.start(0);
    e.tick(30000);
    e.pause(30000);
    var c = new MotionController();
    c.onEvents(e, SessionEngine.EVT_STEP_START, 30000);
    var before = c.sideElapsedMs(e);
    e.tick(90000);                                    // paused for a minute
    Test.assertEqual(c.sideElapsedMs(e), before);
    Test.assert(!c.isAnimating(e, 90000));            // frozen frame: idle frame rate
    return true;
}

(:test)
function testAlternatingSideRestartsAndMirrors(logger as Logger) as Boolean {
    // lower_body_8 starts with calf_stretch, 120 s, alternating sides.
    var e = new SessionEngine("lower_body_8", SessionLibrary.get("lower_body_8"), 0, true);
    e.start(0);
    var c = new MotionController();
    c.onEvents(e, SessionEngine.EVT_STEP_START, 0);
    e.tick(30000);
    Test.assert(!c.isMirrored(e));
    Test.assertEqual(c.sideElapsedMs(e), 30000);
    e.tick(60500);
    Test.assert(c.isMirrored(e));
    Test.assertEqual(c.sideElapsedMs(e), 500);       // set-up replays on the right side
    return true;
}

// ---- Tween -----------------------------------------------------------------

(:test)
function testTweenProgress(logger as Logger) as Boolean {
    var t = new Tween();
    Test.assert(nearF(t.value(0), 1.0, 0.0001));     // never started: finished
    t.start(1000, 200, Easing.LINEAR);
    if (MotionConfig.smooth()) {
        Test.assert(nearF(t.value(1100), 0.5, 0.0001));
        Test.assert(t.isRunning(1100));
    }
    Test.assert(nearF(t.value(1300), 1.0, 0.0001));
    Test.assert(!t.isRunning(1300));
    return true;
}

(:test)
function testBreathingPulseRadius(logger as Logger) as Boolean {
    Test.assertEqual(BreathingPulse.radius(0, 0, 46, 76), 46);      // inhale starts small
    Test.assertEqual(BreathingPulse.radius(0, 1000, 46, 76), 76);   // ... ends full
    Test.assertEqual(BreathingPulse.radius(1, 300, 46, 76), 76);    // hold after inhale: full
    Test.assertEqual(BreathingPulse.radius(2, 1000, 46, 76), 46);   // exhale ends small
    Test.assertEqual(BreathingPulse.radius(3, 500, 46, 76), 46);    // pause: small
    Test.assertEqual(BreathingPulse.radius(0, 500, 46, 76), 61);    // midpoint
    return true;
}
