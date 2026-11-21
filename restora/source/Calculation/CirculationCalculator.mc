import Toybox.Lang;

//! CIRCULATE metrics: time-based only. Deliberately no "drainage" or
//! "lymphatic efficiency" scores - nothing measured supports them.
module CirculationCalculator {

    function legElevationSeconds(record as Dictionary) {
        return RecordUtil.tagSeconds(record, Models.TAG_ELEV);
    }

    function ankleMovementSeconds(record as Dictionary) {
        return RecordUtil.tagSeconds(record, Models.TAG_ANKLE);
    }

    //! Restorative position time = leg elevation + supported rest.
    function restorativeSeconds(record as Dictionary) {
        return RecordUtil.tagSeconds(record, Models.TAG_ELEV)
            + RecordUtil.tagSeconds(record, Models.TAG_REST);
    }

    //! movement seconds / restorative seconds; null if no restorative time.
    function movementToRestRatio(record as Dictionary) {
        return MetricValidator.safeDivide(
            MovementCalculator.movementSeconds(record), restorativeSeconds(record));
    }

    //! Seconds of CIRCULATE sessions in [from, to).
    function circulationVolume(history as Array, from as Number, to as Number) {
        var total = 0;
        for (var i = 0; i < history.size(); i++) {
            var r = history[i];
            if (RecordUtil.inWindow(r, from, to) && RecordUtil.getNum(r, Models.K_CAT, -1) == Models.CAT_CIRCULATE) {
                total += RecordUtil.getNum(r, Models.K_DUR, 0);
            }
        }
        return total;
    }

    //! Leg elevation seconds across all sessions in [from, to).
    function elevationVolume(history as Array, from as Number, to as Number) {
        return RecordUtil.sumTag(history, Models.TAG_ELEV, from, to);
    }
}
