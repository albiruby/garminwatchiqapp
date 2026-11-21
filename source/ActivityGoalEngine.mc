import Toybox.Lang;

// Result of comparing one metric with its target.
class Goal {
    var valid as Boolean = false;      // value present
    var hasTarget as Boolean = false;  // target present and > 0
    var value as Number = 0;
    var target as Number = 0;
    var ratio as Float = 0.0;          // value / target, not clamped
    var percent as Number = 0;         // floor(ratio * 100), not clamped
    var remaining as Number = 0;       // max(target - value, 0)
    var state as Number = 0;           // ActivityGoalEngine.STATE_*
    var fromDevice as Boolean = true;  // target from Garmin (vs custom setting)
}

// Pure goal maths. No device access, so every rule is unit tested.
module ActivityGoalEngine {

    const STATE_NONE = -1;       // no value or no target
    const STATE_START = 0;       // < 25 %
    const STATE_BUILDING = 1;    // 25 to 74 %
    const STATE_NEAR = 2;        // 75 to 99 %
    const STATE_COMPLETED = 3;   // 100 %
    const STATE_OVER = 4;        // > 100 %

    function evaluate(value as Number?, target as Number?) as Goal {
        var g = new Goal();
        g.state = STATE_NONE;
        if (value == null || value < 0) {
            return g;
        }
        g.valid = true;
        g.value = value;
        if (target == null || target <= 0) {
            return g;
        }
        g.hasTarget = true;
        g.target = target;
        g.ratio = value.toFloat() / target.toFloat();
        // Long arithmetic: 100 * steps cannot overflow; floor so 99.9 % never reads as 100 %
        g.percent = (value.toLong() * 100l / target.toLong()).toNumber();
        g.remaining = target > value ? target - value : 0;
        g.state = stateFor(g.percent);
        return g;
    }

    function stateFor(percent as Number) as Number {
        if (percent > 100) {
            return STATE_OVER;
        }
        if (percent == 100) {
            return STATE_COMPLETED;
        }
        if (percent >= 75) {
            return STATE_NEAR;
        }
        if (percent >= 25) {
            return STATE_BUILDING;
        }
        return STATE_START;
    }

    // Filled share of the main track, 0..1. Stops at 1: the overshoot has its own lap.
    function trackFraction(g as Goal) as Float {
        if (!g.hasTarget) {
            return 0.0;
        }
        return g.ratio > 1.0 ? 1.0 : g.ratio;
    }

    // Overshoot lap, 0..1 (150 % gives 0.5). Shows at most one extra lap; the
    // percentage text carries anything beyond 200 %.
    function lapFraction(g as Goal) as Float {
        if (!g.hasTarget || g.ratio <= 1.0) {
            return 0.0;
        }
        var over = g.ratio - 1.0;
        return over > 1.0 ? 1.0 : over;
    }

    // Segments that are completely earned: a segment lights only once its full
    // threshold is reached (99 % of 10 segments = 9).
    function filledSegments(g as Goal, count as Number) as Number {
        if (!g.hasTarget) {
            return 0;
        }
        var n = (g.value.toLong() * count / g.target.toLong()).toNumber();
        return n > count ? count : n;
    }

    // Step target: custom setting, else the Garmin goal.
    function stepTarget(s as SettingsManager, deviceGoal as Number?) as Number? {
        return s.stepGoalMode == 1 ? s.stepGoal : deviceGoal;
    }

    function intensityTarget(s as SettingsManager, deviceGoal as Number?) as Number? {
        return s.intensityGoalMode == 1 ? s.intensityGoal : deviceGoal;
    }

    // Distance target in the watch's unit, converted to centimetres; null when off.
    function distanceTargetCm(target as Float, metric as Boolean) as Number? {
        if (target <= 0.0) {
            return null;
        }
        return (target * (metric ? 100000.0 : 160934.4)).toNumber();
    }
}
