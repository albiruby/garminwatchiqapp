import Toybox.Lang;

//! Movement / mobility metrics from exercise timers. Repetitions are not
//! inferred from wrist motion: legs and hips are not measured by the watch.
module MovementCalculator {

    function completedExercises(record as Dictionary) {
        return RecordUtil.getNum(record, Models.K_DONE, 0);
    }

    //! Seconds of all movement tags in a record (ankle + gentle + stretch).
    function movementSeconds(record as Dictionary) {
        return RecordUtil.tagSeconds(record, Models.TAG_ANKLE)
            + RecordUtil.tagSeconds(record, Models.TAG_MOVE)
            + RecordUtil.tagSeconds(record, Models.TAG_STRETCH);
    }

    //! Left share in percent of left+right time; 50 = balanced. null if none.
    function leftRightBalance(leftSec, rightSec) {
        if (leftSec == null || rightSec == null) {
            return null;
        }
        return MetricValidator.percent(leftSec, leftSec + rightSec);
    }

    //! Mobility volume (seconds of stretch + gentle movement) in [from, to).
    function mobilityVolume(history as Array, from as Number, to as Number) {
        return RecordUtil.sumTag(history, Models.TAG_STRETCH, from, to)
            + RecordUtil.sumTag(history, Models.TAG_MOVE, from, to);
    }
}
