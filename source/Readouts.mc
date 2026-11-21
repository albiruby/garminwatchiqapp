import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Text for the readings every face shares: metric values, goal status, clock, date.
module Readouts {

    const M_DISTANCE = 0;
    const M_CALORIES = 1;
    const M_INTENSITY = 2;
    const M_HEART = 3;
    const M_FLOORS = 4;

    // Metric ids in priority order, filtered by settings and availability.
    // withHeart: false for goal views (heart rate has no target).
    function visible(m as Metrics, s as SettingsManager, withHeart as Boolean) as Array<Number> {
        var out = [] as Array<Number>;
        if (s.showDistance) { out.add(M_DISTANCE); }
        if (s.showCalories) { out.add(M_CALORIES); }
        if (s.showIntensity) { out.add(M_INTENSITY); }
        if (withHeart && s.showHeartRate) { out.add(M_HEART); }
        if (s.showFloors && m.floors != null) { out.add(M_FLOORS); }
        return out;
    }

    // [value, unit label, value colour, goal or null]; "--" when the device has no value.
    function metric(id as Number, m as Metrics, s as SettingsManager) as Array {
        switch (id) {
            case M_DISTANCE:
                if (m.distanceCm == null) {
                    return ["--", FormatUtils.distanceUnit(m.metric), ThemeManager.MUTED, null];
                }
                return [FormatUtils.distance(m.distanceCm, m.metric), FormatUtils.distanceUnit(m.metric), ThemeManager.TEXT,
                        ActivityGoalEngine.evaluate(m.distanceCm,
                            ActivityGoalEngine.distanceTargetCm(s.distanceTarget, m.metric))];
            case M_CALORIES:
                if (m.calories == null) {
                    return ["--", "KCAL", ThemeManager.MUTED, null];
                }
                return [FormatUtils.thousands(m.calories), "KCAL", ThemeManager.TEXT,
                        ActivityGoalEngine.evaluate(m.calories, s.calorieTarget > 0 ? s.calorieTarget : null)];
            case M_INTENSITY:
                if (m.intensityWeek == null) {
                    return ["--", "MIN/WK", ThemeManager.MUTED, null];
                }
                return [m.intensityWeek.toString(), "MIN/WK", ThemeManager.TEXT,
                        ActivityGoalEngine.evaluate(m.intensityWeek,
                            ActivityGoalEngine.intensityTarget(s, m.intensityWeekGoal))];
            case M_HEART:
                if (m.heartRate == null) {
                    return ["--", "BPM", ThemeManager.MUTED, null];
                }
                return [m.heartRate.toString(), "BPM", m.heartRateStale ? ThemeManager.MUTED : ThemeManager.TEXT, null];
            default:
                if (m.floors == null) {
                    return ["--", "FLOORS", ThemeManager.MUTED, null];
                }
                return [m.floors.toString(), "FLOORS", ThemeManager.TEXT, ActivityGoalEngine.evaluate(m.floors, m.floorsGoal)];
        }
    }

    // "74%  2,518 TO GO"; compact amounts ("2.5K") for tight spots.
    function status(g as Goal, compact as Boolean, L as LayoutEngine) as Array {
        if (!g.valid) {
            return [["NO STEP DATA", ThemeManager.MUTED, L.labelFont]];
        }
        if (!g.hasTarget) {
            return [["NO STEP GOAL", ThemeManager.MUTED, L.labelFont]];
        }
        var pct = [FormatUtils.percent(g.percent), ThemeManager.textAccent(g.state), L.textFont];
        var head;
        switch (g.state) {
            case ActivityGoalEngine.STATE_OVER:
                head = ["  +" + amount(g.value - g.target, compact) + " OVER", ThemeManager.lapColor(), L.labelFont];
                break;
            case ActivityGoalEngine.STATE_COMPLETED:
                head = ["  GOAL MET", ThemeManager.textAccent(g.state), L.labelFont];
                break;
            case ActivityGoalEngine.STATE_NEAR:
                head = ["  " + amount(g.remaining, compact) + " TO GO", ThemeManager.TEXT, L.labelFont];
                break;
            default:
                head = ["  " + amount(g.remaining, compact) + " TO GO", ThemeManager.MUTED, L.labelFont];
                break;
        }
        return [pct, head];
    }

    // Status that fits at (x, y): full, then compact amounts, then the percentage alone.
    function fittedStatus(c as Canvas, g as Goal, x as Number, y as Number, justify as Number) as Array {
        var runs = status(g, false, c.L);
        if (!c.fits(runs, x, y, justify)) {
            runs = status(g, true, c.L);
        }
        if (runs.size() > 1 && !c.fits(runs, x, y, justify)) {
            runs = [runs[0]];
        }
        return runs;
    }

    function amount(n as Number, compact as Boolean) as String {
        return compact ? FormatUtils.compact(n) : FormatUtils.thousands(n);
    }

    // [hours, minutes, "AM"/"PM" or ""]
    function clock(hour as Number, min as Number, s as SettingsManager) as Array<String> {
        var t = FormatUtils.clock(hour, min, twelveHour(s));
        var hm = t[0];
        var colon = hm.find(":");
        return [hm.substring(0, colon), hm.substring(colon + 1, hm.length()), t[1]];
    }

    function twelveHour(s as SettingsManager) as Boolean {
        if (s.clockFormat == SettingsManager.CLOCK_12) {
            return true;
        }
        if (s.clockFormat == SettingsManager.CLOCK_24) {
            return false;
        }
        if (Preview.ON) {
            return Preview.TWELVE;
        }
        return !System.getDeviceSettings().is24Hour;
    }

    // "SAT 21 NOV" or "SAT 21"
    function date(withMonth as Boolean) as String {
        if (Preview.ON) {
            return withMonth ? Preview.DATE : Preview.DATE.substring(0, 6);
        }
        var d = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var str = (d.day_of_week as String).toUpper() + " " + d.day.format("%d");
        return withMonth ? str + " " + (d.month as String).toUpper() : str;
    }

    // Date line that fits at (x, y), with the AM/PM marker appended when given.
    function fittedDate(c as Canvas, x as Number, y as Number, justify as Number, marker as String) as String {
        var suffix = marker.equals("") ? "" : " " + marker;
        var str = date(true) + suffix;
        if (!c.fits([[str, 0, c.L.textFont]], x, y, justify)) {
            str = date(false) + suffix;
        }
        return str;
    }
}
