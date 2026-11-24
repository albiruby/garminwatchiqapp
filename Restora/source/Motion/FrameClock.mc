import Toybox.Lang;
import Toybox.Timer;

//! One repeating timer per screen (MotionScheduler). The interval can change
//! between idle (1 s) and animating (125/250 ms); it only restarts the timer
//! when the interval actually changes.
class FrameClock {

    hidden var _timer;
    hidden var _callback;
    hidden var _intervalMs as Number = 0;

    function initialize(callback) {
        _callback = callback;
    }

    function setInterval(intervalMs as Number) as Void {
        if (_timer != null && intervalMs == _intervalMs) {
            return;
        }
        stop();
        _intervalMs = intervalMs;
        _timer = new Timer.Timer();
        _timer.start(_callback, intervalMs, true);
    }

    function intervalMs() as Number {
        return _intervalMs;
    }

    function stop() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }
}
