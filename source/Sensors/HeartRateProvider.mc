import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Lang;

//! Best-effort current heart rate. Returns null when unavailable - never an
//! estimate.
module HeartRateProvider {

    function current() {
        try {
            var info = Activity.getActivityInfo();
            if (info != null && info.currentHeartRate != null) {
                var v = MetricValidator.validHr(info.currentHeartRate);
                if (v != null) {
                    return v;
                }
            }
            if (SensorAvailability.hasHeartRateHistory()) {
                var it = ActivityMonitor.getHeartRateHistory(1, true);
                var sample = (it != null) ? it.next() : null;
                if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                    return MetricValidator.validHr(sample.heartRate);
                }
            }
        } catch (e) {
        }
        return null;
    }
}
