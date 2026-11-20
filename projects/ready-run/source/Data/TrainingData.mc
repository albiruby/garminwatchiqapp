import Toybox.Lang;
import Toybox.ActivityMonitor;

// TrainingData — recent activity / load signals. Real training load (Garmin
// proprietary acute/chronic) is NOT available via public API on this SDK, so
// acute load is derived from recent activity counts when possible and left
// MISSING otherwise. Never fabricated.

class TrainingData {
    var recentCount as MetricValue;      // activities in last ~7 days
    var hasQualityRecently as Boolean;   // a hard session in last 48h
    var loadLevel as String;             // LOW / OPTIMAL / HIGH / NOT AVAILABLE
    var loadColorKey as Number;

    function initialize() {
        recentCount = MetricValue.missing(null);
        hasQualityRecently = false;
        loadLevel = "NOT AVAILABLE";
        loadColorKey = ColorKey.MUTED;
    }
}
