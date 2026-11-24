import Toybox.ActivityMonitor;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Text for the four configurable slots. Garmin's native complications are preferred so
// values match the system watch faces; a few daily totals come from ActivityMonitor.
// Every reader returns "--" when the device does not provide the metric.
module Slots {

    // LEFT ring: performance
    enum {
        L_VO2_RUN, L_VO2_BIKE, L_HEART_RATE, L_BODY_BATTERY, L_STRESS, L_TRAINING_STATUS,
        L_RECOVERY, L_RACE_5K, L_RACE_10K, L_RACE_HALF, L_RACE_FULL
    }
    // RIGHT ring: training volume
    enum {
        R_WEEK_RUN, R_WEEK_BIKE, R_WEEK_ACTIVE, R_WEEK_INTENSITY, R_DAY_DISTANCE, R_DAY_CALORIES, R_DAY_ACTIVE
    }
    // TOP plaque: date and context
    enum {
        T_WEEKDAY_DATE, T_DATE, T_WEATHER, T_TEMPERATURE, T_SUNRISE, T_SUNSET, T_CALENDAR
    }
    // BOTTOM plaque: daily metrics
    enum {
        B_STEPS, B_CALORIES, B_DISTANCE, B_ACTIVE, B_FLOORS, B_BATTERY, B_HEART_RATE, B_RESPIRATION, B_PULSE_OX
    }

    const NONE = "--";

    function comp(type as Complications.Type) as Numeric or String or Null {
        try {
            var c = Complications.getComplication(new Complications.Id(type));
            return c.value as Numeric or String or Null;
        } catch (e) {
            return null;
        }
    }

    function num(v as Numeric or String or Null, fmt as String) as String {
        return (v instanceof Number || v instanceof Float || v instanceof Long || v instanceof Double) ? v.format(fmt) : NONE;
    }

    function statute() as Boolean {
        return System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE;
    }

    // meters -> "12.4" in km or miles
    function dist(meters as Numeric or String or Null) as String {
        if (!(meters instanceof Number || meters instanceof Float || meters instanceof Long || meters instanceof Double)) {
            return NONE;
        }
        var d = meters.toFloat() / (statute() ? 1609.344 : 1000.0);
        return d >= 100 ? d.format("%d") : d.format("%.1f");
    }

    function distUnit() as String {
        return statute() ? "MI" : "KM";
    }

    // seconds -> "22:31" (under an hour) or "1:45" (h:mm)
    function raceTime(v as Numeric or String or Null) as String {
        if (!(v instanceof Number)) {
            return NONE;
        }
        var s = v as Number;
        if (s <= 0) {
            return NONE;
        }
        if (s < 3600) {
            return (s / 60).format("%d") + ":" + (s % 60).format("%02d");
        }
        return (s / 3600).format("%d") + ":" + ((s % 3600) / 60).format("%02d");
    }

    // seconds since local midnight -> "05:31"
    function clockText(v as Numeric or String or Null) as String {
        if (!(v instanceof Number)) {
            return NONE;
        }
        var s = v as Number;
        var h = s / 3600;
        if (!System.getDeviceSettings().is24Hour) {
            h = h % 12;
            if (h == 0) {
                h = 12;
            }
        }
        return h.format("%02d") + ":" + ((s % 3600) / 60).format("%02d");
    }

    // Garmin's training status words, shortened to fit the ring.
    function statusShort(v as Numeric or String or Null) as String {
        if (!(v instanceof String) || v.length() == 0) {
            return NONE;
        }
        var s = v.toUpper();
        while (s.find("_") != null) {
            var i = s.find("_") as Number;
            s = s.substring(0, i) + " " + s.substring(i + 1, s.length());
        }
        if (s.find("NO") == 0) {
            return NONE;
        }
        var known = ["UNPRODUCTIVE", "UNPROD", "PRODUCTIVE", "PROD", "MAINTAINING", "MAINT", "RECOV", "RECOV",
                     "PEAKING", "PEAK", "OVERREACHING", "OVER", "DETRAINING", "DETRN", "STRAINED", "STRAIN", "NO STATUS", NONE];
        for (var i = 0; i < known.size(); i += 2) {
            if (s.find(known[i] as String) != null) {
                return known[i + 1] as String;
            }
        }
        return s.length() > 6 ? s.substring(0, 6) as String : s;
    }

