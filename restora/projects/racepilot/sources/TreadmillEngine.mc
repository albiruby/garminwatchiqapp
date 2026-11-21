import Toybox.Lang;
import Toybox.Math;

class TreadmillEngine {
    private var mCalibFactor as Float = 1.00f;
    private var mValidSampleCount as Number = 0;
    private var mLastCalibDistM as Float = 0.0f;
    private var mLastElapsedSec as Float = 0.0f;
    private var mLapStartDistM as Float = 0.0f;
    private var mLapStartTimeSec as Float = 0.0f;
    private var mLastValidSpeedMps as Float = 0.0f;
    private var mWasRejected as Boolean = false;

    private const WARMUP_DIST_M as Float = 200.0f;
    private const WARMUP_TIME_SEC as Float = 30.0f;
    private const WARMUP_MIN_SAMPLES as Number = 10;
    private const BLEND_END_DIST_M as Float = 500.0f;
    private const MIN_LAP_DIST_M as Float = 50.0f;

    private const MIN_SANITY_SPEED_MPS as Float = 1.111f;
    private const MAX_SANITY_SPEED_MPS as Float = 8.333f;
    private const MAX_DELTA_JUMP_MPS as Float = 5.0f;

    public function initialize(calibSettingX100 as Number) {
        setCalibration(calibSettingX100);
        reset();
    }

    public function reset() as Void {
        mValidSampleCount = 0;
        mLastCalibDistM = 0.0f;
        mLastElapsedSec = 0.0f;
        mLapStartDistM = 0.0f;
        mLapStartTimeSec = 0.0f;
        mLastValidSpeedMps = 0.0f;
        mWasRejected = false;
    }

    public function setCalibration(calibSettingX100 as Number) as Void {
        if (calibSettingX100 >= 50 && calibSettingX100 <= 150) {
            mCalibFactor = calibSettingX100.toFloat() / 100.0f;
        } else {
            mCalibFactor = 1.00f;
        }
    }

    public function getCalibrationFactor() as Float {
        return mCalibFactor;
    }

    public function getCalibratedDistanceM(rawDistM as Float) as Float {
        if (rawDistM <= 0.0f) {
            return 0.0f;
        }
        return rawDistM * mCalibFactor;
    }

    public function wasLastSampleRejected() as Boolean {
        return mWasRejected;
    }

    public function onHardwareLap(rawDistM as Float, elapsedSec as Float) as Void {
        mLapStartDistM = getCalibratedDistanceM(rawDistM);
        mLapStartTimeSec = elapsedSec;
    }

    public function update(rawNativeSpeedMps as Float, rawDistM as Float, elapsedSec as Float) as Float {
        mWasRejected = false;

        var calibSpeedMps = rawNativeSpeedMps * mCalibFactor;
        var calibDistM = getCalibratedDistanceM(rawDistM);

        // 1. Distance delta validation
        var dt = elapsedSec - mLastElapsedSec;
        var dDist = calibDistM - mLastCalibDistM;
        var deltaSpeedMps = 0.0f;
        if (dt >= 0.5f && dDist >= 0.0f) {
            deltaSpeedMps = dDist / dt;
            if (deltaSpeedMps > (calibSpeedMps + MAX_DELTA_JUMP_MPS) || deltaSpeedMps > MAX_SANITY_SPEED_MPS) {
                mWasRejected = true;
                deltaSpeedMps = calibSpeedMps;
            }
        }
        if (calibDistM > mLastCalibDistM) {
            mLastCalibDistM = calibDistM;
        }
        if (elapsedSec > mLastElapsedSec) {
            mLastElapsedSec = elapsedSec;
        }

        // 2. Pace Sanity Check
        var nativeValid = (calibSpeedMps >= MIN_SANITY_SPEED_MPS && calibSpeedMps <= MAX_SANITY_SPEED_MPS);
        if (!nativeValid) {
            mWasRejected = true;
            return mLastValidSpeedMps;
        }

        mValidSampleCount += 1;

        // 3. Phase 1 — Warmup (0-200m, or < 30s, or < 10 valid samples)
        var isWarmup = (
            calibDistM < WARMUP_DIST_M ||
            elapsedSec < WARMUP_TIME_SEC ||
            mValidSampleCount < WARMUP_MIN_SAMPLES
        );
        if (isWarmup) {
            mLastValidSpeedMps = calibSpeedMps;
            return mLastValidSpeedMps;
        }

        // 4. Compute Lap Speed only if lap distance >= 50m
        var lapDistM = calibDistM - mLapStartDistM;
        var lapTimeSec = elapsedSec - mLapStartTimeSec;
        var lapSpeedMps = calibSpeedMps;
        if (lapDistM >= MIN_LAP_DIST_M && lapTimeSec >= 5.0f) {
            var candidateLapSpeed = lapDistM / lapTimeSec;
            if (candidateLapSpeed >= MIN_SANITY_SPEED_MPS && candidateLapSpeed <= MAX_SANITY_SPEED_MPS) {
                lapSpeedMps = candidateLapSpeed;
            }
        }

        // 5. Phase 2 — Progressive Blending (200m to 500m)
        if (calibDistM < BLEND_END_DIST_M) {
            var progress = (calibDistM - WARMUP_DIST_M) / (BLEND_END_DIST_M - WARMUP_DIST_M);
            if (progress < 0.0f) { progress = 0.0f; }
            if (progress > 1.0f) { progress = 1.0f; }
            var lapWeight = 0.30f * progress;
            mLastValidSpeedMps = ((1.0f - lapWeight) * calibSpeedMps) + (lapWeight * lapSpeedMps);
            return mLastValidSpeedMps;
        }

        // 6. Phase 3 — Normal Treadmill Phase (> 500m)
        mLastValidSpeedMps = (0.70f * calibSpeedMps) + (0.30f * lapSpeedMps);
        return mLastValidSpeedMps;
    }
}
