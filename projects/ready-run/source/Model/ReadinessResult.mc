import Toybox.Lang;

// ReadinessResult — output of ReadinessEngine.
// score is 0..100 or null when there is not enough valid input (NOT AVAILABLE).

class ReadinessResult {
    var score as Number or Null;
    var category as String;     // PRIME / HIGH / MODERATE / LOW / POOR / NOT AVAILABLE
    var colorKey as Number;     // semantic color key (see Colors.toArgb)
    var available as Boolean;   // false => insufficient data, show "--"

    function initialize() {
        score = null;
        category = "NOT AVAILABLE";
        colorKey = ColorKey.MUTED;
        available = false;
    }
}
