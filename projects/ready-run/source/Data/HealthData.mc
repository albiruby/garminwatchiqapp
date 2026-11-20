import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.Time;

// HealthData — normalized health metrics (all as MetricValue with explicit
// state). Reads real SensorHistory where available; otherwise leaves metrics
// MISSING. Engines consume this and never touch raw Garmin APIs.

class HealthData {
    var bodyBattery as MetricValue;
    var sleepQuality as MetricValue;
    var overnightHr as MetricValue;
    var nightStress as MetricValue;
    var recovery as MetricValue;
    var hrv as MetricValue;

    function initialize() {
        bodyBattery = MetricValue.missing("%");
        sleepQuality = MetricValue.missing("%");
        overnightHr = MetricValue.missing(" bpm");
        nightStress = MetricValue.missing("%");
        recovery = MetricValue.missing("h");
        hrv = MetricValue.missing(null);
    }

    // Pull the most recent sample from a SensorHistory iterator.
    // Returns a valid MetricValue or missing when no data.
    static function latestFromHistory(hist as SensorHistory.SensorHistoryIterator or Null, unit as String or Null) as MetricValue {
        // hist may be a SensorHistory iterator or null.
        if (hist == null) {
            return MetricValue.missing(unit);
        }
        try {
            var sample = hist.next();
            if (sample == null) {
                return MetricValue.missing(unit);
            }
            var data = sample.data;
            if (data == null) {
                return MetricValue.missing(unit);
            }
            var v = (data as Number).toNumber();
            if (v == null) {
                return MetricValue.invalid(unit);
            }
            return MetricValue.valid(v, unit);
        } catch (e) {
            return MetricValue.missing(unit);
        }
    }
}
