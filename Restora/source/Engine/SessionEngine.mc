import Toybox.Lang;

//! Unified Recovery Session Engine: one state machine runs every session type
//! (breathing, holds, repetitions, alternating sides, rest, transitions).
//!
//! The engine has no timers of its own. The caller passes a monotonic clock
//! (System.getTimer() ms) to every method, which keeps it deterministic and
//! unit-testable. Elapsed time is computed from clock deltas, never from
//! counting ticks, so a delayed tick does not drift the session.
class SessionEngine {

    // States
    static const IDLE = 0;
    static const COUNTDOWN = 1;
    static const RUNNING = 2;
    static const PAUSED = 3;
    static const AWAITING_NEXT = 4; // step finished, manual advance mode
    static const COMPLETED = 5;
    static const CANCELLED = 6;

    // Event bits returned by tick()/actions, consumed by the UI + haptics
    static const EVT_NONE = 0;
    static const EVT_STEP_START = 1;
    static const EVT_PHASE = 2;
    static const EVT_SIDE = 4;
    static const EVT_COMPLETE = 8;
    static const EVT_STEP_DONE = 16;

    static const PREV_RESTART_MS = 3000;

    var sessionId;
    var def;
    var steps;
    var state as Number = IDLE;
    var stepIndex as Number = 0;
    var stepElapsedMs as Number = 0;
    var activeMs as Number = 0;
    var countdownMs as Number = 0;
    var autoAdvance as Boolean = true;
    var restMs as Number = 0;          // rest between exercises (0 = none)
    var resting as Boolean = false;    // COUNTDOWN is a rest, not the opening countdown
    var completedCount as Number = 0;
    var skippedCount as Number = 0;
    var cycles as Number = 0;
    var tags;
    var _lastMs as Number = 0;
    var _stepAccounted as Boolean = false;

    function initialize(sessionId, def, countdownSec as Number, autoAdvance as Boolean) {
        self.sessionId = sessionId;
        self.def = def;
        self.steps = def[SessionLibrary.F_STEPS];
        self.countdownMs = countdownSec * 1000;
        self.autoAdvance = autoAdvance;
        self.tags = {};
    }

    // ---- Queries ---------------------------------------------------------

    function isActive() as Boolean {
        return state == COUNTDOWN || state == RUNNING || state == PAUSED || state == AWAITING_NEXT;
    }

    function isFinished() as Boolean {
        return state == COMPLETED || state == CANCELLED;
    }

    function currentExerciseId() {
        return (stepIndex < steps.size()) ? steps[stepIndex][0] : null;
    }

    function currentExercise() {
        var id = currentExerciseId();
        return (id == null) ? null : ExerciseLibrary.get(id);
    }

    function stepDurationMs() as Number {
        return (stepIndex < steps.size()) ? steps[stepIndex][1] * 1000 : 0;
    }

    function stepRemainingMs() as Number {
        var r = stepDurationMs() - stepElapsedMs;
        return (r > 0) ? r : 0;
    }

    function plannedSeconds() as Number {
        return SessionLibrary.totalSeconds(def);
    }

    //! 0..100 progress through planned active time.
    function progressPercent() as Number {
        var planned = plannedSeconds() * 1000;
        if (planned <= 0) {
            return 0;
        }
        var done = 0;
        for (var i = 0; i < stepIndex && i < steps.size(); i++) {
            done += steps[i][1] * 1000;
        }
        done += stepElapsedMs;
        var p = done * 100 / planned;
        return (p > 100) ? 100 : p;
    }

    //! Breathing phase 0..3 for the current step, or null if not breathing.
    function breathingPhase() {
        var ex = currentExercise();
        if (ex == null || ex[ExerciseLibrary.F_TYPE] != Models.TYPE_BREATHING) {
            return null;
        }
        return BreathingCalculator.phaseAt(ex[ExerciseLibrary.F_PATTERN], stepElapsedMs);
    }

    //! "L"/"R" for alternating steps, null otherwise.
    function currentSide() {
        var ex = currentExercise();
        if (ex == null || ex[ExerciseLibrary.F_TYPE] != Models.TYPE_ALTERNATING) {
            return null;
        }
        return (stepElapsedMs * 2 < stepDurationMs()) ? Models.TAG_LEFT : Models.TAG_RIGHT;
    }

    // ---- Actions ---------------------------------------------------------

    function start(nowMs as Number) as Number {
        if (state != IDLE) {
            return EVT_NONE;
        }
        _lastMs = nowMs;
        if (countdownMs > 0) {
            state = COUNTDOWN;
            return EVT_NONE;
        }
        return beginRunning();
    }

