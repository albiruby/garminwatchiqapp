import Toybox.Lang;

//! Recovery-practice volume. "Recovery" here means time spent on recovery
//! routines - not a physiological recovery estimate.
module RecoveryCalculator {

    //! Practice minutes on the local day containing `epoch`.
    function dailyMinutes(history as Array, epoch as Number, tzOffset as Number) {
        var d = RecordUtil.dayIndex(epoch, tzOffset);
        var from = RecordUtil.dayStart(d, tzOffset);
        return TrendCalculator.totalMinutes(history, from, from + Models.SECONDS_PER_DAY);
    }

    //! Practice minutes in the 7 local days ending today.
    function weeklyMinutes(history as Array, nowEpoch as Number, tzOffset as Number) {
        var w = CalculationEngine.weekWindow(nowEpoch, tzOffset);
        return TrendCalculator.totalMinutes(history, w[0], w[1]);
    }

    //! Observed HR change for a record as a Metric (null if no readings).
    function observedHrChange(record as Dictionary) as Metric {
        return new Metric("Observed HR change",
            HeartRateCalculator.delta(record.get(Models.K_HR_BEFORE), record.get(Models.K_HR_AFTER)),
            " bpm", MetricSource.CALCULATED);
    }
}
