import Toybox.Lang;
import Toybox.Math;

//! Breathing metrics computed from the configured pattern and the session
//! timer / state machine. No respiration sensor is needed.
module BreathingCalculator {

    //! Seconds per cycle for pattern [inhale, hold, exhale, pause]; null if <= 0.
    function cycleLength(pattern) {
        if (pattern == null || pattern.size() < 4) {
            return null;
        }
        var total = pattern[0] + pattern[1] + pattern[2] + pattern[3];
        return (total > 0) ? total : null;
    }

    //! Whole cycles that fit in durationSec. 300 s at 12 s/cycle = 25.
    function plannedCycles(durationSec, cycleLenSec) {
        if (durationSec == null || cycleLenSec == null || cycleLenSec <= 0 || durationSec < 0) {
            return null;
        }
        return durationSec / cycleLenSec;
    }

    //! Exhale / inhale ratio, e.g. 4-6 -> 1.5. null if inhale is 0.
    function exhaleInhaleRatio(pattern) {
        if (pattern == null || pattern.size() < 4) {
            return null;
        }
        return MetricValidator.safeDivide(pattern[2], pattern[0]);
    }

    //! Phase index (0 inhale, 1 hold, 2 exhale, 3 pause) for an elapsed time
    //! inside a breathing exercise. Zero-length phases are skipped.
    function phaseAt(pattern, elapsedMs) {
        var len = cycleLength(pattern);
        if (len == null) {
            return null;
        }
        var t = elapsedMs % (len * 1000);
        var acc = 0;
        for (var i = 0; i < 4; i++) {
            acc += pattern[i] * 1000;
            if (t < acc) {
                return i;
            }
        }
        return 3;
    }

    //! Milliseconds remaining in the current phase.
    function phaseRemainingMs(pattern, elapsedMs) {
        var len = cycleLength(pattern);
        if (len == null) {
            return null;
        }
        var t = elapsedMs % (len * 1000);
        var acc = 0;
        for (var i = 0; i < 4; i++) {
            acc += pattern[i] * 1000;
            if (t < acc) {
                return acc - t;
            }
        }
        return 0;
    }

    //! Completed cycles for an elapsed time (ms) in a breathing exercise.
    function completedCycles(pattern, elapsedMs) {
        var len = cycleLength(pattern);
        if (len == null || elapsedMs == null || elapsedMs < 0) {
            return null;
        }
        return elapsedMs / (len * 1000);
    }

    //! Mean of consecutive differences of cycle timestamps (ms); needs >= 2.
    function averageCycleMs(timestampsMs) {
        if (timestampsMs == null || timestampsMs.size() < 2) {
            return null;
        }
        var n = timestampsMs.size() - 1;
        var span = timestampsMs[n] - timestampsMs[0];
        return MetricValidator.roundedMean(span, n);
    }

    //! Standard deviation (ms, rounded) of cycle durations; lower = steadier.
    //! Needs >= 3 timestamps (2 cycles).
    function cycleStdDevMs(timestampsMs) {
        if (timestampsMs == null || timestampsMs.size() < 3) {
            return null;
        }
        var n = timestampsMs.size() - 1;
        var mean = (timestampsMs[n] - timestampsMs[0]).toFloat() / n;
        var acc = 0.0;
        for (var i = 1; i <= n; i++) {
            var d = (timestampsMs[i] - timestampsMs[i - 1]).toFloat() - mean;
            acc += d * d;
        }
        return Math.round(Math.sqrt(acc / n)).toNumber();
    }
}
