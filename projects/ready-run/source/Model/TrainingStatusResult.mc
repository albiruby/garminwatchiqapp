import Toybox.Lang;

// TrainingStatusResult — output of TrainingStatusEngine.
// This is a READY RUN interpretation, NOT Garmin's proprietary Training Status.

class TrainingStatusResult {
    var status as String;        // PRODUCTIVE / MAINTAINING / RECOVERY / OVERREACHING / UNPRODUCTIVE / DETRAINING / NOT AVAILABLE
    var colorKey as Number;
    var available as Boolean;

    var vo2 as MetricValue;         // VO2 Max (may be missing)
    var vo2Trend as Number;         // -1 down, 0 flat, +1 up, 2 = n/a
    var hrvStatus as String;        // BALANCED / LOW / HIGH / NOT AVAILABLE
    var hrvColorKey as Number;
    var acuteLoad as String;        // LOW / OPTIMAL / HIGH / NOT AVAILABLE
    var acuteColorKey as Number;
    var performance as String;      // IMPROVING / STABLE / DECLINING / NOT AVAILABLE
    var perfColorKey as Number;

    function initialize() {
        status = "NOT AVAILABLE";
        colorKey = ColorKey.MUTED;
        available = false;
        vo2 = MetricValue.missing(null);
        vo2Trend = 2;
        hrvStatus = "NOT AVAILABLE";
        hrvColorKey = ColorKey.MUTED;
        acuteLoad = "NOT AVAILABLE";
        acuteColorKey = ColorKey.MUTED;
        performance = "NOT AVAILABLE";
        perfColorKey = ColorKey.MUTED;
    }
}
