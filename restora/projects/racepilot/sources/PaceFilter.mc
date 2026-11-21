import Toybox.Lang;
import Toybox.Math;

class PaceFilter {
    private const MEDIAN_WINDOW as Number = 5;
    private var mWindow as Array<Float>;
    private var mWindowCount as Number = 0;
    private var mWindowIndex as Number = 0;
    // Preallocated scratch buffer for median sort (avoid per-tick allocation)
    private var mScratch as Array<Float>;

    private var mEwmaPaceSec as Float = 0.0f;
    private var mLockedPaceSec as Float = 0.0f;
    private var mIsPaceLocked as Boolean = false;
    private var mStableTicks as Number = 0;
    private var mSmoothingSetting as Number = 50;

    private const MAX_SLEW_PER_SEC as Float = 6.0f;
    private const LOCK_DEADBAND_SEC as Float = 1.5f;
    private const UNLOCK_BREAKOUT_SEC as Float = 3.2f;
    private const STABLE_TICKS_FOR_LOCK as Number = 4;

    public function initialize(smoothingSetting as Number) {
        mWindow = [0.0f, 0.0f, 0.0f, 0.0f, 0.0f] as Array<Float>;
        mScratch = [0.0f, 0.0f, 0.0f, 0.0f, 0.0f] as Array<Float>;
        setSmoothing(smoothingSetting);
        reset();
    }

    public function reset() as Void {
        for (var i = 0; i < MEDIAN_WINDOW; i += 1) {
            mWindow[i] = 0.0f;
        }
        mWindowCount = 0;
        mWindowIndex = 0;
        mEwmaPaceSec = 0.0f;
        mLockedPaceSec = 0.0f;
        mIsPaceLocked = false;
        mStableTicks = 0;
    }

    public function setSmoothing(smoothingSetting as Number) as Void {
        if (smoothingSetting < 0) {
            mSmoothingSetting = 0;
        } else if (smoothingSetting > 100) {
            mSmoothingSetting = 100;
        } else {
            mSmoothingSetting = smoothingSetting;
        }
    }

    public function isLocked() as Boolean {
        return mIsPaceLocked;
    }

    public function filter(rawPaceSec as Float, confidence as Float, hysteresisSec as Float) as Float {
        if (rawPaceSec <= 0.0f || rawPaceSec > 1800.0f) {
            return mLockedPaceSec > 0.0f ? mLockedPaceSec : mEwmaPaceSec;
        }

        mWindow[mWindowIndex] = rawPaceSec;
        mWindowIndex = (mWindowIndex + 1) % MEDIAN_WINDOW;
        if (mWindowCount < MEDIAN_WINDOW) {
            mWindowCount += 1;
        }

        var medianPace = computeMedian();

        if (mEwmaPaceSec <= 0.0f) {
            mEwmaPaceSec = medianPace;
            mLockedPaceSec = medianPace;
            return mLockedPaceSec;
        }

        var baseAlpha = 0.65f - ((mSmoothingSetting.toFloat() / 100.0f) * 0.51f);
        var delta = (medianPace - mEwmaPaceSec).abs();

        if (delta > 6.0f && confidence >= 0.70f) {
            baseAlpha = baseAlpha * 1.45f;
            if (baseAlpha > 0.75f) { baseAlpha = 0.75f; }
        } else if (confidence < 0.45f) {
            baseAlpha = baseAlpha * 0.50f;
        }

        var candidatePace = (baseAlpha * medianPace) + ((1.0f - baseAlpha) * mEwmaPaceSec);

        var maxStep = MAX_SLEW_PER_SEC * (0.5f + (0.5f * confidence));
        var stepDiff = candidatePace - mEwmaPaceSec;
        if (stepDiff > maxStep) {
            candidatePace = mEwmaPaceSec + maxStep;
        } else if (stepDiff < -maxStep) {
            candidatePace = mEwmaPaceSec - maxStep;
        }

        mEwmaPaceSec = candidatePace;

        var effectiveDeadband = hysteresisSec > 0.0f ? hysteresisSec : LOCK_DEADBAND_SEC;
        var lockDelta = (mEwmaPaceSec - mLockedPaceSec).abs();

        if (mIsPaceLocked) {
            if (lockDelta > UNLOCK_BREAKOUT_SEC) {
                mIsPaceLocked = false;
                mStableTicks = 0;
                mLockedPaceSec = mEwmaPaceSec;
            }
        } else {
            if (lockDelta <= effectiveDeadband) {
                mStableTicks += 1;
                if (mStableTicks >= STABLE_TICKS_FOR_LOCK) {
                    mIsPaceLocked = true;
                }
            } else {
                mStableTicks = 0;
                mLockedPaceSec = mEwmaPaceSec;
            }
        }

        return mLockedPaceSec;
    }

    public function getEwmaPaceSec() as Float {
        return mEwmaPaceSec;
    }

    private function computeMedian() as Float {
        // Use preallocated scratch buffer (no per-tick allocation)
        for (var i = 0; i < mWindowCount; i += 1) {
            mScratch[i] = mWindow[i];
        }
        for (var i = 1; i < mWindowCount; i += 1) {
            var key = mScratch[i];
            var j = i - 1;
            while (j >= 0 && mScratch[j] > key) {
                mScratch[j + 1] = mScratch[j];
                j -= 1;
            }
            mScratch[j + 1] = key;
        }
        var mid = mWindowCount / 2;
        return mScratch[mid];
    }
}
