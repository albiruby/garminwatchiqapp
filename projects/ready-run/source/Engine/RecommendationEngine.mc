import Toybox.Lang;

// RecommendationEngine — centralized, conservative ruleset. Never produces a
// hard recommendation from incomplete data. Insufficient data => EASY /
// conservative with action CAUTION. Outputs workout category, detail, and
// action state (READY / CAUTION / RECOVERY).

class RecommendationEngine {

    static function evaluate(readiness as ReadinessResult, ts as TrainingStatusResult, form as FormResult, t as TrainingData) as RecommendationResult {
        var res = new RecommendationResult();

        // Insufficient data -> conservative default.
        if (!readiness.available) {
            res.category = "EASY";
            res.categoryColorKey = ColorKey.INFO;
            res.detail = "Easy Run";
            res.actionState = "CAUTION";
            res.actionColorKey = ColorKey.WARNING;
            res.available = false;
            return res;
        }
        res.available = true;

        var score = readiness.score as Number;
        var highFatigue = (form.available && form.fatiguePct != null && (form.fatiguePct as Number) >= EngineConfig.recHighFatigue());
        var overreaching = (ts.available && ts.status == "OVERREACHING");
        var recovering = (ts.available && ts.status == "RECOVERY");
        var positiveForm = (form.available && form.score != null && (form.score as Number) >= EngineConfig.catModerate());

        // Very low readiness -> REST / RECOVERY.
        if (score < EngineConfig.catLow()) {
            _set(res, "REST", "Rest Day", "RECOVERY", ColorKey.RECOVERY, ColorKey.SECONDARY);
            return res;
        }
        if (recovering || highFatigue || overreaching) {
            _set(res, "RECOVERY", "Recovery Run", "RECOVERY", ColorKey.RECOVERY, ColorKey.RECOVERY);
            return res;
        }

        // Moderate readiness -> EASY / controlled.
        if (score < EngineConfig.recReadyMinReadiness()) {
            if (score >= EngineConfig.recCautionMinReadiness()) {
                _set(res, "EASY", "Easy Run", "CAUTION", ColorKey.INFO, ColorKey.WARNING);
            } else {
                _set(res, "EASY", "Easy + Strides", "CAUTION", ColorKey.INFO, ColorKey.WARNING);
            }
            return res;
        }

        // High readiness + positive form + status allows -> QUALITY.
        if (score >= EngineConfig.recReadyMinReadiness() && positiveForm) {
            var st = ts.available ? ts.status : "MAINTAINING";
            if (st == "PRODUCTIVE" || st == "MAINTAINING") {
                var detail = _qualityDetail(form, t);
                _set(res, "QUALITY", detail, "READY", ColorKey.READY, ColorKey.READY);
                return res;
            }
            // Readiness high but status not ideal -> controlled easy.
            _set(res, "EASY", "Easy Run", "READY", ColorKey.INFO, ColorKey.READY);
            return res;
        }

        // High readiness but form not positive -> controlled easy.
        _set(res, "EASY", "Easy Run", "CAUTION", ColorKey.INFO, ColorKey.WARNING);
        return res;
    }

    static function _qualityDetail(form as FormResult, t as TrainingData) as String {
        // Choose a quality flavor from form/fatigue. Conservative variety.
        if (form.available && form.fatiguePct != null && (form.fatiguePct as Number) >= 60) {
            return "Tempo Run";
        }
        if (form.available && form.fitnessPct != null && (form.fitnessPct as Number) >= 80) {
            return "Threshold Session";
        }
        return "High Intensity Interval";
    }

    static function _set(res as RecommendationResult, cat as String, detail as String, action as String, catKey as Number, actKey as Number) as Void {
        res.category = cat;
        res.categoryColorKey = catKey;
        res.detail = detail;
        res.actionState = action;
        res.actionColorKey = actKey;
    }
}
