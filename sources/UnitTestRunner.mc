import Toybox.Activity;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Test;

// =============================================================================
// UnitTestRunner — Strict per-mode verification for RacePilot.
// Run via: monkeyc -t ... then monkeydo ... -t
// Stripped from release builds (:(test) annotation).
// =============================================================================

class UnitTestRunner {

    // ---- Helper: build a fresh engine with given settings ----
    private static function makeEngine(preset as Number, distM as Number, timeMin as Number, runType as Number, trackLen as Number) as PaceEngine {
        var e = new PaceEngine();
        e.applySettings(preset, distM, timeMin, runType, 100, trackLen, 50, false);
        return e;
    }

    // =========================================================================
    // OUTDOOR MODE
    // =========================================================================

    // Steady 5:00/km should produce ~300 s/km pace and correct projection
    (:test)
    public static function testOutdoorSteadyPace(logger as Test.Logger) as Boolean {
        var e = makeEngine(8, 5000, 25, 1, 400); // 5K Sub 25 = 1500s
        var snap = e.updateFromValues(3.3333f, 1000.0f, 300000, Activity.TIMER_STATE_ON, Position.QUALITY_GOOD, 0.0f, 10.0f, 175, null);
        Test.assertMessage(snap.activeRunMode == MODE_OUTDOOR_GPS, "Mode must be OUTDOOR");
        Test.assertMessage(snap.lapPaceSec >= 295.0f && snap.lapPaceSec <= 305.0f, "Pace should be ~300s, got " + snap.lapPaceSec.format("%.1f"));
        Test.assertMessage(snap.projectedFinishSec >= 1490.0f && snap.projectedFinishSec <= 1510.0f, "Projection ~1500s");
        return true;
    }

    // GPS spike (unrealistic 11 m/s) must be rejected
    (:test)
    public static function testOutdoorSpikeRejection(logger as Test.Logger) as Boolean {
        var e = makeEngine(8, 5000, 25, 1, 400);
        e.updateFromValues(3.3333f, 500.0f, 150000, Activity.TIMER_STATE_ON, Position.QUALITY_GOOD, 0.0f, 10.0f, 174, null);
        var snap = e.updateFromValues(11.0f, 511.0f, 151000, Activity.TIMER_STATE_ON, Position.QUALITY_GOOD, 0.0f, 10.0f, 174, null);
        Test.assertMessage(snap.lapPaceSec >= 290.0f && snap.lapPaceSec <= 310.0f, "Spike must not corrupt pace");
        return true;
    }

    // GPS loss within 5s grace should hold last valid pace
    (:test)
    public static function testOutdoorTunnelHold(logger as Test.Logger) as Boolean {
        var e = makeEngine(8, 5000, 25, 1, 400);
        e.updateFromValues(3.3333f, 1000.0f, 300000, Activity.TIMER_STATE_ON, Position.QUALITY_GOOD, 0.0f, 10.0f, 176, null);
        var snap = e.updateFromValues(0.2f, 1012.0f, 304000, Activity.TIMER_STATE_ON, Position.QUALITY_NOT_AVAILABLE, 0.0f, 10.0f, 176, null);
        Test.assertMessage(snap.lapPaceSec >= 295.0f && snap.lapPaceSec <= 305.0f, "Tunnel hold should keep pace");
        return true;
    }

    // No-target must hide need pace and show placeholder projection
    (:test)
    public static function testOutdoorNoTarget(logger as Test.Logger) as Boolean {
        var e = makeEngine(0, 5000, 25, 1, 400); // preset 0 = Set Target
        var snap = e.updateFromValues(3.3333f, 1000.0f, 300000, Activity.TIMER_STATE_ON, Position.QUALITY_GOOD, 0.0f, 10.0f, 175, null);
        Test.assertMessage(!snap.hasTarget, "No target expected");
        Test.assertMessage(snap.hideNeedPace, "Need pace must hide with no target");
        Test.assertMessage(snap.state == STATE_NO_TARGET, "State must be NO_TARGET");
        return true;
    }

    // =========================================================================
    // TREADMILL MODE
    // =========================================================================

