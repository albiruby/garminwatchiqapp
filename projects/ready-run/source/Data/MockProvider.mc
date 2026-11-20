import Toybox.Lang;

// MockProvider — supplies the spec's mock dataset so the entire UI + engines
// build and validate before real data. Single source of truth for mock values.
// Selected via AppState.useMock (true for V1 bring-up / dev).

class MockProvider {
    // Build a HealthData matching the approved mock dataset.
    static function health() as HealthData {
        var h = new HealthData();
        h.bodyBattery = MetricValue.valid(72, "%");
        h.sleepQuality = MetricValue.valid(68, "%");
        h.overnightHr = MetricValue.valid(55, " bpm");
        h.nightStress = MetricValue.valid(35, "%");
        h.recovery = MetricValue.valid(24, "h");
        h.hrv = MetricValue.valid(1, null);  // encoded status: 1 = BALANCED
        return h;
    }

    // TrainingData matching the mock (maintaining / optimal load).
    static function training() as TrainingData {
        var t = new TrainingData();
        t.recentCount = MetricValue.valid(4, null);
        t.hasQualityRecently = false;
        t.loadLevel = "OPTIMAL";
        t.loadColorKey = ColorKey.READY;
        return t;
    }
}
