import Toybox.Activity;
import Toybox.Lang;

enum RPState {
    STATE_NO_TARGET = 0,
    STATE_IDLE = 1,
    STATE_WAIT_GPS = 2,
    STATE_READY = 3,
    STATE_COUNTDOWN = 4,
    STATE_RACING = 5,
    STATE_PAUSED = 6,
    STATE_MANUAL_PAUSED = 7,
    STATE_RESUMED = 8,
    STATE_FINISHING = 9,
    STATE_FINISHED = 10,
    STATE_LOCKED = 11
}

class RunStateMachine {
    private var mState as RPState = STATE_IDLE;
    private var mFinishLocked as Boolean = false;
    private var mFinishedTimestampMs as Number = 0;
    private var mResumeTicksRemaining as Number = 0;
    private var mLastDistanceM as Float = 0.0f;
    // Auto-pause: require distance stagnation to avoid false positive on GPS speed dropout
    private var mStagnantTicks as Number = 0;
    private var mPrevTickDistM as Float = -1.0f;

    private const FINISHING_ZONE_RATIO as Float = 0.95f;
    private const FINISHING_ZONE_MAX_M as Float = 200.0f;
    private const FINISH_LOCK_DELAY_MS as Number = 3000;
    private const AUTO_PAUSE_SPEED_MPS as Float = 0.35f;
    private const AUTO_PAUSE_STAGNANT_TICKS as Number = 3;
    private const AUTO_PAUSE_MIN_MOVE_M as Float = 0.5f;

    public function initialize() {
        reset();
    }

    public function reset() as Void {
        mState = STATE_IDLE;
        mFinishLocked = false;
        mFinishedTimestampMs = 0;
        mResumeTicksRemaining = 0;
        mLastDistanceM = 0.0f;
        mStagnantTicks = 0;
        mPrevTickDistM = -1.0f;
    }

    public function getState() as RPState {
        return mState;
    }

    public function isFinishLocked() as Boolean {
        return mFinishLocked;
    }

    public function update(
        hasTarget as Boolean,
        needsGps as Boolean,
        hasGpsLock as Boolean,
        timerState as Number,
        currentDistM as Float,
        targetDistM as Float,
        currentSpeedMps as Float,
        elapsedMs as Number
    ) as RPState {
        if (mFinishLocked) {
            mState = STATE_LOCKED;
            return mState;
        }

        if (!hasTarget || targetDistM <= 0.0f) {
            mState = STATE_NO_TARGET;
            return mState;
        }

        if (currentDistM > mLastDistanceM) {
            mLastDistanceM = currentDistM;
        }
        var effectiveDistM = mLastDistanceM;

        if (effectiveDistM >= targetDistM) {
            if (mState != STATE_FINISHED && mState != STATE_LOCKED) {
                mState = STATE_FINISHED;
                mFinishedTimestampMs = elapsedMs;
            } else if (elapsedMs - mFinishedTimestampMs >= FINISH_LOCK_DELAY_MS) {
                mFinishLocked = true;
                mState = STATE_LOCKED;
            }
            return mState;
        }

        if (timerState == Activity.TIMER_STATE_OFF) {
            if (needsGps && !hasGpsLock) {
                mState = STATE_WAIT_GPS;
            } else {
                mState = STATE_READY;
            }
            return mState;
        }

        if (timerState == Activity.TIMER_STATE_PAUSED || timerState == Activity.TIMER_STATE_STOPPED) {
            mState = STATE_MANUAL_PAUSED;
            mResumeTicksRemaining = 3;
            return mState;
        }

        if (needsGps && !hasGpsLock && effectiveDistM < 15.0f) {
            mState = STATE_WAIT_GPS;
            return mState;
        }

        if (effectiveDistM > 30.0f && currentSpeedMps < AUTO_PAUSE_SPEED_MPS) {
            // Require distance stagnation before declaring auto-pause.
            // Prevents false pause when GPS speed momentarily drops to 0
            // but distance is still increasing.
            if (mPrevTickDistM >= 0.0f && (effectiveDistM - mPrevTickDistM) >= AUTO_PAUSE_MIN_MOVE_M) {
                mStagnantTicks = 0;  // still moving — reset
            } else {
                mStagnantTicks += 1;
            }
            mPrevTickDistM = effectiveDistM;

            if (mStagnantTicks >= AUTO_PAUSE_STAGNANT_TICKS) {
                mState = STATE_PAUSED;
                mResumeTicksRemaining = 2;
                return mState;
            }
        } else {
            mStagnantTicks = 0;
            mPrevTickDistM = effectiveDistM;
        }

        if (mResumeTicksRemaining > 0) {
            mResumeTicksRemaining -= 1;
            mState = STATE_RESUMED;
            return mState;
        }

        var remainingM = targetDistM - effectiveDistM;
        if (remainingM <= FINISHING_ZONE_MAX_M || (effectiveDistM / targetDistM) >= FINISHING_ZONE_RATIO) {
            mState = STATE_FINISHING;
            return mState;
        }

        mState = STATE_RACING;
        return mState;
    }

    public function shouldFreezeProjections() as Boolean {
        return (
            mState == STATE_MANUAL_PAUSED ||
            mState == STATE_PAUSED ||
            mState == STATE_FINISHED ||
            mState == STATE_LOCKED ||
            mState == STATE_IDLE ||
            mState == STATE_WAIT_GPS ||
            mState == STATE_READY
        );
    }

    public function shouldHideNeedPace() as Boolean {
        return (
            mState == STATE_NO_TARGET ||
            mState == STATE_FINISHED ||
            mState == STATE_LOCKED ||
            mState == STATE_IDLE ||
            mState == STATE_WAIT_GPS ||
            mState == STATE_READY
        );
    }

    public function getStateLabel() as String {
        if (mState == STATE_NO_TARGET) { return "NO TARGET"; }
        if (mState == STATE_IDLE) { return "IDLE"; }
        if (mState == STATE_WAIT_GPS) { return "WAIT GPS"; }
        if (mState == STATE_READY) { return "READY"; }
        if (mState == STATE_COUNTDOWN) { return "SET"; }
        if (mState == STATE_RACING) { return "RACING"; }
        if (mState == STATE_PAUSED) { return "AUTO PAUSE"; }
        if (mState == STATE_MANUAL_PAUSED) { return "PAUSED"; }
        if (mState == STATE_RESUMED) { return "RESUMED"; }
        if (mState == STATE_FINISHING) { return "FINAL KICK"; }
        if (mState == STATE_FINISHED) { return "FINISHED"; }
        if (mState == STATE_LOCKED) { return "LOCKED"; }
        return "READY";
    }
}
