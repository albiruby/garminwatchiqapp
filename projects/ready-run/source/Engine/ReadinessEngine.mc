import Toybox.Lang;
import Toybox.Math;

// ReadinessEngine — weighted 0..100 estimate of training/recovery readiness.
// NOT medically authoritative. Re-normalizes weights over VALID inputs only;
// too few valid inputs => NOT AVAILABLE (score null). Missing data is never
// replaced by 0.

class ReadinessEngine {

    static function evaluate(h as HealthData, t as TrainingData) as ReadinessResult {
        var res = new ReadinessResult();

        // Accumulators.
        var weighted = 0.0;
        var wSum = 0.0;
        var validCount = 0;

        // --- Sleep quality ---
        if (h.sleepQuality.isUsable()) {
            var sq = h.sleepQuality.clamped(0, 100) as Number;
            var sScore = _anchorScore(sq, EngineConfig.sleepPoor(), EngineConfig.sleepGood());
            weighted = weighted + sScore * EngineConfig.wSleep();
            wSum = wSum + EngineConfig.wSleep();
            validCount = validCount + 1;
        }

        // --- Energy (Body Battery) ---
        if (h.bodyBattery.isUsable()) {
            var bb = h.bodyBattery.clamped(0, 100) as Number;
            var eScore = _anchorScore(bb, EngineConfig.bbLow(), EngineConfig.bbGood());
            weighted = weighted + eScore * EngineConfig.wEnergy();
            wSum = wSum + EngineConfig.wEnergy();
            validCount = validCount + 1;
        }

        // --- Recovery time ---
        if (h.recovery.isUsable()) {
            var rh = h.recovery.clamped(0, 72) as Number;
            var rScore = _anchorScore(rh, EngineConfig.recoveryLow(), EngineConfig.recoveryUseful());
            weighted = weighted + rScore * EngineConfig.wRecovery();
            wSum = wSum + EngineConfig.wRecovery();
            validCount = validCount + 1;
        }

        // --- Cardiovascular (HR + HRV), combined sub-weight ---
        var cardioValid = false;
        var cardioScore = 0.0;
        var cardioW = 0.0;
        if (h.overnightHr.isUsable()) {
            var hr = h.overnightHr.clamped(30, 120) as Number;
            // Lower resting HR is better; invert the anchor mapping.
            var hrScore = _invAnchorScore(hr, EngineConfig.hrGood(), EngineConfig.hrHigh());
            cardioScore = cardioScore + hrScore;
            cardioW = cardioW + 1.0;
            cardioValid = true;
            validCount = validCount + 1;
        }
        if (h.hrv.isUsable()) {
            // hrv encodes a status: 0 LOW, 1 BALANCED, 2 HIGH.
            var hv = h.hrv.clamped(0, 2) as Number;
            var hvScore = (hv == 2) ? 90.0 : ((hv == 1) ? 75.0 : 35.0);
            cardioScore = cardioScore + hvScore;
            cardioW = cardioW + 1.0;
            cardioValid = true;
            validCount = validCount + 1;
        }
        if (cardioValid) {
            var cScore = cardioScore / cardioW;
            weighted = weighted + cScore * EngineConfig.wCardio();
            wSum = wSum + EngineConfig.wCardio();
        }

        // --- Training-load contribution (inverted: high recent load -> lower readiness) ---
        if (t.loadLevel != "NOT AVAILABLE") {
            var lScore = 80.0;
            if (t.loadLevel == "HIGH") { lScore = 35.0; }
            else if (t.loadLevel == "OPTIMAL") { lScore = 80.0; }
            else if (t.loadLevel == "LOW") { lScore = 65.0; }
            weighted = weighted + lScore * EngineConfig.wLoad();
            wSum = wSum + EngineConfig.wLoad();
            validCount = validCount + 1;
        }

        // --- Decide availability ---
        if (validCount < EngineConfig.readinessMinValidInputs() || wSum < EngineConfig.readinessMinWeight()) {
            res.available = false;
            res.score = null;
            res.category = "NOT AVAILABLE";
            res.colorKey = ColorKey.MUTED;
            return res;
        }

        var score = (weighted / wSum).toNumber();
        if (score < 0) { score = 0; }
        if (score > 100) { score = 100; }
        res.score = score;
        res.available = true;
        _categorize(res, score);
        return res;
    }

    // Map a raw value to 0..100 given a "poor" and "good" anchor (higher=better).
    static function _anchorScore(v as Number, poor as Number, good as Number) as Float {
        if (good == poor) { return 50.0; }
        var t = (v - poor).toFloat() / (good - poor).toFloat();
        return _clampF(t * 100.0);
    }

    // Inverted anchor (lower raw = better), e.g. heart rate.
    static function _invAnchorScore(v as Number, good as Number, high as Number) as Float {
        if (high == good) { return 50.0; }
        var t = (high - v).toFloat() / (high - good).toFloat();
        return _clampF(t * 100.0);
    }

    static function _clampF(x as Float) as Float {
        if (x < 0) { return 0.0; }
        if (x > 100) { return 100.0; }
        return x;
    }

    static function _categorize(res as ReadinessResult, score as Number) as Void {
        if (score >= EngineConfig.catPrime()) { res.category = "PRIME"; res.colorKey = ColorKey.READY; }
        else if (score >= EngineConfig.catHigh()) { res.category = "HIGH"; res.colorKey = ColorKey.READY; }
        else if (score >= EngineConfig.catModerate()) { res.category = "MODERATE"; res.colorKey = ColorKey.MODERATE; }
        else if (score >= EngineConfig.catLow()) { res.category = "LOW"; res.colorKey = ColorKey.WARNING; }
        else { res.category = "POOR"; res.colorKey = ColorKey.DANGER; }
    }
}
