import Toybox.Lang;

//! Routine consistency metrics. All are ratios of what the user did, never a
//! health or recovery score.
module ConsistencyCalculator {

    //! Consecutive local days with >= 1 session (any status), ending today.
    //! If there is no session yet today the streak still counts up to
    //! yesterday, so it does not reset in the morning.
    function dailyStreak(history as Array, nowEpoch as Number, tzOffset as Number) as Number {
        var days = {};
        for (var i = 0; i < history.size(); i++) {
            var s = history[i].get(Models.K_START);
            if (s != null) {
                days.put(RecordUtil.dayIndex(s, tzOffset), true);
            }
        }
        var d = RecordUtil.dayIndex(nowEpoch, tzOffset);
        if (!days.hasKey(d)) {
            d -= 1;
        }
        var streak = 0;
        while (days.hasKey(d)) {
            streak++;
            d--;
        }
        return streak;
    }

    //! % of sessions in [from, to) that were completed (not cancelled).
    function completionRate(history as Array, from as Number, to as Number) {
        var total = 0;
        var done = 0;
        for (var i = 0; i < history.size(); i++) {
            var r = history[i];
            if (RecordUtil.inWindow(r, from, to)) {
                total++;
                if (RecordUtil.isCompleted(r)) {
                    done++;
                }
            }
        }
        return MetricValidator.percent(done, total);
    }

    //! Session completion = completed exercises / total exercises * 100.
    function sessionCompletion(record as Dictionary) {
        return MetricValidator.percent(
            RecordUtil.getNum(record, Models.K_DONE, null),
            RecordUtil.getNum(record, Models.K_TOTAL, null));
    }

    //! Routine consistency = completed planned sessions / planned * 100.
    function routineConsistency(completedPlanned, planned) {
        return MetricValidator.percent(completedPlanned, planned);
    }

    //! Seconds per module in [from, to): Array of CAT_COUNT Numbers.
    function moduleSeconds(history as Array, from as Number, to as Number) as Array {
        var secs = new [Models.CAT_COUNT];
        for (var c = 0; c < Models.CAT_COUNT; c++) {
            secs[c] = 0;
        }
        for (var i = 0; i < history.size(); i++) {
            var r = history[i];
            var cat = RecordUtil.getNum(r, Models.K_CAT, -1);
            if (RecordUtil.inWindow(r, from, to) && cat >= 0 && cat < Models.CAT_COUNT) {
                secs[cat] += RecordUtil.getNum(r, Models.K_DUR, 0);
            }
        }
        return secs;
    }

    //! Module share % = module minutes / total minutes * 100, per module.
    //! Each entry is null when there is no practice time at all.
    function moduleShare(history as Array, from as Number, to as Number) as Array {
        var secs = moduleSeconds(history, from, to);
        var total = 0;
        for (var c = 0; c < secs.size(); c++) {
            total += secs[c];
        }
        var share = new [secs.size()];
        for (var c = 0; c < secs.size(); c++) {
            share[c] = MetricValidator.percent(secs[c], total);
        }
        return share;
    }

    //! Number of distinct modules practised in [from, to).
    function categoriesUsed(history as Array, from as Number, to as Number) as Number {
        var secs = moduleSeconds(history, from, to);
        var n = 0;
        for (var c = 0; c < secs.size(); c++) {
            if (secs[c] > 0) {
                n++;
            }
        }
        return n;
    }
}
