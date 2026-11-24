import Toybox.Lang;

//! Heart-rate derived metrics. Inputs are Garmin-measured values; outputs are
//! RESTORA calculations ("observed HR change"), not proof of recovery.
module HeartRateCalculator {

    //! deltaHR = HR_before - HR_after. Positive means HR was lower afterwards.
    //! null if either reading is missing or out of range.
    function delta(before, after) {
        var b = MetricValidator.validHr(before);
        var a = MetricValidator.validHr(after);
        if (b == null || a == null) {
            return null;
        }
        return b - a;
    }

    //! Rounded mean of valid samples; null if none are valid.
    function average(samples) {
        if (samples == null) {
            return null;
        }
        var sum = 0;
        var n = 0;
        for (var i = 0; i < samples.size(); i++) {
            var v = MetricValidator.validHr(samples[i]);
            if (v != null) {
                sum += v;
                n++;
            }
        }
        return MetricValidator.roundedMean(sum, n);
    }

    function minimum(samples) {
        return extreme(samples, true);
    }

    function maximum(samples) {
        return extreme(samples, false);
    }

    function extreme(samples, wantMin) {
        if (samples == null) {
            return null;
        }
        var best = null;
        for (var i = 0; i < samples.size(); i++) {
            var v = MetricValidator.validHr(samples[i]);
            if (v != null && (best == null || (wantMin ? v < best : v > best))) {
                best = v;
            }
        }
        return best;
    }
}