    function weatherWord(v as Numeric or String or Null) as String {
        if (!(v instanceof Number)) {
            return NONE;
        }
        var c = v as Number;
        // Grouped Weather.CONDITION_* values.
        if (c == 0 || c == 23 || c == 40) { return "CLEAR"; }
        if (c == 1 || c == 22 || c == 52) { return "FAIR"; }
        if (c == 2 || c == 20) { return "CLOUDY"; }
        if (c == 6 || c == 12 || c == 28) { return "STORM"; }
        if (c == 4 || c == 16 || c == 17 || c == 43 || c == 46 || c == 48) { return "SNOW"; }
        if (c == 7 || c == 18 || c == 19 || c == 21 || c == 34 || c == 44 || c == 47 || c == 49 || c == 50 || c == 51) { return "SLEET"; }
        if (c == 8 || c == 9 || c == 29 || c == 39) { return "FOG"; }
        if (c == 5 || c == 36) { return "WINDY"; }
        if (c == 14 || c == 31) { return "DRIZZLE"; }
        if (c == 32 || c == 41 || c == 42) { return "STORM"; }
        if (c == 30 || c == 33 || c == 35 || c == 37 || c == 38) { return "HAZE"; }
        if (c == 3 || c == 10 || c == 11 || c == 13 || c == 15 || c == 24 || c == 25 || c == 26 || c == 27 || c == 45) { return "RAIN"; }
        return NONE;
    }