    // Startup at t=5s must NOT show 24:30/km (historical bug)
    (:test)
    public static function testTreadmillStartupNoLag(logger as Test.Logger) as Boolean {
        var e = makeEngine(12, 5000, 30, 3, 400); // Treadmill, 5K Sub 30
        // native 2.857 m/s = 5:50/km; rawDist tiny (4m) would cause fake slow pace
        var snap = e.updateFromValues(2.8571f, 4.0f, 5000, Activity.TIMER_STATE_ON, null, null, null, 170, Activity.SUB_SPORT_TREADMILL);
        Test.assertMessage(snap.activeRunMode == MODE_TREADMILL, "Mode must be TREADMILL");
        Test.assertMessage(snap.lapPaceSec >= 340.0f && snap.lapPaceSec <= 360.0f, "Startup pace must be ~350s not 1470s, got " + snap.lapPaceSec.format("%.1f"));
        return true;
    }

    // Calibration x105 applied exactly once to distance
    (:test)
    public static function testTreadmillCalibration(logger as Test.Logger) as Boolean {
        var e = new PaceEngine();
        e.applySettings(12, 5000, 30, 3, 105, 400, 50, false);
        var snap = e.updateFromValues(3.0f, 1000.0f, 333000, Activity.TIMER_STATE_ON, null, null, null, 172, Activity.SUB_SPORT_TREADMILL);
        // 1000 * 1.05 = 1050 (not 1102.5)
        Test.assertMessage(snap.distanceMeters >= 1049.0f && snap.distanceMeters <= 1051.0f, "Calibrated dist must be 1050m, got " + snap.distanceMeters.format("%.1f"));
        return true;
    }

    // Treadmill unit is /km not /400m
    (:test)
    public static function testTreadmillUnit(logger as Test.Logger) as Boolean {
        var e = makeEngine(12, 5000, 30, 3, 400);
        var snap = e.updateFromValues(3.0f, 1000.0f, 333000, Activity.TIMER_STATE_ON, null, null, null, 172, Activity.SUB_SPORT_TREADMILL);
        Test.assertMessage(snap.paceUnitStr.equals("/km"), "Treadmill unit must be /km, got " + snap.paceUnitStr);
        return true;
    }

    // =========================================================================
    // TRACK MODE
    // =========================================================================

    // 400m track: unit /400m, lap count 12/12.5 for 5K, pace per lap
    (:test)
    public static function testTrack400m(logger as Test.Logger) as Boolean {
        var e = makeEngine(8, 5000, 25, 2, 400); // Track, 400m
        var snap = e.updateFromValues(3.3333f, 4800.0f, 1440000, Activity.TIMER_STATE_ON, Position.QUALITY_NOT_AVAILABLE, null, null, 180, Activity.SUB_SPORT_TRACK);
        Test.assertMessage(snap.isTrackMode, "isTrackMode must be true");
        Test.assertMessage(snap.paceUnitStr.equals("/400m"), "Unit must be /400m, got " + snap.paceUnitStr);
        Test.assertMessage(snap.lapCountText.equals("12/12.5"), "Lap count must be 12/12.5, got " + snap.lapCountText);
        // 3.3333 m/s => 400/3.3333 = 120s per 400m
        Test.assertMessage(snap.lapPaceSec >= 115.0f && snap.lapPaceSec <= 125.0f, "Lap pace ~120s, got " + snap.lapPaceSec.format("%.1f"));
        return true;
    }

    // Custom 250m track: 20 laps for 5K, no double LAP prefix
    (:test)
    public static function testTrack250m(logger as Test.Logger) as Boolean {
        var e = makeEngine(8, 5000, 25, 2, 250);
        var snap = e.updateFromValues(3.3333f, 2500.0f, 750000, Activity.TIMER_STATE_ON, null, null, null, 180, Activity.SUB_SPORT_TRACK);
        Test.assertMessage(snap.paceUnitStr.equals("/250m"), "Unit must be /250m, got " + snap.paceUnitStr);
        Test.assertMessage(snap.lapCountText.equals("10/20"), "Lap count must be 10/20, got " + snap.lapCountText);
        // 250/3.3333 = 75s per lap
        Test.assertMessage(snap.lapPaceSec >= 70.0f && snap.lapPaceSec <= 80.0f, "Lap pace ~75s");
        return true;
    }

    // Track with no target: lap count must be just number (no "LAP LAP")
    (:test)
    public static function testTrackNoTargetLapCount(logger as Test.Logger) as Boolean {
        var e = makeEngine(0, 5000, 25, 2, 400); // no target
        var snap = e.updateFromValues(3.3333f, 1200.0f, 360000, Activity.TIMER_STATE_ON, null, null, null, 180, Activity.SUB_SPORT_TRACK);
        Test.assertMessage(!snap.lapCountText.substring(0, 3).equals("LAP"), "lapCountText must NOT contain LAP prefix, got: " + snap.lapCountText);
        return true;
    }

