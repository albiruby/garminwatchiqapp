import Toybox.Lang;

//! A reusable, allocation-free tween (MotionState): progress 0..1 over a
//! duration from a start time. With reduced motion it completes instantly.
class Tween {

    hidden var _startMs as Number = 0;
    hidden var _durationMs as Number = 0;
    hidden var _easing as Number = Easing.LINEAR;
    hidden var _active as Boolean = false;

    function initialize() {
    }

    function start(nowMs as Number, durationMs as Number, easing as Number) as Void {
        _startMs = nowMs;
        _durationMs = durationMs;
        _easing = easing;
        _active = MotionConfig.smooth() && durationMs > 0;
    }

    //! Eased progress at nowMs; 1.0 when finished or never started.
    function value(nowMs as Number) as Float {
        if (!_active) {
            return 1.0;
        }
        var t = (nowMs - _startMs).toFloat() / _durationMs;
        if (t >= 1.0) {
            _active = false;
            return 1.0;
        }
        return Easing.apply(_easing, t);
    }

    function isRunning(nowMs as Number) as Boolean {
        return _active && (nowMs - _startMs) < _durationMs;
    }
}
