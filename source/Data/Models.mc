import Toybox.Lang;

//! Shared constants for RESTORA content, sessions and history records.
//! History records are plain Dictionaries with short String keys so they can
//! be persisted with Application.Storage (Symbols are not storable).
module Models {

    // ---- Module / category ids -------------------------------------------
    const CAT_BREATHE = 0;
    const CAT_MIND = 1;
    const CAT_CIRCULATE = 2;
    const CAT_MOBILITY = 3;
    const CAT_SLEEP = 4;
    const CAT_RECOVER = 5;
    const CAT_COUNT = 6;

    // ---- Exercise instruction types (Session Engine) ----------------------
    const TYPE_BREATHING = 0;   // inhale / hold / exhale / pause phases
    const TYPE_HOLD = 1;        // hold a position for a duration
    const TYPE_REPETITION = 2;  // repeat a gentle movement for a duration
    const TYPE_ALTERNATING = 3; // left side then right side
    const TYPE_INTERVAL = 4;    // work / rest intervals
    const TYPE_REST = 5;        // relaxation / meditation period
    const TYPE_TRANSITION = 6;  // move between positions

    // ---- Exercise tags: what the time counts toward in analytics ----------
    const TAG_BREATH = "br";   // breathing practice
    const TAG_MIND = "mi";     // meditation / attention
    const TAG_ELEV = "el";     // leg elevation / restorative positioning
    const TAG_ANKLE = "an";    // ankle movement
    const TAG_MOVE = "mv";     // other gentle movement
    const TAG_STRETCH = "st";  // mobility / stretching
    const TAG_REST = "rs";     // relaxation / supported rest
    const TAG_TRANS = "tr";    // transitions
    const TAG_LEFT = "L";      // left-side seconds (alternating)
    const TAG_RIGHT = "R";     // right-side seconds (alternating)

    // ---- Session record status --------------------------------------------
    const STATUS_COMPLETED = 0;
    const STATUS_CANCELLED = 1;

    // ---- Session record keys ----------------------------------------------
    const K_ID = "id";       // session id (String)
    const K_CAT = "cat";     // category (Number)
    const K_START = "start"; // start, epoch seconds UTC (Number)
    const K_DUR = "dur";     // actual active seconds, excl. countdown/pause (Number)
    const K_PLAN = "plan";   // planned seconds (Number)
    const K_STATUS = "st";   // STATUS_* (Number)
    const K_DONE = "done";   // completed exercises (Number)
    const K_SKIP = "skip";   // skipped exercises (Number)
    const K_TOTAL = "tot";   // total exercises in session (Number)
    const K_CYCLES = "cyc";  // completed breathing cycles (Number)
    const K_TAGS = "t";      // Dictionary tag => seconds
    const K_HR_BEFORE = "hrB"; // optional, Garmin measured
    const K_HR_AFTER = "hrA";  // optional, Garmin measured

    const SECONDS_PER_DAY = 86400;

    function categoryName(cat as Number) as String {
        var names = ["BREATHE", "MIND", "CIRCULATE", "MOBILITY", "SLEEP", "RECOVER"];
        if (cat >= 0 && cat < names.size()) {
            return names[cat];
        }
        return "?";
    }

    function categorySubtitle(cat as Number) as String {
        var names = ["Breathing", "Meditation", "Leg & circulation", "Stretch & move", "Wind down", "Post-activity"];
        if (cat >= 0 && cat < names.size()) {
            return names[cat];
        }
        return "";
    }
}
