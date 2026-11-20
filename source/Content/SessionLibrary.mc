import Toybox.Lang;

//! Session (program) definitions. Each entry:
//! [name, category, [[exerciseId, seconds], ...], description, safety note]
module SessionLibrary {

    const F_NAME = 0;
    const F_CAT = 1;
    const F_STEPS = 2;
    const F_DESC = 3;
    const F_SAFETY = 4;

    const SAFETY_GENERAL = "Stop if you feel pain, dizziness or shortness of breath.";
    const SAFETY_ELEVATION = "Skip with heart, kidney or eye (glaucoma) issues. Not a treatment.";
    const SAFETY_BREATH = "Breathe comfortably. Stop if light-headed.";

    var _all = null;

    function all() as Dictionary {
        if (_all == null) {
            _all = build();
        }
        return _all;
    }

    function get(id) {
        if (id == null) {
            return null;
        }
        if (id.equals("custom_breath")) {
            return custom();
        }
        return all().get(id);
    }

    //! Custom breathing session from the pattern and length in Settings.
    function custom() as Array {
        var p = SettingsRepository.customPattern();
        var name = p[0].toString() + "-" + p[1].toString() + "-" + p[2].toString() + "-" + p[3].toString();
        return ["Custom " + name, Models.CAT_BREATHE, [["custom", SettingsRepository.customMinutes() * 60]],
            "Your pattern (edit in Settings)", SAFETY_BREATH];
    }

    //! Session ids for a module, in display order.
    function idsFor(cat as Number) as Array {
        var order = [
            ["box_5", "b478_4", "extexh_5", "resonance_10", "custom_breath"],
            ["mindful_5", "bodyscan_10", "focus_3", "unwind_8", "gratitude_5"],
            ["leg_reset_5", "leg_relief_10", "desk_break_5", "circulation_8"],
            ["lower_body_8", "spine_6", "neck_shoulder_5", "joint_mobility_6"],
            ["wind_down_5", "bedtime_breath_6", "sleep_relax_10", "night_mobility_8", "legs_rest_10", "evening_restore_20"],
            ["cooldown_5", "lower_reset_10", "easy_day_12", "post_run_15", "long_run_20"]
        ];
        return (cat >= 0 && cat < order.size()) ? order[cat] : [];
    }

    //! Planned total seconds of a session definition.
    function totalSeconds(def) as Number {
        var steps = def[F_STEPS];
        var total = 0;
        for (var i = 0; i < steps.size(); i++) {
            total += steps[i][1];
        }
        return total;
    }