    // =========================================================================
    // STATE MACHINE
    // =========================================================================

    // Pause freezes projection
    (:test)
    public static function testPauseFreezes(logger as Test.Logger) as Boolean {
        var e = makeEngine(8, 5000, 25, 1, 400);
        var s1 = e.updateFromValues(3.3333f, 2000.0f, 600000, Activity.TIMER_STATE_ON, Position.QUALITY_GOOD, 0.0f, 10.0f, 175, null);
        var projBefore = s1.projectedFinishSec;
        var s2 = e.updateFromValues(0.0f, 2000.0f, 600000, Activity.TIMER_STATE_PAUSED, Position.QUALITY_GOOD, 0.0f, 10.0f, 0, null);
        Test.assertMessage(s2.state == STATE_MANUAL_PAUSED, "Must be MANUAL_PAUSED");
        Test.assertMessage(s2.freezeProjections, "Projection must be frozen");
        Test.assertMessage(s2.projectedFinishSec == projBefore, "Projection value must not change while paused");
        return true;
    }

    // Finish lock prevents flicker back to racing on distance jitter
    (:test)
    public static function testFinishLock(logger as Test.Logger) as Boolean {
        var e = makeEngine(8, 5000, 25, 1, 400);
        var s1 = e.updateFromValues(3.4f, 5001.0f, 1480000, Activity.TIMER_STATE_ON, Position.QUALITY_GOOD, 0.0f, 10.0f, 178, null);
        Test.assertMessage(s1.state == STATE_FINISHED, "Must be FINISHED");
        var s2 = e.updateFromValues(0.5f, 4998.0f, 1484000, Activity.TIMER_STATE_ON, Position.QUALITY_GOOD, 0.0f, 10.0f, 100, null);
        Test.assertMessage(s2.state == STATE_LOCKED, "Must be LOCKED after finish");
        Test.assertMessage(s2.hideNeedPace, "Need pace hidden when locked");
        return true;
    }

    // No false auto-pause when distance still increasing
    (:test)
    public static function testAutoPauseNoFalsePositive(logger as Test.Logger) as Boolean {
        var e = makeEngine(8, 5000, 25, 1, 400);
        // first tick establishes distance
        e.updateFromValues(3.3333f, 1000.0f, 300000, Activity.TIMER_STATE_ON, Position.QUALITY_GOOD, 0.0f, 10.0f, 175, null);
        // speed reported 0 (GPS dropout) but distance increases by 3m
        var snap = e.updateFromValues(0.0f, 1003.0f, 301000, Activity.TIMER_STATE_ON, Position.QUALITY_GOOD, 0.0f, 10.0f, 175, null);
        Test.assertMessage(snap.state != STATE_PAUSED, "Must NOT auto-pause when distance increases, got state");
        return true;
    }

    // =========================================================================
    // SETTINGS VALIDATION
    // =========================================================================

    // Invalid runType must fall back to AUTO mode (not crash)
    (:test)
    public static function testInvalidRunTypeFallback(logger as Test.Logger) as Boolean {
        var e = new PaceEngine();
        e.applySettings(8, 5000, 25, 99, 100, 400, 50, false); // invalid runType
        var snap = e.updateFromValues(3.3333f, 1000.0f, 300000, Activity.TIMER_STATE_ON, Position.QUALITY_GOOD, 0.0f, 10.0f, 175, null);
        Test.assertMessage(snap.activeRunMode == MODE_OUTDOOR_GPS, "Invalid runType falls back to auto->outdoor, got " + snap.activeRunMode);
        return true;
    }

    // Zero distance/time must not divide-by-zero
    (:test)
    public static function testZeroValuesSafe(logger as Test.Logger) as Boolean {
        var e = makeEngine(8, 5000, 25, 1, 400);
        var snap = e.updateFromValues(0.0f, 0.0f, 0, Activity.TIMER_STATE_ON, null, null, null, null, null);
        Test.assertMessage(snap.lapPaceSec >= 0.0f, "Pace must be >= 0, no NaN");
        Test.assertMessage(snap.distanceMeters >= 0.0f, "Distance must be >= 0");
        return true;
    }
}
