import Toybox.Lang;
import Toybox.Math;

//! Heart rate variability from Garmin beat-to-beat intervals (RR, ms).
//!
//! RMSSD = sqrt(mean of squared differences between successive intervals).
//! The intervals are measured by the watch (Garmin); the RMSSD is a RESTORA
//! calculation. Optical wrist RR is noisy, so intervals are cleaned first and
//! the result is null unless enough clean beats remain. Never estimated.
module HrvCalculator {

    const RR_MIN_MS = 300;       // 200 bpm
    const RR_MAX_MS = 2000;      // 30 bpm
    const MAX_JUMP_PCT = 20;     // successive change above 20 % = artefact
    const MIN_CLEAN_BEATS = 30;  // fewer clean beats -> no value

    //! Intervals that pass the range and successive-change filters.
    function clean(rr) as Array {
        var out = [];
        if (rr == null) {
            return out;
        }
        var prev = 0;               // 0 = no previous beat yet
        for (var i = 0; i < rr.size(); i++) {
            var v = rr[i];
            if (v == null || v < RR_MIN_MS || v > RR_MAX_MS) {
                continue;
            }
            if (prev > 0 && (v - prev).abs() * 100 > prev * MAX_JUMP_PCT) {
                prev = v;          // restart the chain after an artefact
                continue;
            }
            out.add(v);
            prev = v;
        }
        return out;
    }

    //! RMSSD in ms (Number, rounded), or null when there are too few clean beats.
    function rmssd(rr) {
        var c = clean(rr);
        if (c.size() < MIN_CLEAN_BEATS) {
            return null;
        }
        var sum = 0.0;
        for (var i = 1; i < c.size(); i++) {
            var d = (c[i] - c[i - 1]).toFloat();
            sum += d * d;
        }
        return Math.round(Math.sqrt(sum / (c.size() - 1))).toNumber();
    }

    //! Intervals covering the first windowMs of the list (beats are summed).
    function head(rr as Array, windowMs as Number) as Array {
        var out = [];
        var t = 0;
        for (var i = 0; i < rr.size() && t < windowMs; i++) {
            out.add(rr[i]);
            t += rr[i];
        }
        return out;
    }

    //! Intervals covering the last windowMs of the list.
    function tail(rr as Array, windowMs as Number) as Array {
        var start = rr.size();
        var t = 0;
        while (start > 0 && t < windowMs) {
            start--;
            t += rr[start];
        }
        return rr.slice(start, rr.size());
    }
}
