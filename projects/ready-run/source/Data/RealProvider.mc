import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.SensorHistory;

// RealProvider — reads real device data where the SDK exposes it, and marks
// everything else MISSING. Nothing is fabricated. Body Battery, stress and HR
// come from SensorHistory; sleep/HRV/VO2/recovery are not exposed on this SDK
// and stay MISSING (engines re-normalize around them).

class RealProvider {

    static function health(av as DataAvailability) as HealthData {
        var h = new HealthData();

        if (av.hasBodyBattery) {
            h.bodyBattery = _latest(SensorHistory.getBodyBatteryHistory({:order => SensorHistory.ORDER_NEWEST_FIRST}), "%");
        }
        if (av.hasStress) {
            h.nightStress = _latest(SensorHistory.getStressHistory({:order => SensorHistory.ORDER_NEWEST_FIRST}), "%");
        }
        if (av.hasHeartRate) {
            // Prefer ActivityMonitor HR if present; else SensorHistory.
            h.overnightHr = _latest(SensorHistory.getHeartRateHistory({:order => SensorHistory.ORDER_NEWEST_FIRST}), " bpm");
        }
        // sleepQuality, recovery, hrv remain MISSING on this SDK (guarded above).
        return h;
    }

    static function training(av as DataAvailability) as TrainingData {
        var t = new TrainingData();
        // Recent activity count from ActivityMonitor history.
        try {
            var hist = ActivityMonitor.getHistory();
            if (hist != null) {
                t.recentCount = MetricValue.valid(hist.size(), null);
            }
        } catch (e) {
            t.recentCount = MetricValue.missing(null);
        }
        // Load level is proprietary; left NOT AVAILABLE rather than guessed.
        return t;
    }

    // Pull newest sample from a SensorHistory iterator into a MetricValue.
    static function _latest(hist as SensorHistory.SensorHistoryIterator or Null, unit as String or Null) as MetricValue {
        if (hist == null) {
            return MetricValue.missing(unit);
        }
        try {
            var sample = hist.next();
            if (sample == null) { return MetricValue.missing(unit); }
            var data = sample.data;
            if (data == null) { return MetricValue.missing(unit); }
            var v = (data as Number).toNumber();
            if (v == null) { return MetricValue.invalid(unit); }
            return MetricValue.valid(v, unit);
        } catch (e) {
            return MetricValue.missing(unit);
        }
    }
}
