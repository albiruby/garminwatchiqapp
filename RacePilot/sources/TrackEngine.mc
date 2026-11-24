import Toybox.Lang;
import Toybox.Math;

class TrackEngine {
    private var mTrackLapLengthM as Float = 400.0f;
    private var mCurrentLapStartDistM as Float = 0.0f;
    private var mCurrentLapStartTimeSec as Float = 0.0f;
    private var mCompletedLaps as Number = 0;
    private var mLastSplitPaceSec as Float = 0.0f;
    private var mCurrentLapPaceSec as Float = 0.0f;
    private var mIsIntervalActive as Boolean = false;

    private const SPLIT_BUFFER_SIZE as Number = 8;
    private var mSplitBuffer as Array<Float>;
    private var mSplitCount as Number = 0;
    private var mSplitIndex as Number = 0;

    private const LAP_BLEND_DIST_M as Float = 50.0f;
    private const TRACK_HYSTERESIS_SEC as Float = 0.5f;
    private const INTERVAL_VARIANCE_THRESHOLD_SEC as Float = 8.0f;

    public function initialize(trackLapLengthM as Number) {
        mSplitBuffer = new Array<Float>[SPLIT_BUFFER_SIZE];
        setTrackLapLength(trackLapLengthM);
        reset();
    }

    public function reset() as Void {
        mCurrentLapStartDistM = 0.0f;
        mCurrentLapStartTimeSec = 0.0f;
        mCompletedLaps = 0;
        mLastSplitPaceSec = 0.0f;
        mCurrentLapPaceSec = 0.0f;
        mIsIntervalActive = false;
        for (var i = 0; i < SPLIT_BUFFER_SIZE; i += 1) {
            mSplitBuffer[i] = 0.0f;
        }
        mSplitCount = 0;
        mSplitIndex = 0;
    }

    public function setTrackLapLength(trackLapLengthM as Number) as Void {
        if (trackLapLengthM >= 100 && trackLapLengthM <= 2000) {
            mTrackLapLengthM = trackLapLengthM.toFloat();
        } else {
            mTrackLapLengthM = 400.0f;
        }
    }

    public function getTrackLapLengthM() as Float {
        return mTrackLapLengthM;
    }

    public function getHysteresisSec() as Float {
        return TRACK_HYSTERESIS_SEC;
    }

    public function isIntervalActive() as Boolean {
        return mIsIntervalActive;
    }

    public function onHardwareLap(totalDistM as Float, elapsedSec as Float) as Void {
        var lapDistM = totalDistM - mCurrentLapStartDistM;
        var lapTimeSec = elapsedSec - mCurrentLapStartTimeSec;

        var minAutoDetectM = mTrackLapLengthM * 0.875f;
        var maxAutoDetectM = mTrackLapLengthM * 1.125f;

        if (lapDistM >= minAutoDetectM && lapDistM <= maxAutoDetectM && lapTimeSec > 20.0f) {
            var splitPace = (lapTimeSec / lapDistM) * mTrackLapLengthM;
            recordSplit(splitPace);
            mCompletedLaps += 1;
        } else if (lapDistM >= 50.0f && lapTimeSec > 10.0f) {
            var splitPace = (lapTimeSec / lapDistM) * mTrackLapLengthM;
            recordSplit(splitPace);
            mCompletedLaps = (totalDistM / mTrackLapLengthM).toNumber();
        }

        mCurrentLapStartDistM = totalDistM;
        mCurrentLapStartTimeSec = elapsedSec;
    }