    function build() as Dictionary {
        var BR = Models.CAT_BREATHE;
        var MI = Models.CAT_MIND;
        var CI = Models.CAT_CIRCULATE;
        var MO = Models.CAT_MOBILITY;
        var SL = Models.CAT_SLEEP;
        var RE = Models.CAT_RECOVER;
        return {
            "box_5" => ["Box Breathing", BR, [["box", 300]], "4-4-4-4 structured breathing", SAFETY_BREATH],
            "b478_4" => ["4-7-8", BR, [["b478", 240]], "Relaxing 4-7-8 rhythm", SAFETY_BREATH],
            "extexh_5" => ["Extended Exhale", BR, [["extexh", 300]], "4-6 gentle downshift", SAFETY_BREATH],
            "resonance_10" => ["Resonance", BR, [["resonance", 600]], "Slow 5-5 paced breathing", SAFETY_BREATH],

            "gratitude_5" => ["Gratitude", MI, [["slowbreath", 60], ["gratitude", 240]],
                "Settle, then three good things", SAFETY_GENERAL],
            "unwind_8" => ["Mental Unwind", MI, [["slowbreath", 60], ["tension", 180], ["unwind", 240]],
                "Release the day", SAFETY_GENERAL],
            "mindful_5" => ["Mindful Breathing", MI, [["mindful", 300]], "Breath awareness", SAFETY_GENERAL],
            "bodyscan_10" => ["Body Scan", MI, [["bodyscan", 600]], "Feet to head awareness", SAFETY_GENERAL],
            "focus_3" => ["Focus Reset", MI, [["present", 180]], "Short present-moment reset", SAFETY_GENERAL],

            "leg_reset_5" => ["Leg Reset", CI, [["ankle_pumps", 60], ["ankle_circles", 60], ["legs_chair", 180]],
                "Ankle movement and elevation", SAFETY_ELEVATION],
            "leg_relief_10" => ["Leg Relief", CI, [["diaphragm", 120], ["ankle_pumps", 60], ["ankle_circles", 60],
                ["legs_wall", 300], ["transition", 60]], "Breathing, ankles, legs up the wall", SAFETY_ELEVATION],
            "desk_break_5" => ["Desk Break", CI, [["seated_march", 90], ["ankle_pumps", 60], ["heel_raises", 60],
                ["ankle_circles", 60], ["slowbreath", 30]], "Seated movement for long sitting", SAFETY_GENERAL],

            "circulation_8" => ["Circulation Boost", CI, [["ankle_pumps", 60], ["toe_curls", 60], ["ankle_circles", 60],
                ["heel_raises", 60], ["supine_elev", 240]], "Feet, ankles, elevation", SAFETY_ELEVATION],

            "joint_mobility_6" => ["Joint Mobility", MO, [["ankle_mob", 90], ["shoulder_mob", 90], ["hip_mobility", 90],
                ["thoracic_rot", 90]], "Ankles, hips, shoulders", SAFETY_GENERAL],
            "lower_body_8" => ["Lower Body Mobility", MO, [["calf_stretch", 120], ["hip_mobility", 180],
                ["knee_bends", 60], ["childs_pose", 120]], "Calves, hips and back", SAFETY_GENERAL],
            "spine_6" => ["Spine Mobility", MO, [["cat_cow", 120], ["thoracic_rot", 120], ["childs_pose", 120]],
                "Gentle spinal movement", SAFETY_GENERAL],
            "neck_shoulder_5" => ["Neck & Shoulders", MO, [["shoulder_rolls", 60], ["neck_side", 120], ["slowbreath", 120]],
                "Release upper-body tension", SAFETY_GENERAL],

            "bedtime_breath_6" => ["Bedtime Breathing", SL, [["b478", 180], ["extexh", 180]],
                "Slow breathing for sleep", SAFETY_BREATH],
            "sleep_relax_10" => ["Sleep Relaxation", SL, [["bodyscan", 300], ["relax", 300]],
                "Body scan, then stillness", SAFETY_GENERAL],
            "night_mobility_8" => ["Gentle Night Mobility", SL, [["cat_cow", 90], ["childs_pose", 120], ["knee_chest", 120],
                ["hip_mobility", 120], ["relax", 30]], "Easy stretches before bed", SAFETY_GENERAL],
            "legs_rest_10" => ["Legs Elevated Rest", SL, [["slowbreath", 60], ["legs_wall", 420], ["transition", 60],
                ["relax", 60]], "Legs up, slow breathing", SAFETY_ELEVATION],
            "wind_down_5" => ["5-Min Wind Down", SL, [["extexh", 180], ["relax", 120]], "Calm breathing before bed", SAFETY_BREATH],
            "evening_restore_20" => ["Evening Restore", SL, [["diaphragm", 180], ["cat_cow", 120], ["knee_chest", 120],
                ["legs_wall", 300], ["bodyscan", 300], ["relax", 180]], "Full evening routine", SAFETY_ELEVATION],

            "lower_reset_10" => ["Lower Body Reset", RE, [["calf_stretch", 120], ["quad_stretch", 120], ["hamstring", 120],
                ["hip_flexor", 120], ["knee_chest", 120]], "Calves, quads, hamstrings, hips", SAFETY_GENERAL],
            "easy_day_12" => ["Easy Day Recovery", RE, [["walk_cool", 120], ["cat_cow", 120], ["hip_mobility", 120],
                ["childs_pose", 120], ["legs_wall", 180], ["relax", 60]], "Gentle movement and rest", SAFETY_ELEVATION],
            "long_run_20" => ["Long Run Recovery", RE, [["walk_cool", 180], ["calf_stretch", 120], ["quad_stretch", 120],
                ["hamstring", 120], ["hip_flexor", 120], ["ankle_pumps", 60], ["legs_wall", 300], ["extexh", 180]],
                "Cooldown, stretch, elevate, breathe", SAFETY_ELEVATION],
            "post_run_15" => ["Post-Run Downshift", RE, [["walk_cool", 120], ["calf_stretch", 120], ["quad_stretch", 120],
                ["hamstring", 120], ["hip_flexor", 120], ["legs_chair", 180], ["relax", 120]],
                "Cooldown, stretching, elevation", SAFETY_ELEVATION],
            "cooldown_5" => ["Workout Cooldown", RE, [["walk_cool", 120], ["calf_stretch", 120], ["relax", 60]],
                "Short gradual cooldown", SAFETY_GENERAL]
        };
    }
}
