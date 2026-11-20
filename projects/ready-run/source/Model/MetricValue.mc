import Toybox.Lang;
import Toybox.Math;

// MetricValue — a single normalized metric with an explicit availability state.
// Never fabricates data: a missing metric keeps state != VALID and value == null.
// The UI renders "--" for anything not VALID; engines skip non-VALID inputs.

module MetricState {
    const VALID = 0;     // fresh, usable value
    const STALE = 1;     // value exists but is old (still usable, flagged)
    const MISSING = 2;   // no data available on this device / SDK
    const INVALID = 3;   // data present but out of plausible range
}

class MetricValue {
    var value as Number or Null;   // raw numeric value, null when unavailable
    var state as Number;           // MetricState.*
    var unit as String or Null;    // e.g. "bpm", "%", "h"
    var stale as Boolean;          // true when state == STALE

    function initialize() {
        value = null;
        state = MetricState.MISSING;
        unit = null;
        stale = false;
    }

    // A usable numeric value.
    static function valid(v as Number, u as String or Null) as MetricValue {
        var m = new MetricValue();
        m.value = v;
        m.state = MetricState.VALID;
        m.unit = u;
        return m;
    }

    // A value flagged as old but still shown.
    static function staleValue(v as Number, u as String or Null) as MetricValue {
        var m = valid(v, u);
        m.state = MetricState.STALE;
        m.stale = true;
        return m;
    }

    // Explicitly no data (device/SDK cannot provide it).
    static function missing(u as String or Null) as MetricValue {
        var m = new MetricValue();
        m.state = MetricState.MISSING;
        m.unit = u;
        return m;
    }

    // Data present but implausible -> treat as unavailable, never display garbage.
    static function invalid(u as String or Null) as MetricValue {
        var m = new MetricValue();
        m.state = MetricState.INVALID;
        m.unit = u;
        return m;
    }

    // True when the value may be used in engine calculations.
    function isUsable() as Boolean {
        return state == MetricState.VALID || state == MetricState.STALE;
    }

    // True when the value should be shown as a real number (not "--").
    function isDisplayable() as Boolean {
        return isUsable() && value != null;
    }

    // Display string, e.g. "72", "55 bpm", "24h". "--" when unavailable.
    function display() as String {
        if (!isDisplayable()) {
            return "--";
        }
        var v = value as Number;
        var s = v.format("%d");
        if (unit != null && (unit as String).length() > 0) {
            return s + (unit as String);
        }
        return s;
    }

    // Numeric value clamped into [lo, hi]; returns null when unusable.
    function clamped(lo as Number, hi as Number) as Number or Null {
        if (!isUsable() || value == null) {
            return null;
        }
        var v = value as Number;
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }
}
