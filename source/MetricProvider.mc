import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// One snapshot of device data per update. A null field means "not available right now".
// Nothing here estimates or substitutes a value: see docs/CAPABILITY_MATRIX.md.
class Metrics {
    var steps as Number? = null;
    var stepGoal as Number? = null;
    var distanceCm as Number? = null;
    var calories as Number? = null;          // total kcal (Garmin has no active-calorie API)
    var intensityDay as Number? = null;      // moderate + 2 x vigorous, today
    var intensityWeek as Number? = null;     // same, this week
    var intensityWeekGoal as Number? = null;
    var moveBar as Number? = null;           // 0..5
    var floors as Number? = null;
    var floorsGoal as Number? = null;
    var heartRate as Number? = null;
    var heartRateStale as Boolean = false;   // last stored sample, older than 10 min
    var battery as Float? = null;
    var batteryDays as Number? = null;
    var metric as Boolean = true;
}

module MetricProvider {

    const HR_STALE_SECONDS = 600;

    function read() as Metrics {
        if (Preview.ON) {
            return Preview.metrics();
        }
        var m = new Metrics();

        var info = ActivityMonitor.getInfo();
        if (info != null) {
            m.steps = nonNeg(info.steps);
            m.stepGoal = info.stepGoal;
            m.distanceCm = nonNeg(info.distance);
            m.calories = nonNeg(info.calories);
            if (info has :activeMinutesDay && info.activeMinutesDay != null) {
                m.intensityDay = nonNeg(info.activeMinutesDay.total);
            }
            if (info has :activeMinutesWeek && info.activeMinutesWeek != null) {
                m.intensityWeek = nonNeg(info.activeMinutesWeek.total);
            }
            if (info has :activeMinutesWeekGoal) {
                m.intensityWeekGoal = info.activeMinutesWeekGoal;
            }
            m.moveBar = info.moveBarLevel;
            if (info has :floorsClimbed) {
                m.floors = nonNeg(info.floorsClimbed);
            }
            if (info has :floorsClimbedGoal) {
                m.floorsGoal = info.floorsClimbedGoal;
            }
        }

        readHeartRate(m);

        var stats = System.getSystemStats();
        m.battery = stats.battery;
        if (stats has :batteryInDays && stats.batteryInDays != null) {
            var d = stats.batteryInDays.toNumber();
            m.batteryDays = d > 0 ? d : null;
        }

        var ds = System.getDeviceSettings();
        m.metric = ds.distanceUnits != System.UNIT_STATUTE;
        return m;
    }

    function readHeartRate(m as Metrics) as Void {
        var ai = Activity.getActivityInfo();
        if (ai != null && ai.currentHeartRate != null && ai.currentHeartRate > 0) {
            m.heartRate = ai.currentHeartRate;
            return;
        }
        if (!(ActivityMonitor has :getHeartRateHistory)) {
            return;
        }
        var it = ActivityMonitor.getHeartRateHistory(1, true);
        var s = it.next();
        if (s == null || s.heartRate == null || s.heartRate == ActivityMonitor.INVALID_HR_SAMPLE) {
            return;
        }
        m.heartRate = s.heartRate;
        if (s.when != null) {
            m.heartRateStale = Time.now().subtract(s.when).value() > HR_STALE_SECONDS;
        }
    }

    function nonNeg(v as Number?) as Number? {
        return (v != null && v >= 0) ? v : null;
    }
}
