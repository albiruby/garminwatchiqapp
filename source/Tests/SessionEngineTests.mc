import Toybox.Lang;
import Toybox.Test;

(:debug)
function newEngine(id as String, countdown as Number, auto as Boolean) as SessionEngine {
    return new SessionEngine(id, SessionLibrary.get(id), countdown, auto);
}

(:test)
function testEngineFullRun(logger as Logger) as Boolean {
    var e = newEngine("leg_relief_10", 0, true);
    Test.assertEqual(e.start(0), SessionEngine.EVT_STEP_START);
    Test.assertEqual(e.state, SessionEngine.RUNNING);
    var evt = e.tick(600000);
    Test.assert((evt & SessionEngine.EVT_COMPLETE) != 0);
    Test.assertEqual(e.state, SessionEngine.COMPLETED);
    var r = e.buildRecord(1795000000, 85, 74);
    Test.assertEqual(r.get("dur"), 600);
    Test.assertEqual(r.get("plan"), 600);
    Test.assertEqual(r.get("done"), 5);
    Test.assertEqual(r.get("st"), Models.STATUS_COMPLETED);
    Test.assertEqual(r.get("cyc"), 12); // 120 s at 10 s/cycle
    var t = r.get("t");
    Test.assertEqual(t.get("br"), 120);
    Test.assertEqual(t.get("an"), 120);
    Test.assertEqual(t.get("el"), 300);
    Test.assertEqual(t.get("tr"), 60);
    Test.assertEqual(t.get("L"), 30);
    Test.assertEqual(t.get("R"), 30);
    Test.assertEqual(r.get("hrB"), 85);
    return true;
}

(:test)
function testEnginePhaseAndStepEvents(logger as Logger) as Boolean {
    var e = newEngine("leg_relief_10", 0, true);
    e.start(0);
    Test.assertEqual(e.tick(1000), SessionEngine.EVT_NONE);
    Test.assert((e.tick(4000) & SessionEngine.EVT_PHASE) != 0); // inhale -> exhale
    Test.assert((e.tick(120000) & SessionEngine.EVT_STEP_START) != 0);
    Test.assertEqual(e.stepIndex, 1);
    e.tick(180000); // ankle circles start
    Test.assertEqual(e.currentSide(), "L");
    Test.assert((e.tick(210000) & SessionEngine.EVT_SIDE) != 0);
    Test.assertEqual(e.currentSide(), "R");
    return true;
}

(:test)
function testEnginePauseResume(logger as Logger) as Boolean {
    var e = newEngine("box_5", 0, true);
    e.start(0);
    e.tick(10000);
    e.pause(10000);
    Test.assertEqual(e.state, SessionEngine.PAUSED);
    e.tick(70000);
    Test.assertEqual(e.stepElapsedMs, 10000); // paused time not counted
    e.resume(70000);
    e.tick(80000);
    Test.assertEqual(e.stepElapsedMs, 20000);
    Test.assertEqual(e.activeMs, 20000);
    return true;
}

(:test)
function testEngineSkip(logger as Logger) as Boolean {
    var e = newEngine("leg_relief_10", 0, true);
    e.start(0);
    e.tick(30000);
    e.skip(30000);
    Test.assertEqual(e.stepIndex, 1);
    Test.assertEqual(e.skippedCount, 1);
    Test.assertEqual(e.completedCount, 0);
    Test.assertEqual(e.tags.get("br"), 30); // partial time kept
    Test.assertEqual(e.cycles, 3);
    return true;
}

(:test)
function testEngineCountdown(logger as Logger) as Boolean {
    var e = newEngine("box_5", 3, true);
    Test.assertEqual(e.start(0), SessionEngine.EVT_NONE);
    Test.assertEqual(e.state, SessionEngine.COUNTDOWN);
    e.tick(2000);
    Test.assertEqual(e.state, SessionEngine.COUNTDOWN);
    Test.assert((e.tick(5000) & SessionEngine.EVT_STEP_START) != 0);
    Test.assertEqual(e.state, SessionEngine.RUNNING);
    Test.assertEqual(e.stepElapsedMs, 2000); // countdown excluded
    return true;
}

(:test)
function testEngineManualAdvance(logger as Logger) as Boolean {
    var e = newEngine("leg_reset_5", 0, false);
    e.start(0);
    e.tick(60000);
    Test.assertEqual(e.state, SessionEngine.AWAITING_NEXT);
    e.tick(90000);
    Test.assertEqual(e.activeMs, 60000); // waiting time not counted
    Test.assertEqual(e.next(90000), SessionEngine.EVT_STEP_START);
    Test.assertEqual(e.stepIndex, 1);
    return true;
}

