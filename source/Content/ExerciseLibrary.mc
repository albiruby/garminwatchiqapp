import Toybox.Lang;

//! Exercise definitions. Each entry:
//! [name, type, tag, cue, breathingPattern [in, hold, out, pause] or null]
module ExerciseLibrary {

    const F_NAME = 0;
    const F_TYPE = 1;
    const F_TAG = 2;
    const F_CUE = 3;
    const F_PATTERN = 4;

    var _all = null;

    function get(id as String) {
        if (_all == null) {
            _all = build();
        }
        return _all.get(id);
    }

    function build() as Dictionary {
        var B = Models.TYPE_BREATHING;
        var H = Models.TYPE_HOLD;
        var P = Models.TYPE_REPETITION;
        var A = Models.TYPE_ALTERNATING;
        var R = Models.TYPE_REST;
        var T = Models.TYPE_TRANSITION;
        return {
            // BREATHE
            "box" => ["Box Breathing", B, Models.TAG_BREATH, "Follow the circle", [4, 4, 4, 4]],
            "b478" => ["4-7-8 Breathing", B, Models.TAG_BREATH, "Exhale slowly through the mouth", [4, 7, 8, 0]],
            "equal" => ["Equal Breathing", B, Models.TAG_BREATH, "Same length in and out", [4, 0, 4, 0]],
            "extexh" => ["Extended Exhale", B, Models.TAG_BREATH, "Let the exhale be longer", [4, 0, 6, 0]],
            "resonance" => ["Resonance Breathing", B, Models.TAG_BREATH, "Slow, smooth rhythm", [5, 0, 5, 0]],
            "diaphragm" => ["Diaphragmatic Breathing", B, Models.TAG_BREATH, "Hand on belly, breathe low", [4, 0, 6, 0]],
            "slowbreath" => ["Slow Breathing", B, Models.TAG_BREATH, "Breathe gently and slowly", [4, 1, 6, 1]],
            // MIND
            "mindful" => ["Mindful Breathing", R, Models.TAG_MIND, "Rest attention on the breath", null],
            "bodyscan" => ["Body Scan", R, Models.TAG_MIND, "Move attention from feet to head", null],
            "present" => ["Present Moment", R, Models.TAG_MIND, "Notice sounds, then the body", null],
            "quiet" => ["Quiet Sitting", R, Models.TAG_MIND, "Sit comfortably and rest", null],
            // CIRCULATE
            "legs_wall" => ["Legs Up the Wall", H, Models.TAG_ELEV, "Hips near wall, legs resting up", null],
            "legs_chair" => ["Legs on Chair", H, Models.TAG_ELEV, "Lie back, calves on a chair", null],
            "ankle_pumps" => ["Ankle Pumps", P, Models.TAG_ANKLE, "Point and flex your feet", null],
            "ankle_circles" => ["Ankle Circles", A, Models.TAG_ANKLE, "Circle the ankle slowly", null],
            "heel_raises" => ["Heel Raises", P, Models.TAG_MOVE, "Rise onto toes, lower slowly", null],
            "seated_march" => ["Seated Marching", P, Models.TAG_MOVE, "Lift knees gently, alternate", null],
            "knee_bends" => ["Gentle Knee Bends", P, Models.TAG_MOVE, "Slide heel in and out", null],
            // MOBILITY
            "calf_stretch" => ["Calf Stretch", A, Models.TAG_STRETCH, "Back heel down, lean gently", null],
            "hip_mobility" => ["Hip Mobility", A, Models.TAG_STRETCH, "Figure four, ease into it", null],
            "cat_cow" => ["Cat-Cow", P, Models.TAG_STRETCH, "Round, then arch the spine", null],
            "childs_pose" => ["Child's Pose", H, Models.TAG_STRETCH, "Sink hips back, arms long", null],
            "thoracic_rot" => ["Thoracic Rotation", A, Models.TAG_STRETCH, "Open the chest to the side", null],
            "neck_side" => ["Neck Side Stretch", A, Models.TAG_STRETCH, "Ear toward shoulder, soft", null],
            "shoulder_rolls" => ["Shoulder Rolls", P, Models.TAG_STRETCH, "Roll shoulders back slowly", null],
            // REST / TRANSITION
            "relax" => ["Relaxation", R, Models.TAG_REST, "Lie still, soften the body", null],
            "transition" => ["Slow Transition", T, Models.TAG_TRANS, "Exit the position slowly", null]
        };
    }
}
