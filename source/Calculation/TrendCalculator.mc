import Toybox.Lang;

//! Volume, frequency and personal-baseline trends over session history.
module TrendCalculator {

    const BASELINE_DAYS = 14;
    const BASELINE_MIN_POINTS = 5;

    function sessionCount(history as Array, from as Number, to as Number) as Number {
        var n = 0;
        for (var i = 0; i < history.size(); i++) {
            if (RecordUtil.inWindow(history[i], from, to)) {
                n++;
            }
        }
        return n;
    }

    //! Total practice minutes (rounded) in [from, to).
    function totalMinutes(history as Array, from as Number, to as Number) {
        return RecordUtil.toMinutes(RecordUtil.sumDuration(history, from, to));
    }

    //! Average actual session duration in seconds; null if no sessions.
    function averageSessionSeconds(history as Array, from as Number, to as Number) {
        return MetricValidator.roundedMean(
            RecordUtil.sumDuration(history, from, to), sessionCount(history, from, to));
    }

    //! Sessions per week over a span of `days` days.
    function sessionsPerWeek(count, days) {
        if (count == null) {
            return null;
        }
        return MetricValidator.safeDivide(count * 7, days);
    }

    //! Most frequently used session id in [from, to); ties keep the one
    //! reached first in history order. null if none.
    function mostUsedSession(history as Array, from as Number, to as Number) {
        var counts = {};
        var bestId = null;
        var bestCount = 0;
        for (var i = 0; i < history.size(); i++) {
            var r = history[i];
            var id = r.get(Models.K_ID);
            if (id != null && RecordUtil.inWindow(r, from, to)) {
                var c = counts.get(id);
                c = (c == null) ? 1 : c + 1;
                counts.put(id, c);
                if (c > bestCount) {
                    bestCount = c;
                    bestId = id;
                }
            }
        }
        return bestId;
    }

    //! Rounded mean of values, or null if fewer than minPoints non-null values.
    function baseline(values as Array, minPoints as Number) {
        var sum = 0;
        var n = 0;
        for (var i = 0; i < values.size(); i++) {
            if (values[i] != null) {
                sum += values[i];
                n++;
            }
        }
        if (n < minPoints) {
            return null;
        }
        return MetricValidator.roundedMean(sum, n);
    }

    //! Personal baseline of pre-session HR over the last 14 days.
    function hrBeforeBaseline(history as Array, nowEpoch as Number) {
        var from = nowEpoch - BASELINE_DAYS * Models.SECONDS_PER_DAY;
        var values = [];
        for (var i = 0; i < history.size(); i++) {
            var r = history[i];
            if (RecordUtil.inWindow(r, from, nowEpoch + 1)) {
                var hr = MetricValidator.validHr(r.get(Models.K_HR_BEFORE));
                if (hr != null) {
                    values.add(hr);
                }
            }
        }
        return baseline(values, BASELINE_MIN_POINTS);
    }

    //! current - baseline, or null if either is missing.
    function vsBaseline(current, base) {
        if (current == null || base == null) {
            return null;
        }
        return current - base;
    }
}