(:test)
function testEngineCancel(logger as Logger) as Boolean {
    var e = newEngine("leg_relief_10", 0, true);
    e.start(0);
    e.tick(100000);
    e.cancel(100000);
    Test.assertEqual(e.state, SessionEngine.CANCELLED);
    var r = e.buildRecord(1795000000, null, null);
    Test.assertEqual(r.get("st"), Models.STATUS_CANCELLED);
    Test.assertEqual(r.get("dur"), 100);
    Test.assertEqual(r.get("done"), 0);
    Test.assert(!r.hasKey("hrB")); // missing sensor data is omitted, not faked
    return true;
}

//! Exercise names and cues must fit the round HUD without truncation.
(:test)
function testContentFitsHud(logger as Logger) as Boolean {
    for (var c = 0; c < Models.CAT_COUNT; c++) {
        var ids = SessionLibrary.idsFor(c);
        for (var i = 0; i < ids.size(); i++) {
            var steps = SessionLibrary.get(ids[i])[SessionLibrary.F_STEPS];
            for (var j = 0; j < steps.size(); j++) {
                var ex = ExerciseLibrary.get(steps[j][0]);
                Test.assertMessage(ex != null, "missing exercise " + steps[j][0]);
                Test.assertMessage(ex[ExerciseLibrary.F_NAME].length() <= 22, "name too long: " + ex[ExerciseLibrary.F_NAME]);
                Test.assertMessage(ex[ExerciseLibrary.F_CUE].length() <= 26, "cue too long: " + ex[ExerciseLibrary.F_CUE]);
            }
        }
    }
    return true;
}

(:test)
function testEnginePrevious(logger as Logger) as Boolean {
    var e = newEngine("leg_relief_10", 0, true);
    e.start(0);
    e.tick(130000);                        // step 1 (ankle pumps), 10 s in
    Test.assertEqual(e.stepIndex, 1);
    // more than 3 s into the step: restart it
    Test.assertEqual(e.previous(130000), SessionEngine.EVT_STEP_START);
    Test.assertEqual(e.stepIndex, 1);
    Test.assertEqual(e.stepElapsedMs, 0);
    // within 3 s: go back one exercise
    e.tick(131000);
    e.previous(131000);
    Test.assertEqual(e.stepIndex, 0);
    Test.assertEqual(e.state, SessionEngine.RUNNING);
    // first exercise: previous restarts it; a paused session stays paused
    e.togglePause(132000);
    e.previous(132000);
    Test.assertEqual(e.stepIndex, 0);
    Test.assertEqual(e.state, SessionEngine.PAUSED);
    // active time already done is kept
    Test.assert(e.activeMs >= 131000);
    return true;
}

(:test)
function testEngineRestBetweenExercises(logger as Logger) as Boolean {
    var e = newEngine("leg_relief_10", 0, true);
    e.restMs = 10000;
    e.start(0);
    // first exercise is 120 s; at 125 s we are 5 s into the rest
    var evt = e.tick(125000);
    Test.assert((evt & SessionEngine.EVT_STEP_DONE) != 0);
    Test.assert((evt & SessionEngine.EVT_STEP_START) == 0);   // no buzz until the rest ends
    Test.assertEqual(e.state, SessionEngine.COUNTDOWN);
    Test.assert(e.resting);
    Test.assertEqual(e.stepIndex, 1);
    Test.assertEqual(e.activeMs, 120000);                     // rest is not active time
    // rest ends at 130 s; leftover 2 s run in the next exercise
    evt = e.tick(132000);
    Test.assert((evt & SessionEngine.EVT_STEP_START) != 0);
    Test.assertEqual(e.state, SessionEngine.RUNNING);
    Test.assertEqual(e.stepElapsedMs, 2000);
    // DOWN during a rest ends it early
    e.tick(192000);                                           // exercise 2 (60 s) done at 190 s
    Test.assert(e.resting);
    Test.assertEqual(e.skip(193000), SessionEngine.EVT_STEP_START);
    Test.assertEqual(e.state, SessionEngine.RUNNING);
    Test.assertEqual(e.stepIndex, 2);
    return true;
}

(:test)
function testCustomBreathingSession(logger as Logger) as Boolean {
    var def = SessionLibrary.get("custom_breath");
    Test.assert(def != null);
    var steps = def[SessionLibrary.F_STEPS];
    Test.assertEqual(steps[0][1], SettingsRepository.customMinutes() * 60);
    var ex = ExerciseLibrary.get("custom");
    Test.assertEqual(ex[ExerciseLibrary.F_TYPE], Models.TYPE_BREATHING);
    Test.assert(BreathingCalculator.cycleLength(ex[ExerciseLibrary.F_PATTERN]) > 0);
    return true;
}
