import Toybox.Lang;

// RecommendationResult — output of RecommendationEngine.
// actionState drives the pill: READY / CAUTION / RECOVERY.

class RecommendationResult {
    var category as String;      // session category e.g. QUALITY / EASY / REST / RECOVERY
    var categoryColorKey as Number;
    var detail as String;        // e.g. "Threshold Session", "Easy Run", "Rest Day"
    var actionState as String;   // READY / CAUTION / RECOVERY
    var actionColorKey as Number;
    var available as Boolean;    // false => conservative default

    function initialize() {
        category = "EASY";
        categoryColorKey = ColorKey.MUTED;
        detail = "Easy Run";
        actionState = "CAUTION";
        actionColorKey = ColorKey.WARNING;
        available = false;
    }
}
