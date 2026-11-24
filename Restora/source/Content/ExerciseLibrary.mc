import Toybox.Lang;

//! Exercise definitions. Each entry:
//! [name, type, tag, cue, breathingPattern [in, hold, out, pause] or null]
//! Names <= 22 chars and cues <= 26 chars so they fit the round HUD without
//! truncation (enforced by testContentFitsHud).
module ExerciseLibrary {

    const F_NAME = 0;
    const F_TYPE = 1;
    const F_TAG = 2;
    const F_CUE = 3;
    const F_PATTERN = 4;

    var _all = null;

    function get(id as String) {
        if (id.equals("custom")) {
            // built on each call so Settings changes apply immediately
            return ["Custom Breathing", Models.TYPE_BREATHING, Models.TAG_BREATH, "Your own rhythm",
                SettingsRepository.customPattern()];
        }
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
            "b478" => ["4-7-8 Breathing", B, Models.TAG_BREATH, "Slow exhale through mouth", [4, 7, 8, 0]],
            "equal" => ["Equal Breathing", B, Models.TAG_BREATH, "Same length in and out", [4, 0, 4, 0]],
            "extexh" => ["Extended Exhale", B, Models.TAG_BREATH, "Let the exhale be longer", [4, 0, 6, 0]],
            "resonance" => ["Resonance Breathing", B, Models.TAG_BREATH, "Slow, smooth rhythm", [5, 0, 5, 0]],
            "diaphragm" => ["Diaphragm Breathing", B, Models.TAG_BREATH, "Hand on belly, breathe low", [4, 0, 6, 0]],
            "slowbreath" => ["Slow Breathing", B, Models.TAG_BREATH, "Breathe gently and slowly", [4, 1, 6, 1]],
            // MIND
            "mindful" => ["Mindful Breathing", R, Models.TAG_MIND, "Rest on the breath", null],
            "bodyscan" => ["Body Scan", R, Models.TAG_MIND, "Attention: feet to head", null],
            "present" => ["Present Moment", R, Models.TAG_MIND, "Sounds, then the body", null],
            "unwind" => ["Mental Unwind", R, Models.TAG_MIND, "Let thoughts pass by", null],
            "tension" => ["Tension Awareness", R, Models.TAG_MIND, "Notice tension, soften", null],
            "gratitude" => ["Gratitude Reflection", R, Models.TAG_MIND, "Recall three good things", null],
            "quiet" => ["Quiet Sitting", R, Models.TAG_MIND, "Sit comfortably and rest", null],
            // CIRCULATE
            "supine_elev" => ["Supine Leg Elevation", H, Models.TAG_ELEV, "Legs on pillows, relax", null],
            "toe_curls" => ["Toe Curls", P, Models.TAG_ANKLE, "Curl, then spread the toes", null],
            "legs_wall" => ["Legs Up the Wall", H, Models.TAG_ELEV, "Hips near wall, legs up", null],
            "legs_chair" => ["Legs on Chair", H, Models.TAG_ELEV, "Calves resting on a chair", null],
            "ankle_pumps" => ["Ankle Pumps", P, Models.TAG_ANKLE, "Point and flex your feet", null],
            "ankle_circles" => ["Ankle Circles", A, Models.TAG_ANKLE, "Circle the ankle slowly", null],
            "heel_raises" => ["Heel Raises", P, Models.TAG_MOVE, "Up on toes, lower slowly", null],
            "seated_march" => ["Seated Marching", P, Models.TAG_MOVE, "Lift knees, alternate", null],
            "knee_bends" => ["Gentle Knee Bends", P, Models.TAG_MOVE, "Slide heel in and out", null],
            // MOBILITY
            "calf_stretch" => ["Calf Stretch", A, Models.TAG_STRETCH, "Heel down, lean gently", null],
            "hip_mobility" => ["Hip Mobility", A, Models.TAG_STRETCH, "Figure four, ease into it", null],
            "cat_cow" => ["Cat-Cow", P, Models.TAG_STRETCH, "Round, then arch the spine", null],
            "childs_pose" => ["Child's Pose", H, Models.TAG_STRETCH, "Sink hips back, arms long", null],
            "thoracic_rot" => ["Thoracic Rotation", A, Models.TAG_STRETCH, "Open the chest to the side", null],
            "neck_side" => ["Neck Side Stretch", A, Models.TAG_STRETCH, "Ear toward shoulder, soft", null],
            "hamstring" => ["Hamstring Stretch", A, Models.TAG_STRETCH, "Hinge at hips, back long", null],
            "quad_stretch" => ["Quad Stretch", A, Models.TAG_STRETCH, "Heel to glute, knees close", null],
            "hip_flexor" => ["Hip Flexor Stretch", A, Models.TAG_STRETCH, "Tuck pelvis, shift forward", null],
            "knee_chest" => ["Knee to Chest", A, Models.TAG_STRETCH, "Hug knee in, back relaxed", null],
            "walk_cool" => ["Walking Cooldown", P, Models.TAG_MOVE, "Easy pace, loose arms", null],
            "shoulder_mob" => ["Shoulder Mobility", P, Models.TAG_STRETCH, "Slow circles, easy range", null],
            "ankle_mob" => ["Ankle Mobility", A, Models.TAG_ANKLE, "Knee over toes, heel down", null],
            "hip_9090" => ["90/90 Hip Rotation", P, Models.TAG_STRETCH, "Knees side to side, slow", null],
            "worlds_greatest" => ["World's Greatest", A, Models.TAG_STRETCH, "Lunge, hand down, reach up", null],
            "hip_circles" => ["Hip Circles", P, Models.TAG_MOVE, "Slow circles, knees soft", null],
            "knee_raise" => ["Standing Knee Raises", P, Models.TAG_MOVE, "Lift knee, stand tall", null],
            "cross_body" => ["Cross-Body Stretch", A, Models.TAG_STRETCH, "Arm across, gentle hold", null],
            "chest_opener" => ["Chest Opener", H, Models.TAG_STRETCH, "Open arms, lift the chest", null],
            "thoracic_ext" => ["Thoracic Extension", P, Models.TAG_STRETCH, "Lean back over the chair", null],
            "open_book" => ["Open Book Rotation", A, Models.TAG_STRETCH, "Top arm opens behind you", null],
            "reclined_butterfly" => ["Reclined Butterfly", H, Models.TAG_REST, "Soles together, knees open", null],
            "supine_twist" => ["Supine Twist", A, Models.TAG_STRETCH, "Knees to one side, breathe", null],
            "supported_rest" => ["Supported Rest", H, Models.TAG_REST, "Pillow under calves, rest", null],
            "shoulder_rolls" => ["Shoulder Rolls", P, Models.TAG_STRETCH, "Roll shoulders back slowly", null],
            // REST / TRANSITION
            "relax" => ["Relaxation", R, Models.TAG_REST, "Lie still, soften the body", null],
            "transition" => ["Slow Transition", T, Models.TAG_TRANS, "Exit the position slowly", null]
        };
    }
}
