import Toybox.Lang;

//! Samples an exercise animation definition (ExercisePoseData) at a time:
//! interpolates between keyframe poses with per-segment easing, loops
//! repeating movements, counts repetitions and reports the movement phase.
//! The time comes from the Session Engine (step elapsed ms), so pausing the
//! session freezes the figure and nothing here can end an exercise.
class PoseSampler {

    static const TYPE_STATIC = 0;
    static const TYPE_HOLD = 1;
    static const TYPE_REPETITION = 2;
    static const TYPE_SEQUENCE = 3;
    static const TYPE_BREATH_SYNC = 4;

    var def;
    var pose as Array;        // current pose (Skeleton.POSE_LEN floats)
    var segment as Number = 0;
    var permille as Number = 0;
    var reps as Number = 0;
    var holding as Boolean = false;
    hidden var _cycleMs as Number = 0;

    function initialize(def) {
        self.def = def;
        pose = new [Skeleton.POSE_LEN];
        for (var i = 0; i < pose.size(); i++) {
            pose[i] = 0.0;
        }
        var seq = def[:seq];
        for (var i = 0; i < seq.size(); i++) {
            _cycleMs += seq[i][2];
        }
    }

    function cycleMs() as Number {
        return _cycleMs;
    }

    function type() as Number {
        return def[:type];
    }

    //! Label for the current phase ("COW", "FLEX", "HOLD", ...).
    function label() as String {
        if (holding && def[:holdLabel] != null) {
            return def[:holdLabel];
        }
        return def[:seq][segment][4];
    }

    //! Compute the pose at tMs. reduced = snap to each segment's target pose.
    function sample(tMs as Number, reduced as Boolean) as Void {
        var seq = def[:seq];
        var loop = def[:loop];
        var t = tMs;
        reps = 0;
        holding = false;
        if (_cycleMs <= 0) {
            return;
        }
        if (loop) {
            reps = tMs / _cycleMs;
            t = tMs % _cycleMs;
        } else if (t >= _cycleMs) {
            t = _cycleMs;
            holding = true;
        }
        var acc = 0;
        var last = seq.size() - 1;
        for (var i = 0; i <= last; i++) {
            var dur = seq[i][2];
            if (t < acc + dur || i == last) {
                var local = (dur > 0) ? (t - acc).toFloat() / dur : 1.0;
                if (local > 1.0) {
                    local = 1.0;
                }
                var k = reduced ? 1.0 : Easing.apply(seq[i][3], local);
                var p0 = def[:poses][seq[i][0]];
                var p1 = def[:poses][seq[i][1]];
                for (var q = 0; q < Skeleton.POSE_LEN; q++) {
                    pose[q] = p0[q] + (p1[q] - p0[q]) * k;
                }
                segment = i;
                permille = (local * 1000).toNumber();
                return;
            }
            acc += dur;
        }
    }
}
