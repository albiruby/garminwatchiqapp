import Toybox.Lang;
import Toybox.Math;

class PredictionBuffer {
    private var mLastProjectedFinishSec as Float = 0.0f;
    private var mProjectionLocked as Boolean = false;
    private var mStableProjectionTicks as Number = 0;

    private const PROJECTION_LOCK_DEADBAND_SEC as Float = 2.0f;
    private const PROJECTION_BREAKOUT_SEC as Float = 5.0f;
    private const MAX_PROJECTION_SLEW_SEC as Float = 4.0f;

    public function initialize() {
        reset();
    }

    public function reset() as Void {
        mLastProjectedFinishSec = 0.0f;
        mProjectionLocked = false;
        mStableProjectionTicks = 0;
    }

    public function isProjectionLocked() as Boolean {
        return mProjectionLocked;
    }

    public function computeProjectedFinish(
        targetDistM as Float,
        currentDistM as Float,
        elapsedSec as Float,
        instantSpeedMps as Float,
        lapSpeedMps as Float,
        ewmaSpeedMps as Float,
        confidence as Float,
        freezeProjection as Boolean
    ) as Float {
        if (targetDistM <= 0.0f) {
            return 0.0f;
        }

        if (freezeProjection && mLastProjectedFinishSec > 0.0f) {
            return mLastProjectedFinishSec;
        }

        var remainingM = targetDistM - currentDistM;
        if (remainingM <= 0.0f) {
            mLastProjectedFinishSec = elapsedSec;
            return mLastProjectedFinishSec;
        }

        var histSpeedMps = 0.0f;
        if (currentDistM >= 50.0f && elapsedSec >= 10.0f) {
            histSpeedMps = currentDistM / elapsedSec;
        }

        var wInst = 0.20f;
        var wLap = 0.35f;
        var wEwma = 0.30f;
        var wHist = 0.15f;

        var totalWeight = 0.0f;
        var weightedSpeed = 0.0f;

        if (instantSpeedMps >= 1.111f && instantSpeedMps <= 8.333f) {
            weightedSpeed += instantSpeedMps * wInst;
            totalWeight += wInst;
        }
        if (lapSpeedMps >= 1.111f && lapSpeedMps <= 8.333f) {
            weightedSpeed += lapSpeedMps * wLap;
            totalWeight += wLap;
        }
        if (ewmaSpeedMps >= 1.111f && ewmaSpeedMps <= 8.333f) {
            weightedSpeed += ewmaSpeedMps * wEwma;
            totalWeight += wEwma;
        }
        if (histSpeedMps >= 1.111f && histSpeedMps <= 8.333f) {
            var progress = currentDistM / targetDistM;
            var dynHistW = wHist + (0.20f * progress);
            weightedSpeed += histSpeedMps * dynHistW;
            totalWeight += dynHistW;
        }

        if (totalWeight <= 0.0f) {
            return mLastProjectedFinishSec;
        }

        var blendedSpeedMps = weightedSpeed / totalWeight;
        if (blendedSpeedMps <= 0.1f) {
            return mLastProjectedFinishSec;
        }

        var rawProjectedSec = elapsedSec + (remainingM / blendedSpeedMps);

        if (confidence < 0.35f && mLastProjectedFinishSec > 0.0f) {
            return mLastProjectedFinishSec;
        }

        if (mLastProjectedFinishSec <= 0.0f) {
            mLastProjectedFinishSec = rawProjectedSec;
            return mLastProjectedFinishSec;
        }

        if (currentDistM >= 100.0f) {
            var diff = rawProjectedSec - mLastProjectedFinishSec;
            if (diff > MAX_PROJECTION_SLEW_SEC) {
                rawProjectedSec = mLastProjectedFinishSec + MAX_PROJECTION_SLEW_SEC;
            } else if (diff < -MAX_PROJECTION_SLEW_SEC) {
                rawProjectedSec = mLastProjectedFinishSec - MAX_PROJECTION_SLEW_SEC;
            }
        }

        var absDiff = (rawProjectedSec - mLastProjectedFinishSec).abs();
        if (mProjectionLocked) {
            if (absDiff > PROJECTION_BREAKOUT_SEC) {
                mProjectionLocked = false;
                mStableProjectionTicks = 0;
                mLastProjectedFinishSec = rawProjectedSec;
            }
        } else {
            if (absDiff <= PROJECTION_LOCK_DEADBAND_SEC) {
                mStableProjectionTicks += 1;
                if (mStableProjectionTicks >= 3) {
                    mProjectionLocked = true;
                }
            } else {
                mStableProjectionTicks = 0;
                mLastProjectedFinishSec = rawProjectedSec;
            }
        }

        return mLastProjectedFinishSec;
    }
}
