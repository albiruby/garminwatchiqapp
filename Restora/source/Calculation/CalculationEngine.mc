import Toybox.Lang;

//! Facade over the calculators. Pure: takes history/records in, returns
//! Dictionaries of Metric objects out. No Storage, UI or sensor access, so
//! everything here is unit-testable.
module CalculationEngine {

    //! [from, to) epoch window for the 7 local days ending today.
    function weekWindow(nowEpoch as Number, tzOffset as Number) as Array {
        var today = RecordUtil.dayIndex(nowEpoch, tzOffset);
        return [RecordUtil.dayStart(today - 6, tzOffset), RecordUtil.dayStart(today + 1, tzOffset)];
    }

    //! Metrics for one finished session record.
    function summarizeSession(record as Dictionary) as Dictionary {
        var calc = MetricSource.CALCULATED;
        var m = {};
        m.put("duration", new Metric("Duration", RecordUtil.getNum(record, Models.K_DUR, null), " s", calc));
        m.put("completion", new Metric("Completion", ConsistencyCalculator.sessionCompletion(record), "%", calc));
        m.put("skipped", new Metric("Skipped", RecordUtil.getNum(record, Models.K_SKIP, null), "", calc));

        var hrB = MetricValidator.validHr(record.get(Models.K_HR_BEFORE));
        var hrA = MetricValidator.validHr(record.get(Models.K_HR_AFTER));
        m.put("hrBefore", new Metric("HR before", hrB, " bpm", MetricSource.MEASURED));
        m.put("hrAfter", new Metric("HR after", hrA, " bpm", MetricSource.MEASURED));
        m.put("hrChange", RecoveryCalculator.observedHrChange(record));

        var breath = RecordUtil.tagSeconds(record, Models.TAG_BREATH);
        m.put("breathSec", new Metric("Breathing", breath, " s", calc));
        m.put("cycles", new Metric("Breath cycles", (breath > 0) ? RecordUtil.getNum(record, Models.K_CYCLES, null) : null, "", calc));

        m.put("elevation", new Metric("Leg elevation", CirculationCalculator.legElevationSeconds(record), " s", calc));
        m.put("ankle", new Metric("Ankle movement", CirculationCalculator.ankleMovementSeconds(record), " s", calc));
        m.put("moveRest", new Metric("Move:rest", CirculationCalculator.movementToRestRatio(record), "", calc));
        m.put("lrBalance", new Metric("Left share", MovementCalculator.leftRightBalance(
            RecordUtil.tagSeconds(record, Models.TAG_LEFT), RecordUtil.tagSeconds(record, Models.TAG_RIGHT)), "%", calc));
        return m;
    }

    //! Weekly dashboard metrics for the 7 local days ending at nowEpoch.
    function summarizeWeek(history as Array, nowEpoch as Number, tzOffset as Number) as Dictionary {
        var calc = MetricSource.CALCULATED;
        var w = weekWindow(nowEpoch, tzOffset);
        var from = w[0];
        var to = w[1];
        var count = TrendCalculator.sessionCount(history, from, to);
        var m = {};
        m.put("sessions", new Metric("Sessions", count, "", calc));
        m.put("minutes", new Metric("Minutes", TrendCalculator.totalMinutes(history, from, to), "", calc));
        m.put("categories", new Metric("Modules used", ConsistencyCalculator.categoriesUsed(history, from, to), "", calc));
        m.put("streak", new Metric("Day streak", ConsistencyCalculator.dailyStreak(history, nowEpoch, tzOffset), "", calc));
        m.put("completionRate", new Metric("Completed", ConsistencyCalculator.completionRate(history, from, to), "%", calc));
        m.put("avgSession", new Metric("Avg session", TrendCalculator.averageSessionSeconds(history, from, to), " s", calc));
        m.put("moduleShare", new Metric("Module share", ConsistencyCalculator.moduleShare(history, from, to), "%", calc));
        m.put("circulation", new Metric("Circulation", RecordUtil.toMinutes(CirculationCalculator.circulationVolume(history, from, to)), " min", calc));
        m.put("elevation", new Metric("Leg elevation", RecordUtil.toMinutes(CirculationCalculator.elevationVolume(history, from, to)), " min", calc));
        m.put("windDown", new Metric("Wind-down", RecordUtil.toMinutes(SleepCalculator.windDownSeconds(history, from, to)), " min", calc));
        m.put("mostUsed", new Metric("Most used", TrendCalculator.mostUsedSession(history, from, to), "", calc));
        m.put("hrBaseline", new Metric("Pre-session HR (14d)", TrendCalculator.hrBeforeBaseline(history, nowEpoch), " bpm", calc));
        return m;
    }
}
