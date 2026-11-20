import Toybox.Lang;

// EngineConfig — ALL weights and thresholds in one place. Tunable during
// validation without touching engine logic. Readiness inputs are each scored
// 0..100; weights are re-normalized over the VALID inputs only.

module EngineConfig {
    // ---- Readiness weights (sum need not be 1; re-normalized over valid) ----
    function wSleep() as Float { return 0.30; }
    function wRecovery() as Float { return 0.15; }
    function wEnergy() as Float { return 0.20; }     // Body Battery
    function wCardio() as Float { return 0.20; }     // HR + HRV
    function wLoad() as Float { return 0.15; }       // training-load contribution

    // Minimum number of valid inputs (and min summed weight) to trust a score.
    function readinessMinValidInputs() as Number { return 2; }
    function readinessMinWeight() as Float { return 0.35; }

    // Readiness category cut-points (score is 0..100).
    function catPrime() as Number { return 90; }
    function catHigh() as Number { return 75; }
    function catModerate() as Number { return 60; }
    function catLow() as Number { return 40; }       // below => POOR

    // Body Battery / sleep / stress mapping anchors (raw -> 0..100 readiness).
    // Calibrated so the spec's mock dataset (BB 72, sleep 68, HR 55, stress 35,
    // recovery 24h, HRV balanced, load optimal) lands ~65 MODERATE.
    function bbLow() as Number { return 20; }         // BB <= 20 -> 0
    function bbGood() as Number { return 90; }        // BB >= 90 -> 100
    function sleepPoor() as Number { return 40; }
    function sleepGood() as Number { return 95; }
    function hrGood() as Number { return 48; }        // lower resting/overnight HR = better
    function hrHigh() as Number { return 72; }
    function stressGood() as Number { return 20; }
    function stressHigh() as Number { return 70; }
    function recoveryLow() as Number { return 4; }
    function recoveryUseful() as Number { return 38; } // hours >= 38 -> full recovery credit

    // Form engine.
    function formBalanceGoodGap() as Number { return 12; } // fitness-fatigue gap for GOOD balance
    // Recommendation engine thresholds.
    function recReadyMinReadiness() as Number { return 75; }
    function recCautionMinReadiness() as Number { return 55; }
    function recHighFatigue() as Number { return 80; }
}
