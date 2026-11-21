import Toybox.Lang;

//! Connects Session Engine events to motion and haptics for one session
//! screen. It reacts to events; it never decides when anything ends.
//!
//! Session Engine event bits -> motion:
//!   EVT_STEP_START  -> EXERCISE_STARTED: new sampler, slide-in tween
//!   EVT_STEP_DONE   -> EXERCISE_COMPLETED (haptic via HapticEngine)
//!   EVT_PHASE       -> PHASE_CHANGED (breathing visuals follow the phase)
//!   EVT_SIDE        -> left/right switch: figure mirrors
//!   EVT_COMPLETE    -> SESSION_COMPLETED (summary plays the check animation)
//!   tick            -> TIMER_UPDATED; sampler.reps -> REPETITION_UPDATED
class MotionController {

    static const STEP_IN_MS = 220;
    static const STEP_IN_PX = 24;

    var sampler = null;          // PoseSampler for the current exercise, or null
    var renderer as FigureRenderer;
    hidden var _stepIn as Tween;
    hidden var _exerciseId = null;
    hidden var _lastSegment as Number = -1;

    function initialize() {
        renderer = new FigureRenderer();
        _stepIn = new Tween();
    }

    //! Handle engine events (bitmask) at nowMs; returns the same bitmask.
    function onEvents(engine as SessionEngine, evt as Number, nowMs as Number) as Number {
        HapticEngine.forEvents(evt);
        var id = engine.currentExerciseId();
        if ((evt & SessionEngine.EVT_STEP_START) != 0 || !sameId(id, _exerciseId)) {
            bindExercise(id);
            _stepIn.start(nowMs, STEP_IN_MS, Easing.OUT_CUBIC);
        } else if ((evt & SessionEngine.EVT_SIDE) != 0) {
            _stepIn.start(nowMs, STEP_IN_MS, Easing.OUT_CUBIC);   // re-enter on the new side
        }
        return evt;
    }

    //! Strings must be compared with equals(); == compares references.
    hidden function sameId(a, b) as Boolean {
        if (a == null || b == null) {
            return a == null && b == null;
        }
        return a.equals(b);
    }

    hidden function bindExercise(id) as Void {
        _exerciseId = id;
        _lastSegment = -1;
        var def = MotionConfig.exerciseAnim() ? ExercisePoseData.forExercise(id) : null;
        sampler = (def != null) ? new PoseSampler(def) : null;
        renderer.setStyle((MotionConfig.detail() == MotionConfig.DETAIL_LOW)
            ? FigureRenderer.SKELETAL : FigureRenderer.SILHOUETTE);
        renderer.setXray(SettingsRepository.figureXray());
    }

    //! Sample the figure for the step's elapsed time. Breath-synced movements
    //! get a haptic cue on each movement phase change (cat <-> cow).
    function update(engine as SessionEngine) as Void {
        if (sampler == null) {
            return;
        }
        sampler.sample(sideElapsedMs(engine), !MotionConfig.smooth());
        if (sampler.type() == PoseSampler.TYPE_BREATH_SYNC && engine.state == SessionEngine.RUNNING) {
            if (_lastSegment >= 0 && sampler.segment != _lastSegment) {
                HapticEngine.phaseCue();   // throttled: not every 4 s
            }
            _lastSegment = sampler.segment;
        }
    }

    //! Animation time: the step's elapsed time, restarted for the second side
    //! of an alternating exercise so the set-up plays again on the new side.
    function sideElapsedMs(engine as SessionEngine) as Number {
        var t = engine.stepElapsedMs;
        if (isMirrored(engine)) {
            t -= engine.stepDurationMs() / 2;
        }
        return (t < 0) ? 0 : t;
    }

    //! Right side of an alternating exercise: draw the figure mirrored.
    function isMirrored(engine as SessionEngine) as Boolean {
        var side = engine.currentSide();
        return side != null && side.equals(Models.TAG_RIGHT);
    }

    //! Horizontal offset (px) of the slide-in after an exercise starts.
    function slideOffset(nowMs as Number) as Number {
        return ((1.0 - _stepIn.value(nowMs)) * STEP_IN_PX).toNumber();
    }

    //! True when the screen has something moving and needs fast frames.
    function isAnimating(engine as SessionEngine, nowMs as Number) as Boolean {
        if (!MotionConfig.smooth()) {
            return false;
        }
        var st = engine.state;
        if (st == SessionEngine.COUNTDOWN) {
            return true;
        }
        if (st != SessionEngine.RUNNING) {
            return false;            // paused / waiting: frozen frame
        }
        if (_stepIn.isRunning(nowMs)) {
            return true;
        }
        if (sampler != null) {
            return !sampler.holding;  // a held pose does not need fast frames
        }
        var ex = engine.currentExercise();
        return ex != null && ex[ExerciseLibrary.F_TYPE] == Models.TYPE_BREATHING && MotionConfig.breathingAnim();
    }
}