    public function update(
        correctedDistM as Float,
        elapsedSec as Float,
        nativeSpeedMps as Float
    ) as Float {
        var lapDistM = correctedDistM - mCurrentLapStartDistM;
        var lapTimeSec = elapsedSec - mCurrentLapStartTimeSec;

        if (lapDistM >= mTrackLapLengthM) {
            var splitPace = (lapTimeSec / lapDistM) * mTrackLapLengthM;
            recordSplit(splitPace);
            mCompletedLaps += 1;
            mCurrentLapStartDistM += mTrackLapLengthM;
            mCurrentLapStartTimeSec = elapsedSec - ((correctedDistM - mCurrentLapStartDistM) / (nativeSpeedMps > 0.5f ? nativeSpeedMps : 3.0f));
            lapDistM = correctedDistM - mCurrentLapStartDistM;
            lapTimeSec = elapsedSec - mCurrentLapStartTimeSec;
        }

        var rawLapPaceSec = 0.0f;
        if (lapDistM >= 15.0f && lapTimeSec > 2.0f) {
            rawLapPaceSec = (lapTimeSec / lapDistM) * mTrackLapLengthM;
        } else if (nativeSpeedMps >= 1.111f && nativeSpeedMps <= 8.333f) {
            rawLapPaceSec = mTrackLapLengthM / nativeSpeedMps;
        } else if (mLastSplitPaceSec > 0.0f) {
            rawLapPaceSec = mLastSplitPaceSec;
        }

        if (rawLapPaceSec <= 0.0f) {
            return mCurrentLapPaceSec;
        }

        var transitionPredDistM = mTrackLapLengthM * 0.9875f;
        if (lapDistM >= transitionPredDistM) {
            if (mCurrentLapPaceSec > 0.0f) {
                return mCurrentLapPaceSec;
            }
        }

        if (lapDistM < LAP_BLEND_DIST_M && mLastSplitPaceSec > 0.0f && !mIsIntervalActive) {
            var blendRatio = lapDistM / LAP_BLEND_DIST_M;
            if (blendRatio < 0.0f) { blendRatio = 0.0f; }
            if (blendRatio > 1.0f) { blendRatio = 1.0f; }
            mCurrentLapPaceSec = (blendRatio * rawLapPaceSec) + ((1.0f - blendRatio) * mLastSplitPaceSec);
        } else {
            mCurrentLapPaceSec = rawLapPaceSec;
        }

        return mCurrentLapPaceSec;
    }

    public function getCompletedLaps(correctedDistM as Float) as Number {
        var byDist = (correctedDistM / mTrackLapLengthM).toNumber();
        return byDist > mCompletedLaps ? byDist : mCompletedLaps;
    }

    public function getEstimatedTotalLaps(targetDistM as Float) as Float {
        if (targetDistM <= 0.0f || mTrackLapLengthM <= 0.0f) {
            return 0.0f;
        }
        return targetDistM / mTrackLapLengthM;
    }

    public function formatLapCount(correctedDistM as Float, targetDistM as Float) as String {
        var done = getCompletedLaps(correctedDistM);
        var total = getEstimatedTotalLaps(targetDistM);
        if (total <= 0.0f) {
            return done.format("%d");
        }
        var totalInt = total.toNumber();
        var frac = (total - totalInt.toFloat()).abs();
        if (frac < 0.05f) {
            return done.format("%d") + "/" + totalInt.format("%d");
        }
        return done.format("%d") + "/" + total.format("%.1f");
    }

    private function recordSplit(splitPaceSec as Float) as Void {
        if (splitPaceSec <= 0.0f) {
            return;
        }
        if (mLastSplitPaceSec > 0.0f) {
            var normalizedDiff = (splitPaceSec - mLastSplitPaceSec).abs() * (400.0f / mTrackLapLengthM);
            mIsIntervalActive = (normalizedDiff > INTERVAL_VARIANCE_THRESHOLD_SEC);
        }
        mLastSplitPaceSec = splitPaceSec;
        mSplitBuffer[mSplitIndex] = splitPaceSec;
        mSplitIndex = (mSplitIndex + 1) % SPLIT_BUFFER_SIZE;
        if (mSplitCount < SPLIT_BUFFER_SIZE) {
            mSplitCount += 1;
        }
    }
}
