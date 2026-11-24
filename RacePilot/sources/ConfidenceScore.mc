import Toybox.Activity;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;

class ConfidenceScore {
    private var mLastScore as Float = 0.0f;

    public function initialize() {
        mLastScore = 0.0f;
    }

    public function compute(
        runMode as Number,
        gpsAccuracy as Number?,
        speedMps as Float,
        paceVarianceSec as Float,
        cadenceSpm as Number?
    ) as Float {
        var baseScore = 0.75f;
        if (runMode == 1) {
            if (gpsAccuracy == null || gpsAccuracy == Position.QUALITY_NOT_AVAILABLE) {
                baseScore = 0.10f;
            } else if (gpsAccuracy == Position.QUALITY_LAST_KNOWN) {
                baseScore = 0.30f;
            } else if (gpsAccuracy == Position.QUALITY_POOR) {
                baseScore = 0.50f;
            } else if (gpsAccuracy == Position.QUALITY_USABLE) {
                baseScore = 0.78f;
            } else {
                baseScore = 0.96f;
            }
        } else if (runMode == 2) {
            baseScore = 0.90f;
        } else {
            baseScore = 0.85f;
        }

        if (speedMps < 1.111f || speedMps > 8.333f) {
            baseScore *= 0.25f;
        }

        var variancePenalty = 0.0f;
        if (paceVarianceSec > 2.0f) {
            variancePenalty = (paceVarianceSec - 2.0f) * 0.025f;
            if (variancePenalty > 0.45f) {
                variancePenalty = 0.45f;
            }
        }

        var cadenceBonus = 0.0f;
        if (cadenceSpm != null && cadenceSpm >= 140 && cadenceSpm <= 225) {
            cadenceBonus = 0.05f;
        }

        var finalScore = baseScore - variancePenalty + cadenceBonus;
        if (finalScore < 0.0f) { finalScore = 0.0f; }
        if (finalScore > 1.0f) { finalScore = 1.0f; }

        mLastScore = finalScore;
        return mLastScore;
    }

    public function getLastScore() as Float {
        return mLastScore;
    }
}
