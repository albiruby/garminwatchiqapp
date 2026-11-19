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
    const SAFETY_ELEVATION = "Leg elevation is not for everyone (e.g. glaucoma, heart or kidney failure, uncontrolled blood pressure). Ask a clinician if unsure. Not a treatment.";
    const SAFETY_BREATH = "Breathe comfortably. Return to normal breathing if light-headed.";

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
        return all().get(id);
    }

    //! Session ids for a module, in display order.
    function idsFor(cat as Number) as Array {
        var order = [
            ["box_5", "b478_4", "extexh_5", "resonance_10"],
            ["mindful_5", "bodyscan_10", "focus_3"],
            ["leg_reset_5", "leg_relief_10", "desk_break_5"],
            ["lower_body_8", "spine_6", "neck_shoulder_5"],
            ["wind_down_5", "evening_restore_20"],
            ["post_run_15", "cooldown_5"]
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

            "mindful_5" => ["Mindful Breathing", MI, [["mindful", 300]], "Breath awareness", SAFETY_GENERAL],
            "bodyscan_10" => ["Body Scan", MI, [["bodyscan", 600]], "Feet to head awareness", SAFETY_GENERAL],
            "focus_3" => ["Focus Reset", MI, [["present", 180]], "Short present-moment reset", SAFETY_GENERAL],

            "leg_reset_5" => ["Leg Reset", CI, [["ankle_pumps", 60], ["ankle_circles", 60], ["legs_chair", 180]],
                "Ankle movement and elevation", SAFETY_ELEVATION],
            "leg_relief_10" => ["Leg Relief", CI, [["diaphragm", 120], ["ankle_pumps", 60], ["ankle_circles", 60],
                ["legs_wall", 300], ["transition", 60]], "Breathing, ankles, legs up the wall", SAFETY_ELEVATION],
            "desk_break_5" => ["Desk Break", CI, [["seated_march", 90], ["ankle_pumps", 60], ["heel_raises", 60],
                ["ankle_circles", 60], ["slowbreath", 30]], "Seated movement for long sitting", SAFETY_GENERAL],

            "lower_body_8" => ["Lower Body Mobility", MO, [["calf_stretch", 120], ["hip_mobility", 180],
                ["knee_bends", 60], ["childs_pose", 120]], "Calves, hips and back", SAFETY_GENERAL],
            "spine_6" => ["Spine Mobility", MO, [["cat_cow", 120], ["thoracic_rot", 120], ["childs_pose", 120]],
                "Gentle spinal movement", SAFETY_GENERAL],
            "neck_shoulder_5" => ["Neck & Shoulders", MO, [["shoulder_rolls", 60], ["neck_side", 120], ["slowbreath", 120]],
                "Release upper-body tension", SAFETY_GENERAL],

            "wind_down_5" => ["5-Min Wind Down", SL, [["extexh", 180], ["relax", 120]], "Calm breathing before bed", SAFETY_BREATH],
            "evening_restore_20" => ["Evening Restore", SL, [["diaphragm", 180], ["cat_cow", 120], ["hip_mobility", 120],
                ["legs_wall", 300], ["bodyscan", 300], ["relax", 180]], "Full evening routine", SAFETY_ELEVATION],

            "post_run_15" => ["Post-Run Downshift", RE, [["slowbreath", 180], ["calf_stretch", 120], ["hip_mobility", 240],
                ["legs_chair", 240], ["relax", 120]], "Breathing, mobility, elevation", SAFETY_ELEVATION],
            "cooldown_5" => ["Workout Cooldown", RE, [["slowbreath", 120], ["calf_stretch", 120], ["relax", 60]],
                "Short gradual cooldown", SAFETY_GENERAL]
        };
    }
}
