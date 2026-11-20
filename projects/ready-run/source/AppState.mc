import Toybox.Lang;

// AppState — orchestrates data collection + all four engines ONCE per refresh,
// outside onUpdate. Screens read these cached results; onUpdate only renders.
// A mock flag lets us build the full UI against the mock dataset first.

class AppState {
    var useMock as Boolean;

    var availability as DataAvailability;
    var health as HealthData;
    var training as TrainingData;

    var readiness as ReadinessResult;
    var trainingStatus as TrainingStatusResult;
    var form as FormResult;
    var recommendation as RecommendationResult;

    function initialize() {
        useMock = true;   // V1 bring-up: mock dataset; flip when real data ready.
        availability = new DataAvailability();
        health = new HealthData();
        training = new TrainingData();
        readiness = new ReadinessResult();
        trainingStatus = new TrainingStatusResult();
        form = new FormResult();
        recommendation = new RecommendationResult();
        refresh();
    }

    // Collect data + run engines. Called at startup and on user refresh (START).
    function refresh() as Void {
        if (useMock) {
            availability.refresh();
            health = MockProvider.health();
            training = MockProvider.training();
        } else {
            availability.refresh();
            health = RealProvider.health(availability);
            training = RealProvider.training(availability);
        }

        // Engine pipeline (order matters: readiness feeds status + recommendation).
        readiness = ReadinessEngine.evaluate(health, training);
        trainingStatus = TrainingStatusEngine.evaluate(health, training, readiness);
        form = FormEngine.evaluate(health, training);
        recommendation = RecommendationEngine.evaluate(readiness, trainingStatus, form, training);

        // Persist for trends (best-effort; ignore when unavailable).
        if (readiness.available && readiness.score != null) {
            HistoryData.push(HistoryData.KEY_READINESS, readiness.score as Number);
        }
        if (form.available && form.score != null) {
            HistoryData.push(HistoryData.KEY_FORM, form.score as Number);
        }
    }
}
