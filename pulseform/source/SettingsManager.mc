import Toybox.Application;
import Toybox.Lang;

// Validated view of the app properties. Every read falls back to a safe default, so
// a missing, renamed or out-of-range value can never break rendering.
class SettingsManager {

    static const LAYOUT_BALANCED = 0;
    static const LAYOUT_MINIMAL = 1;
    static const LAYOUT_DENSE = 2;
    static const LAYOUT_DIAL = 3;
    static const LAYOUT_HORIZON = 4;
    static const LAYOUT_STACK = 5;

    static const STYLE_CIRCULAR = 0;
    static const STYLE_LINEAR = 1;
    static const STYLE_SEGMENTED = 2;

    static const CLOCK_DEVICE = 0;
    static const CLOCK_12 = 1;
    static const CLOCK_24 = 2;

    // id => [default, min, max]; booleans use [default]
    static const NUMBERS = {
        "Layout" => [0, 0, 5],
        "ClockFormat" => [0, 0, 2],
        "StepGoalMode" => [0, 0, 1],
        "StepGoal" => [10000, 500, 100000],
        "CalorieTarget" => [0, 0, 20000],
        "IntensityGoalMode" => [0, 0, 1],
        "IntensityGoal" => [150, 10, 2000],
        "GoalStyle" => [0, 0, 2],
        "MinimalMetric" => [0, 0, 4],
        "Theme" => [0, 0, 8],
        "Look" => [0, 0, 3],
        "TrackWeight" => [1, 0, 2],
        "AodStyle" => [0, 0, 1]
    };
    static const BOOLEANS = {
        "ShowSeconds" => false,
        "ShowAmPm" => true,
        "ShowDate" => true,
        "ShowDistance" => true,
        "ShowCalories" => true,
        "ShowIntensity" => true,
        "ShowMoveBar" => true,
        "ShowHeartRate" => true,
        "ShowFloors" => true,
        "ShowBattery" => true,
        "ShowLabels" => true
    };
    static const DISTANCE_DEFAULT = 0.0;
    static const DISTANCE_MAX = 200.0;

    var layout as Number = 0;
    var clockFormat as Number = 0;
    var showSeconds as Boolean = false;
    var showAmPm as Boolean = true;
    var showDate as Boolean = true;
    var stepGoalMode as Number = 0;
    var stepGoal as Number = 10000;
    var distanceTarget as Float = 0.0;     // in the watch's distance unit, 0 = off
    var calorieTarget as Number = 0;        // total kcal, 0 = off
    var intensityGoalMode as Number = 0;
    var intensityGoal as Number = 150;
    var goalStyle as Number = 0;
    var showDistance as Boolean = true;
    var showCalories as Boolean = true;
    var showIntensity as Boolean = true;
    var showMoveBar as Boolean = true;
    var showHeartRate as Boolean = true;
    var showFloors as Boolean = true;
    var showBattery as Boolean = true;
    var minimalMetric as Number = 0;
    var theme as Number = 0;            // accent: 0 = the look's own, 1..8 = fixed colour
    var look as Number = 0;             // ThemeManager.LOOK_*
    var trackWeight as Number = 1;
    var showLabels as Boolean = true;
    var aodStyle as Number = 0;

    function initialize() {
        load();
    }

    function load() as Void {
        if (readBool("ResetDefaults", false)) {
            resetAll();
        }
        layout = num("Layout");
        clockFormat = num("ClockFormat");
        showSeconds = bool("ShowSeconds");
        showAmPm = bool("ShowAmPm");
        showDate = bool("ShowDate");
        stepGoalMode = num("StepGoalMode");
        stepGoal = num("StepGoal");
        distanceTarget = readDistance();
        calorieTarget = num("CalorieTarget");
        intensityGoalMode = num("IntensityGoalMode");
        intensityGoal = num("IntensityGoal");
        goalStyle = num("GoalStyle");
        showDistance = bool("ShowDistance");
        showCalories = bool("ShowCalories");
        showIntensity = bool("ShowIntensity");
        showMoveBar = bool("ShowMoveBar");
        showHeartRate = bool("ShowHeartRate");
        showFloors = bool("ShowFloors");
        showBattery = bool("ShowBattery");
        minimalMetric = num("MinimalMetric");
        theme = num("Theme");
        look = num("Look");
        trackWeight = num("TrackWeight");
        showLabels = bool("ShowLabels");
        aodStyle = num("AodStyle");
        ThemeManager.apply(look, theme);
    }

    // "Restore all defaults" switch: write every default back, then turn itself off.
    private function resetAll() as Void {
        var keys = NUMBERS.keys();
        for (var i = 0; i < keys.size(); i++) {
            write(keys[i], (NUMBERS[keys[i]] as Array)[0]);
        }
        keys = BOOLEANS.keys();
        for (var i = 0; i < keys.size(); i++) {
            write(keys[i], BOOLEANS[keys[i]]);
        }
        write("DistanceTarget", DISTANCE_DEFAULT);
        write("ResetDefaults", false);
    }

    private function num(key as String) as Number {
        var spec = NUMBERS[key] as Array<Number>;
        return validNumber(read(key), spec[0], spec[1], spec[2]);
    }

    private function bool(key as String) as Boolean {
        return readBool(key, BOOLEANS[key] as Boolean);
    }

    private function readBool(key as String, def as Boolean) as Boolean {
        var v = read(key);
        return v instanceof Boolean ? v : def;
    }

    private function readDistance() as Float {
        return validDistance(read("DistanceTarget"));
    }

    // Pure validation helpers (unit tested).
    static function validNumber(v, def as Number, lo as Number, hi as Number) as Number {
        if (v instanceof Float || v instanceof Double || v instanceof Long) {
            v = v.toNumber();
        }
        if (v instanceof Number && v >= lo && v <= hi) {
            return v;
        }
        return def;
    }

    static function validDistance(v) as Float {
        if (v instanceof Number || v instanceof Long || v instanceof Double) {
            v = v.toFloat();
        }
        if (v instanceof Float && v >= 0.0 && v <= DISTANCE_MAX) {
            return v;
        }
        return DISTANCE_DEFAULT;
    }

    private function read(key as String) {
        try {
            return Application.Properties.getValue(key);
        } catch (e) {
            return null;
        }
    }

    private function write(key as String, v) as Void {
        try {
            Application.Properties.setValue(key, v);
        } catch (e) {
            // ignore: defaults still apply on read
        }
    }
}
