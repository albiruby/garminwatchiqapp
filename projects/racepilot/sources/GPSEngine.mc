import Toybox.Activity;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;

class GPSEngine {
    private var mLastValidSpeedMps as Float = 0.0f;
    private var mLastHeadingRad as Float? = null;
    private var mLastDistanceM as Float = 0.0f;
    private var mLastCadenceSpm as Number = 0;

    private var mSignalLostTimestampMs as Number = -1;
    private var mRecoveryTicksRemaining as Number = 0;
    private var mWasRejected as Boolean = false;

    private const TUNNEL_GRACE_MS as Number = 5000;
    private const RECOVERY_BLEND_TICKS as Number = 3;
    private const CORNER_HEADING_THRESHOLD_RAD as Float = 0.42f;
    private const MIN_VALID_SPEED_MPS as Float = 1.111f;
    private const MAX_VALID_SPEED_MPS as Float = 8.333f;
    private const MAX_RELATIVE_CHANGE_PCT as Float = 0.32f;

    public function initialize() {
        reset();
    }

    public function reset() as Void {
        mLastValidSpeedMps = 0.0f;
        mLastHeadingRad = null;
        mLastDistanceM = 0.0f;
        mLastCadenceSpm = 0;
        mSignalLostTimestampMs = -1;
        mRecoveryTicksRemaining = 0;
        mWasRejected = false;
    }

    public function wasLastSampleRejected() as Boolean {
        return mWasRejected;
    }

    public function update(
        rawSpeedMps as Float,
        currentDistM as Float,
        elapsedMs as Number,
        gpsAccuracy as Number?,
        headingRad as Float?,
        altitudeM as Float?,
        cadenceSpm as Number?
    ) as Float {
        mWasRejected = false;

        var gpsGood = (gpsAccuracy != null && gpsAccuracy >= Position.QUALITY_USABLE);

        // 1. Tunnel / Tree-Cover Grace Hold (5 seconds)
        if (!gpsGood) {
            if (mSignalLostTimestampMs < 0) {
                mSignalLostTimestampMs = elapsedMs;
            }
            var lostDurationMs = elapsedMs - mSignalLostTimestampMs;
            if (lostDurationMs <= TUNNEL_GRACE_MS && mLastValidSpeedMps > 0.0f) {
                mRecoveryTicksRemaining = RECOVERY_BLEND_TICKS;
                return mLastValidSpeedMps;
            }
        } else {
            mSignalLostTimestampMs = -1;
        }

        // 2. Speed Sanity Check
        if (rawSpeedMps < MIN_VALID_SPEED_MPS || rawSpeedMps > MAX_VALID_SPEED_MPS) {
            mWasRejected = true;
            return mLastValidSpeedMps;
        }

        var workingSpeedMps = rawSpeedMps;

        // 3. Corner Protection via Heading Analysis
        if (headingRad != null && mLastHeadingRad != null && mLastValidSpeedMps > 0.0f) {
            var headingDelta = (headingRad - mLastHeadingRad).abs();
            if (headingDelta > Math.PI.toFloat()) {
                headingDelta = (2.0f * Math.PI.toFloat()) - headingDelta;
            }
            if (headingDelta >= CORNER_HEADING_THRESHOLD_RAD) {
                workingSpeedMps = (0.75f * mLastValidSpeedMps) + (0.25f * workingSpeedMps);
            }
        }
        mLastHeadingRad = headingRad;

        // 4. Cadence Spike & Outlier Rejection
        if (mLastValidSpeedMps > 0.0f) {
            var relChange = (workingSpeedMps - mLastValidSpeedMps).abs() / mLastValidSpeedMps;
            if (relChange > MAX_RELATIVE_CHANGE_PCT) {
                var cadenceConfirmed = false;
                if (cadenceSpm != null && mLastCadenceSpm > 0) {
                    var cadDiff = (cadenceSpm - mLastCadenceSpm).abs();
                    if (cadDiff >= 8) {
                        cadenceConfirmed = true;
                    }
                }
                if (!cadenceConfirmed) {
                    mWasRejected = true;
                    if (workingSpeedMps > mLastValidSpeedMps) {
                        workingSpeedMps = mLastValidSpeedMps * (1.0f + (MAX_RELATIVE_CHANGE_PCT * 0.35f));
                    } else {
                        workingSpeedMps = mLastValidSpeedMps * (1.0f - (MAX_RELATIVE_CHANGE_PCT * 0.35f));
                    }
                }
            }
        }
        if (cadenceSpm != null && cadenceSpm > 0) {
            mLastCadenceSpm = cadenceSpm;
        }

        // Grade compensation removed: its 10 m gate could never trigger at 1 Hz,
        // and adjusting real speed for grade would distort projected finish.
        // Grade-adjusted pace (GAP) is planned as a separate display metric (v2.3).
        if (currentDistM > mLastDistanceM) {
            mLastDistanceM = currentDistM;
        }

        // 6. Post-Tunnel GPS Recovery Ramp
        if (mRecoveryTicksRemaining > 0 && mLastValidSpeedMps > 0.0f) {
            var recoveryWeight = 1.0f / (mRecoveryTicksRemaining + 1).toFloat();
            workingSpeedMps = (recoveryWeight * workingSpeedMps) + ((1.0f - recoveryWeight) * mLastValidSpeedMps);
            mRecoveryTicksRemaining -= 1;
        }

        mLastValidSpeedMps = workingSpeedMps;
        return mLastValidSpeedMps;
    }
}