    function pause(nowMs as Number) as Number {
        if (state == RUNNING || state == COUNTDOWN) {
            var evt = tick(nowMs);
            if (state == RUNNING || state == COUNTDOWN) {
                state = PAUSED;
            }
            return evt;
        }
        return EVT_NONE;
    }

    function resume(nowMs as Number) as Number {
        if (state == PAUSED) {
            _lastMs = nowMs;
            state = (countdownMs > 0) ? COUNTDOWN : RUNNING;
        }
        return EVT_NONE;
    }

    function togglePause(nowMs as Number) as Number {
        return (state == PAUSED) ? resume(nowMs) : pause(nowMs);
    }

    //! Skip the current exercise (counts as skipped; partial time is kept).
    function skip(nowMs as Number) as Number {
        if (state == COUNTDOWN && resting) {
            return endRest(nowMs);
        }
        if (state == AWAITING_NEXT) {
            return next(nowMs);
        }
        if (state != RUNNING && state != PAUSED) {
            return EVT_NONE;
        }
        var wasPaused = (state == PAUSED);
        var evt = wasPaused ? EVT_NONE : tick(nowMs);
        if (isFinished()) {
            return evt;
        }
        accountStep();
        skippedCount++;
        evt |= advance();
        if (wasPaused && state == RUNNING) {
            state = PAUSED;
        }
        _lastMs = nowMs;
        return evt;
    }

    //! Manual advance after a finished step.
    function next(nowMs as Number) as Number {
        if (state != AWAITING_NEXT) {
            return EVT_NONE;
        }
        _lastMs = nowMs;
        state = RUNNING;
        return advance();
    }

    //! Previous: within the first 3 s of a step go back one exercise,
    //! otherwise restart the current one. Time already done stays counted;
    //! a paused session stays paused.
    function previous(nowMs as Number) as Number {
        if (state == COUNTDOWN && resting) {
            resting = false;
            countdownMs = 0;
            if (stepIndex > 0) {
                stepIndex--;
                if (completedCount > 0) {
                    completedCount--;
                }
            }
            stepElapsedMs = 0;
            _stepAccounted = false;
            state = RUNNING;
            _lastMs = nowMs;
            return EVT_STEP_START;
        }
        if (state != RUNNING && state != PAUSED && state != AWAITING_NEXT) {
            return EVT_NONE;
        }
        var wasPaused = (state == PAUSED);
        if (state == RUNNING) {
            tick(nowMs);
            if (isFinished() || state != RUNNING) {
                return EVT_NONE;
            }
        }
        accountStep();
        if (state != AWAITING_NEXT && stepElapsedMs < PREV_RESTART_MS && stepIndex > 0) {
            stepIndex--;
        } else if (state == AWAITING_NEXT && completedCount > 0) {
            completedCount--;   // finished step is replayed; it counts once when it ends again
        }
        stepElapsedMs = 0;
        _stepAccounted = false;
        state = wasPaused ? PAUSED : RUNNING;
        _lastMs = nowMs;
        return EVT_STEP_START;
    }

    function cancel(nowMs as Number) as Number {
        if (!isActive()) {
            return EVT_NONE;
        }
        if (state == RUNNING) {
            tick(nowMs);
        }
        if (!isFinished()) {
            accountStep();
            state = CANCELLED;
        }
        return EVT_NONE;
    }

    //! Advance the clock. Returns a bitmask of EVT_* that happened.
    //! COUNTDOWN is used both before the first exercise and for the rest
    //! between exercises (resting == true); leftover time carries over.
    function tick(nowMs as Number) as Number {
        var delta = nowMs - _lastMs;
        _lastMs = nowMs;
        if (delta <= 0) {
            return EVT_NONE;
        }
        var evt = EVT_NONE;
        while (delta > 0 && (state == COUNTDOWN || state == RUNNING)) {
            if (state == COUNTDOWN) {
                if (delta < countdownMs) {
                    countdownMs -= delta;
                    return evt;
                }
                delta -= countdownMs;
                countdownMs = 0;
                if (resting) {
                    resting = false;
                    state = RUNNING;
                    evt |= EVT_STEP_START;
                } else {
                    evt |= beginRunning();
                }
                continue;
            }
            var remaining = stepDurationMs() - stepElapsedMs;
            var used = (delta < remaining) ? delta : remaining;
            var phaseBefore = breathingPhase();
            var sideBefore = currentSide();
            stepElapsedMs += used;
            activeMs += used;
            delta -= used;
            if (stepElapsedMs < stepDurationMs()) {
                if (breathingPhase() != phaseBefore) {
                    evt |= EVT_PHASE;
                }
                if (currentSide() != sideBefore) {
                    evt |= EVT_SIDE;
                }
            } else {
                accountStep();
                completedCount++;
                evt |= EVT_STEP_DONE;
                if (autoAdvance || stepIndex + 1 >= steps.size()) {
                    var a = advance();
                    if (a == EVT_STEP_START && restMs > 0) {
                        // rest before the next exercise; it starts (and buzzes) after
                        state = COUNTDOWN;
                        countdownMs = restMs;
                        resting = true;
                    } else {
                        evt |= a;
                    }
                } else {
                    state = AWAITING_NEXT;
                }
            }
        }
        return evt;
    }

