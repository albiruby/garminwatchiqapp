import Toybox.Lang;
import Toybox.Math;

// FormEngine — FORM = FITNESS - FATIGUE, normalized to 0..100 (not a blind raw
// subtraction). Fitness and fatigue are each 0..100 proxies derived from recent
// load + recovery. Outputs form score + status, fitness %, fatigue %, trend,
// balance. Missing inputs => NOT AVAILABLE.

class FormEngine {

    static function evaluate(h as HealthData, t as TrainingData) as FormResult {
        var res = new FormResult();

        // Fitness proxy: recent activity frequency + body battery baseline.
        var fitness = _fitness(h, t);
        // Fatigue proxy: high load + high stress + low recovery -> more fatigue.
        var fatigue = _fatigue(h, t);

        if (fitness == null || fatigue == null) {
            res.available = false;
            res.score = null;
            res.status = "NOT AVAILABLE";
            res.colorKey = ColorKey.MUTED;
            return res;
        }

        var f = fitness as Number;
        var g = fatigue as Number;
        res.fitnessPct = f;
        res.fatiguePct = g;

        // Normalize: raw gap (f - g) spans roughly -100..100; map to 0..100.
        var rawGap = f - g;                      // -100..100
        var norm = 50 + (rawGap / 2);            // -100->0, 0->50, 100->100
        var score = norm.toNumber();
        if (score < 0) { score = 0; }
        if (score > 100) { score = 100; }
        res.score = score;
        res.available = true;

        // Status bands.
        if (score >= EngineConfig.catPrime()) { res.status = "PRIME"; res.colorKey = ColorKey.READY; }
        else if (score >= EngineConfig.catHigh()) { res.status = "HIGH"; res.colorKey = ColorKey.READY; }
        else if (score >= EngineConfig.catModerate()) { res.status = "MODERATE"; res.colorKey = ColorKey.MODERATE; }
        else if (score >= EngineConfig.catLow()) { res.status = "LOW"; res.colorKey = ColorKey.WARNING; }
        else { res.status = "POOR"; res.colorKey = ColorKey.DANGER; }

        // Balance: how far apart fitness and fatigue are.
        var gap = f - g;
        if (gap >= EngineConfig.formBalanceGoodGap()) { res.balance = "GOOD"; res.balanceColorKey = ColorKey.READY; }
        else if (gap >= 0) { res.balance = "EVEN"; res.balanceColorKey = ColorKey.INFO; }
        else { res.balance = "POOR"; res.balanceColorKey = ColorKey.WARNING; }

        // Trend from stored form history (HistoryData), n/a when <3 samples.
        _attachTrend(res);
        return res;
    }

    static function _fitness(h as HealthData, t as TrainingData) as Number or Null {
        var base = 50.0;
        if (t.recentCount.isUsable()) {
            var c = (t.recentCount.value as Number);
            // 0 -> 30, 5+ -> 85
            base = 30 + (c < 5 ? c : 5) * 11.0;
        }
        if (h.bodyBattery.isUsable()) {
            base = base + ((h.bodyBattery.value as Number) - 50) * 0.3;
        }
        return _clamp(base).toNumber();
    }

    static function _fatigue(h as HealthData, t as TrainingData) as Number or Null {
        var base = 40.0;
        if (t.loadLevel == "HIGH") { base = base + 35; }
        else if (t.loadLevel == "OPTIMAL") { base = base + 10; }
        else if (t.loadLevel == "LOW") { base = base - 5; }
        if (t.hasQualityRecently) { base = base + 15; }
        if (h.nightStress.isUsable()) {
            base = base + ((h.nightStress.value as Number) - 35) * 0.3;
        }
        if (h.recovery.isUsable()) {
            base = base - ((h.recovery.value as Number) - 12) * 0.6;
        }
        return _clamp(base).toNumber();
    }

    static function _attachTrend(res as FormResult) as Void {
        var tr = HistoryData.trendOf(HistoryData.KEY_FORM);
        if (tr == 2) {
            res.trend = "NOT AVAILABLE";
            res.trendColorKey = ColorKey.MUTED;
        } else if (tr == 1) {
            res.trend = "IMPROVING"; res.trendColorKey = ColorKey.READY;
        } else if (tr == -1) {
            res.trend = "DECLINING"; res.trendColorKey = ColorKey.WARNING;
        } else {
            res.trend = "STABLE"; res.trendColorKey = ColorKey.INFO;
        }
    }

    static function _clamp(x as Float) as Float {
        if (x < 0) { return 0.0; }
        if (x > 100) { return 100.0; }
        return x;
    }
}
