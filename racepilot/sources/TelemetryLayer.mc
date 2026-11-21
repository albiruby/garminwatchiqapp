import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;

class TelemetryLayer {
    private const RING_SIZE as Number = 32;
    private var mPaceRing as Array<Float>;
    private var mRingIndex as Number = 0;
    private var mRingCount as Number = 0;

    private var mTotalSamples as Number = 0;
    private var mRejectedSamples as Number = 0;
    private var mGpsGoodCount as Number = 0;
    private var mGpsPoorCount as Number = 0;
    private var mLastVarianceSec as Float = 0.0f;

    public function initialize() {
        mPaceRing = new Array<Float>[RING_SIZE];
        reset();
    }

    public function reset() as Void {
        for (var i = 0; i < RING_SIZE; i += 1) {
            mPaceRing[i] = 0.0f;
        }
        mRingIndex = 0;
        mRingCount = 0;
        mTotalSamples = 0;
        mRejectedSamples = 0;
        mGpsGoodCount = 0;
        mGpsPoorCount = 0;
        mLastVarianceSec = 0.0f;
    }

    public function recordSample(paceSec as Float, wasRejected as Boolean, gpsAccuracy as Number?) as Void {
        mTotalSamples += 1;
        if (wasRejected) {
            mRejectedSamples += 1;
        } else if (paceSec > 0.0f) {
            mPaceRing[mRingIndex] = paceSec;
            mRingIndex = (mRingIndex + 1) % RING_SIZE;
            if (mRingCount < RING_SIZE) {
                mRingCount += 1;
            }
            mLastVarianceSec = computeStdDev();
        }

        if (gpsAccuracy != null && gpsAccuracy >= Position.QUALITY_USABLE) {
            mGpsGoodCount += 1;
        } else {
            mGpsPoorCount += 1;
        }
    }

    public function getPaceVarianceSec() as Float {
        return mLastVarianceSec;
    }

    public function getRejectionRatePct() as Float {
        if (mTotalSamples <= 0) {
            return 0.0f;
        }
        return (mRejectedSamples.toFloat() / mTotalSamples.toFloat()) * 100.0f;
    }

    public function getGpsGoodRatioPct() as Float {
        var total = mGpsGoodCount + mGpsPoorCount;
        if (total <= 0) {
            return 0.0f;
        }
        return (mGpsGoodCount.toFloat() / total.toFloat()) * 100.0f;
    }

    private function computeStdDev() as Float {
        if (mRingCount < 2) {
            return 0.0f;
        }
        var sum = 0.0f;
        for (var i = 0; i < mRingCount; i += 1) {
            sum += mPaceRing[i];
        }
        var mean = sum / mRingCount.toFloat();
        var sqDiffSum = 0.0f;
        for (var i = 0; i < mRingCount; i += 1) {
            var d = mPaceRing[i] - mean;
            sqDiffSum += d * d;
        }
        return Math.sqrt(sqDiffSum / mRingCount.toFloat()).toFloat();
    }
}
