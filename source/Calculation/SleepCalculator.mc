import Toybox.Lang;

//! Wind-down metrics. These describe routine habits only; they make no claim
//! about sleep quality.
module SleepCalculator {

    const EVENING_START_HOUR = 18;

    function isEvening(record as Dictionary, tzOffset as Number) as Boolean {
        var s = record.get(Models.K_START);
        if (s == null) {
            return false;
        }
        return RecordUtil.localHour(s, tzOffset) >= EVENING_START_HOUR;
    }

    //! Seconds of SLEEP-module sessions in [from, to).
    function windDownSeconds(history as Array, from as Number, to as Number) {
        var total = 0;
        for (var i = 0; i < history.size(); i++) {
            var r = history[i];
            if (RecordUtil.inWindow(r, from, to) && RecordUtil.getNum(r, Models.K_CAT, -1) == Models.CAT_SLEEP) {
                total += RecordUtil.getNum(r, Models.K_DUR, 0);
            }
        }
        return total;
    }

    //! Number of sessions (any module) started in the evening in [from, to).
    function eveningSessionCount(history as Array, from as Number, to as Number, tzOffset as Number) {
        var n = 0;
        for (var i = 0; i < history.size(); i++) {
            var r = history[i];
            if (RecordUtil.inWindow(r, from, to) && isEvening(r, tzOffset)) {
                n++;
            }
        }
        return n;
    }

    //! % of the last `days` local days (ending today) with >= 1 evening session.
    function eveningConsistency(history as Array, nowEpoch as Number, tzOffset as Number, days as Number) {
        if (days <= 0) {
            return null;
        }
        var today = RecordUtil.dayIndex(nowEpoch, tzOffset);
        var first = today - days + 1;
        var seen = {};
        for (var i = 0; i < history.size(); i++) {
            var r = history[i];
            var s = r.get(Models.K_START);
            if (s != null && isEvening(r, tzOffset)) {
                var d = RecordUtil.dayIndex(s, tzOffset);
                if (d >= first && d <= today) {
                    seen.put(d, true);
                }
            }
        }
        return MetricValidator.percent(seen.size(), days);
    }
}