    function temperature(v as Numeric or String or Null) as String {
        if (!(v instanceof Number || v instanceof Float)) {
            return NONE;
        }
        var c = v.toFloat();
        if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
            return (c * 9 / 5 + 32).format("%d") + "°F";
        }
        return c.format("%d") + "°C";
    }

    function kilo(n as Number) as String {
        return n >= 1000 ? (n / 1000.0).format("%.1f") + "K" : n.format("%d");
    }

    // ---- slot readers ----

    // [value, label]
    function left(choice as Number) as [String, String] {
        switch (choice) {
            case L_VO2_BIKE:
                return [num(comp(Complications.COMPLICATION_TYPE_VO2MAX_BIKE), "%d"), "VO2 BK"];
            case L_HEART_RATE:
                return [num(comp(Complications.COMPLICATION_TYPE_HEART_RATE), "%d"), "BPM"];
            case L_BODY_BATTERY:
                return [num(comp(Complications.COMPLICATION_TYPE_BODY_BATTERY), "%d"), "BODY BT"];
            case L_STRESS:
                return [num(comp(Complications.COMPLICATION_TYPE_STRESS), "%d"), "STRESS"];
            case L_TRAINING_STATUS:
                return [statusShort(comp(Complications.COMPLICATION_TYPE_TRAINING_STATUS)), "STATUS"];
            case L_RECOVERY: {
                var m = comp(Complications.COMPLICATION_TYPE_RECOVERY_TIME);
                return [m instanceof Number ? ((m + 59) / 60).format("%d") + "H" : NONE, "RECOV"];
            }
            case L_RACE_5K:
                return [raceTime(comp(Complications.COMPLICATION_TYPE_RACE_PREDICTOR_5K)), "5K"];
            case L_RACE_10K:
                return [raceTime(comp(Complications.COMPLICATION_TYPE_RACE_PREDICTOR_10K)), "10K"];
            case L_RACE_HALF:
                return [raceTime(comp(Complications.COMPLICATION_TYPE_RACE_PREDICTOR_HALF_MARATHON)), "HALF"];
            case L_RACE_FULL:
                return [raceTime(comp(Complications.COMPLICATION_TYPE_RACE_PREDICTOR_MARATHON)), "FULL"];
            default:
                return [num(comp(Complications.COMPLICATION_TYPE_VO2MAX_RUN), "%d"), "VO2 RUN"];
        }
    }

    function right(choice as Number) as [String, String] {
        var info = ActivityMonitor.getInfo();
        switch (choice) {
            case R_WEEK_BIKE:
                return [dist(comp(Complications.COMPLICATION_TYPE_WEEKLY_BIKE_DISTANCE)), "BIKE " + distUnit()];
            case R_WEEK_ACTIVE: {
                var a = info.activeMinutesWeek;
                return [a != null ? a.total.format("%d") : NONE, "ACT/WK"];
            }
            case R_WEEK_INTENSITY:
                return [num(comp(Complications.COMPLICATION_TYPE_INTENSITY_MINUTES), "%d"), "INT/WK"];
            case R_DAY_DISTANCE: {
                var cm = info.distance;
                return [cm != null ? dist(cm / 100.0) : NONE, distUnit() + " DAY"];
            }
            case R_DAY_CALORIES: {
                var k = info.calories;
                return [k != null ? kilo(k) : NONE, "KCAL"];
            }
            case R_DAY_ACTIVE: {
                var a = info.activeMinutesDay;
                return [a != null ? a.total.format("%d") : NONE, "ACT MIN"];
            }
            default:
                return [dist(comp(Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE)), "RUN " + distUnit()];
        }
    }

    function top(choice as Number) as String {
        switch (choice) {
            case T_DATE: {
                var d = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
                return Lang.format("$1$ $2$", [d.day, d.month]).toUpper();
            }
            case T_WEATHER: {
                var t = temperature(comp(Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE));
                var w = weatherWord(comp(Complications.COMPLICATION_TYPE_CURRENT_WEATHER));
                return t.equals(NONE) ? w : w + " " + t;
            }
            case T_TEMPERATURE:
                return temperature(comp(Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE));
            case T_SUNRISE:
                return "RISE " + clockText(comp(Complications.COMPLICATION_TYPE_SUNRISE));
            case T_SUNSET:
                return "SET " + clockText(comp(Complications.COMPLICATION_TYPE_SUNSET));
            case T_CALENDAR: {
                var e = comp(Complications.COMPLICATION_TYPE_CALENDAR_EVENTS);
                return e instanceof String && e.length() > 0 ? "NEXT " + e.toUpper() : "NO EVENT";
            }
            default: {
                var d = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
                return Lang.format("$1$ $2$", [d.day_of_week, d.day]).toUpper();
            }
        }
    }

    function bottom(choice as Number) as String {
        var info = ActivityMonitor.getInfo();
        switch (choice) {
            case B_CALORIES:
                return (info.calories != null ? (info.calories as Number).format("%d") : NONE) + " KCAL";
            case B_DISTANCE:
                return (info.distance != null ? dist((info.distance as Number) / 100.0) : NONE) + " " + distUnit();
            case B_ACTIVE: {
                var a = info.activeMinutesDay;
                return (a != null ? a.total.format("%d") : NONE) + " MIN";
            }
            case B_FLOORS:
                return (info.floorsClimbed != null ? (info.floorsClimbed as Number).format("%d") : NONE) + " FLOORS";
            case B_BATTERY:
                return System.getSystemStats().battery.format("%d") + "%";
            case B_HEART_RATE:
                return num(comp(Complications.COMPLICATION_TYPE_HEART_RATE), "%d") + " BPM";
            case B_RESPIRATION:
                return num(comp(Complications.COMPLICATION_TYPE_RESPIRATION_RATE), "%d") + " BRPM";
            case B_PULSE_OX:
                return num(comp(Complications.COMPLICATION_TYPE_PULSE_OX), "%d") + "% SPO2";
            default: {
                var s = info.steps;
                if (Preview.ON) { s = Preview.STEPS; } // store screenshots (tools/capture.ps1); Preview.ON is false in releases
                return (s != null ? kilo(s as Number) : NONE) + " STEPS";
            }
        }
    }
    // ---- long-press targets: the native Garmin screen behind each slot choice ----

    function leftTarget(choice as Number) as Complications.Type? {
        switch (choice) {
            case L_VO2_BIKE: return Complications.COMPLICATION_TYPE_VO2MAX_BIKE;
            case L_HEART_RATE: return Complications.COMPLICATION_TYPE_HEART_RATE;
            case L_BODY_BATTERY: return Complications.COMPLICATION_TYPE_BODY_BATTERY;
            case L_STRESS: return Complications.COMPLICATION_TYPE_STRESS;
            case L_TRAINING_STATUS: return Complications.COMPLICATION_TYPE_TRAINING_STATUS;
            case L_RECOVERY: return Complications.COMPLICATION_TYPE_RECOVERY_TIME;
            case L_RACE_5K: return Complications.COMPLICATION_TYPE_RACE_PREDICTOR_5K;
            case L_RACE_10K: return Complications.COMPLICATION_TYPE_RACE_PREDICTOR_10K;
            case L_RACE_HALF: return Complications.COMPLICATION_TYPE_RACE_PREDICTOR_HALF_MARATHON;
            case L_RACE_FULL: return Complications.COMPLICATION_TYPE_RACE_PREDICTOR_MARATHON;
            default: return Complications.COMPLICATION_TYPE_VO2MAX_RUN;
        }
    }

    function rightTarget(choice as Number) as Complications.Type? {
        switch (choice) {
            case R_WEEK_BIKE: return Complications.COMPLICATION_TYPE_WEEKLY_BIKE_DISTANCE;
            case R_WEEK_ACTIVE: return Complications.COMPLICATION_TYPE_INTENSITY_MINUTES;
            case R_WEEK_INTENSITY: return Complications.COMPLICATION_TYPE_INTENSITY_MINUTES;
            case R_DAY_DISTANCE: return Complications.COMPLICATION_TYPE_STEPS;
            case R_DAY_CALORIES: return Complications.COMPLICATION_TYPE_CALORIES;
            case R_DAY_ACTIVE: return Complications.COMPLICATION_TYPE_INTENSITY_MINUTES;
            default: return Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE;
        }
    }

    function topTarget(choice as Number) as Complications.Type? {
        switch (choice) {
            case T_DATE: return Complications.COMPLICATION_TYPE_DATE;
            case T_WEATHER: return Complications.COMPLICATION_TYPE_CURRENT_WEATHER;
            case T_TEMPERATURE: return Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE;
            case T_SUNRISE: return Complications.COMPLICATION_TYPE_SUNRISE;
            case T_SUNSET: return Complications.COMPLICATION_TYPE_SUNSET;
            case T_CALENDAR: return Complications.COMPLICATION_TYPE_CALENDAR_EVENTS;
            default: return Complications.COMPLICATION_TYPE_WEEKDAY_MONTHDAY;
        }
    }

    function bottomTarget(choice as Number) as Complications.Type? {
        switch (choice) {
            case B_CALORIES: return Complications.COMPLICATION_TYPE_CALORIES;
            case B_DISTANCE: return Complications.COMPLICATION_TYPE_STEPS;
            case B_ACTIVE: return Complications.COMPLICATION_TYPE_INTENSITY_MINUTES;
            case B_FLOORS: return Complications.COMPLICATION_TYPE_FLOORS_CLIMBED;
            case B_BATTERY: return Complications.COMPLICATION_TYPE_BATTERY;
            case B_HEART_RATE: return Complications.COMPLICATION_TYPE_HEART_RATE;
            case B_RESPIRATION: return Complications.COMPLICATION_TYPE_RESPIRATION_RATE;
            case B_PULSE_OX: return Complications.COMPLICATION_TYPE_PULSE_OX;
            default: return Complications.COMPLICATION_TYPE_STEPS;
        }
    }

    // Opens the native screen; false when the device has no such complication.
    function open(type as Complications.Type?) as Boolean {
        if (type == null || !(Complications has :exitTo)) {
            return false;
        }
        try {
            Complications.exitTo(new Complications.Id(type as Complications.Type));
            return true;
        } catch (e) {
            return false;
        }
    }
}