    //! End the rest early (START or DOWN during a rest).
    function endRest(nowMs as Number) as Number {
        if (state != COUNTDOWN || !resting) {
            return EVT_NONE;
        }
        tick(nowMs);
        if (state != COUNTDOWN || !resting) {
            return EVT_STEP_START;     // the rest ran out in this tick
        }
        countdownMs = 0;
        resting = false;
        state = RUNNING;
        _lastMs = nowMs;
        return EVT_STEP_START;
    }

    // ---- Result ----------------------------------------------------------

    //! Build the history record. hrBefore/hrAfter are optional Garmin readings.
    function buildRecord(startEpoch as Number, hrBefore, hrAfter) as Dictionary {
        var r = {
            Models.K_ID => sessionId,
            Models.K_CAT => def[SessionLibrary.F_CAT],
            Models.K_START => startEpoch,
            Models.K_DUR => (activeMs + 500) / 1000,
            Models.K_PLAN => plannedSeconds(),
            Models.K_STATUS => (state == COMPLETED) ? Models.STATUS_COMPLETED : Models.STATUS_CANCELLED,
            Models.K_DONE => completedCount,
            Models.K_SKIP => skippedCount,
            Models.K_TOTAL => steps.size(),
            Models.K_CYCLES => cycles,
            Models.K_TAGS => tags
        };
        var b = MetricValidator.validHr(hrBefore);
        var a = MetricValidator.validHr(hrAfter);
        if (b != null) {
            r.put(Models.K_HR_BEFORE, b);
        }
        if (a != null) {
            r.put(Models.K_HR_AFTER, a);
        }
        return r;
    }

    // ---- Internals -------------------------------------------------------

    hidden function beginRunning() as Number {
        state = RUNNING;
        stepIndex = 0;
        stepElapsedMs = 0;
        _stepAccounted = false;
        return (steps.size() > 0) ? EVT_STEP_START : completeNow();
    }

    hidden function advance() as Number {
        stepIndex++;
        stepElapsedMs = 0;
        _stepAccounted = false;
        if (stepIndex >= steps.size()) {
            return completeNow();
        }
        state = RUNNING;
        return EVT_STEP_START;
    }

    hidden function completeNow() as Number {
        state = COMPLETED;
        return EVT_COMPLETE;
    }

    //! Add the current step's elapsed time to tag totals (once per step).
    hidden function accountStep() as Void {
        if (_stepAccounted || stepIndex >= steps.size()) {
            return;
        }
        _stepAccounted = true;
        var secs = stepElapsedMs / 1000;
        var ex = currentExercise();
        if (ex == null || secs <= 0) {
            return;
        }
        addTag(ex[ExerciseLibrary.F_TAG], secs);
        var type = ex[ExerciseLibrary.F_TYPE];
        if (type == Models.TYPE_BREATHING) {
            var c = BreathingCalculator.completedCycles(ex[ExerciseLibrary.F_PATTERN], stepElapsedMs);
            if (c != null) {
                cycles += c;
            }
        } else if (type == Models.TYPE_ALTERNATING) {
            var half = stepDurationMs() / 2;
            var leftMs = (stepElapsedMs < half) ? stepElapsedMs : half;
            addTag(Models.TAG_LEFT, leftMs / 1000);
            addTag(Models.TAG_RIGHT, (stepElapsedMs - leftMs) / 1000);
        }
    }

    hidden function addTag(tag as String, secs as Number) as Void {
        if (secs <= 0) {
            return;
        }
        var cur = tags.get(tag);
        tags.put(tag, (cur == null) ? secs : cur + secs);
    }
}
