import Toybox.Lang;

// TrainingStatusEngine — interprets training state from available signals.
// This is a READY RUN interpretation, NOT Garmin's proprietary Training Status.
// Uses VO2 trend, acute load, recovery, HRV, performance trend, recent activity.
// Fewer than 2 valid inputs => NOT AVAILABLE.

class TrainingStatusEngine {

    static function evaluate(h as HealthData, t as TrainingData, readiness as ReadinessResult) as TrainingStatusResult {
        var res = new TrainingStatusResult();

        // Gather available signals. VO2/HRV/perf not exposed via public API on
        // this SDK -> left MISSING (trend = 2 = n/a) rather than fabricated.
        var loadKnown = (t.loadLevel != "NOT AVAILABLE");
        var perfTrend = _perfTrendFromReadiness(readiness);
        var hrvKnown = h.hrv.isUsable();
        var recencyKnown = t.recentCount.isUsable();

        // Supporting indicators (display). VO2/HRV/perf show only when known.
        res.vo2 = MetricValue.missing(" ml/kg/min");  // not available via API
        res.vo2Trend = 2;
        if (hrvKnown) {
            var hv = h.hrv.clamped(0, 2) as Number;
            res.hrvStatus = (hv == 2) ? "HIGH" : ((hv == 1) ? "BALANCED" : "LOW");
            res.hrvColorKey = (hv == 2) ? ColorKey.READY : ((hv == 1) ? ColorKey.INFO : ColorKey.WARNING);
        }
        if (loadKnown) {
            res.acuteLoad = t.loadLevel;
            res.acuteColorKey = t.loadColorKey;
        }
        if (perfTrend != 2) {
            res.performance = (perfTrend == 1) ? "IMPROVING" : ((perfTrend == 0) ? "STABLE" : "DECLINING");
            res.perfColorKey = (perfTrend == 1) ? ColorKey.READY : ((perfTrend == 0) ? ColorKey.INFO : ColorKey.WARNING);
        }

        // Count valid decision inputs.
        var validCount = 0;
        if (loadKnown) { validCount = validCount + 1; }
        if (perfTrend != 2) { validCount = validCount + 1; }
        if (hrvKnown) { validCount = validCount + 1; }
        if (recencyKnown) { validCount = validCount + 1; }
        if (readiness.available) { validCount = validCount + 1; }

        if (validCount < 2) {
            res.available = false;
            res.status = "NOT AVAILABLE";
            res.colorKey = ColorKey.MUTED;
            return res;
        }
        res.available = true;

        // Heuristic state machine (conservative, centralized intent):
        // 1) High load + low readiness -> OVERREACHING.
        // 2) Low readiness regardless of load -> RECOVERY.
        // 3) Low recent activity + stable/low load -> DETRAINING.
        // 4) Improving performance + adequate readiness -> PRODUCTIVE.
        // 5) Declining performance with adequate load -> UNPRODUCTIVE.
        // 6) Otherwise -> MAINTAINING.
        var lowReadiness = (readiness.available && readiness.score != null && (readiness.score as Number) < EngineConfig.catModerate());
        var highLoad = (t.loadLevel == "HIGH");
        var improving = (perfTrend == 1);
        var declining = (perfTrend == -1);
        var lowRecency = (t.recentCount.isUsable() && (t.recentCount.value as Number) <= 1);

        if (highLoad && lowReadiness) {
            res.status = "OVERREACHING"; res.colorKey = ColorKey.WARNING;
        } else if (lowReadiness) {
            res.status = "RECOVERY"; res.colorKey = ColorKey.RECOVERY;
        } else if (lowRecency && t.loadLevel == "LOW") {
            res.status = "DETRAINING"; res.colorKey = ColorKey.DANGER;
        } else if (improving && !lowReadiness) {
            res.status = "PRODUCTIVE"; res.colorKey = ColorKey.READY;
        } else if (declining && loadKnown) {
            res.status = "UNPRODUCTIVE"; res.colorKey = ColorKey.MODERATE;
        } else {
            res.status = "MAINTAINING"; res.colorKey = ColorKey.INFO;
        }
        return res;
    }

    // Derive a performance trend proxy from readiness history when the real
    // performance metric is unavailable. 2 = n/a.
    static function _perfTrendFromReadiness(readiness as ReadinessResult) as Number {
        if (!readiness.available) { return 2; }
        // Without a stored performance series we keep it n/a rather than guess.
        return 2;
    }
}
