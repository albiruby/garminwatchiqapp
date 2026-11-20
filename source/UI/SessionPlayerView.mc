import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

//! Active session HUD. A FrameClock drives redraws: 1 s when nothing moves,
//! 125/250 ms while something animates (MotionConfig). Elapsed time always
//! comes from System.getTimer() deltas inside SessionEngine, so the frame
//! rate never changes session timing.
class SessionPlayerView extends WatchUi.View {

    const MIN_SAVE_SECONDS = 10; // don't log accidental starts

    hidden var _engine as SessionEngine;
    hidden var _clock as FrameClock;
    hidden var _motion as MotionController;
    hidden var _visible as Boolean = true;
    hidden var _weights as Array;        // step durations for the segmented bar (cached)
    hidden var _single as Array = [1];   // one-segment ring (cached)
    hidden var _startEpoch as Number = 0;
    hidden var _hrBefore = null;
    hidden var _finished as Boolean = false;

    function initialize(id, def) {
        View.initialize();
        _engine = new SessionEngine(id, def, SettingsRepository.countdownSec(), SettingsRepository.autoAdvance());
        _hrBefore = SensorManager.snapshotHr();
        _startEpoch = Time.now().value();
        _weights = new [_engine.steps.size()];
        for (var i = 0; i < _weights.size(); i++) {
            _weights[i] = _engine.steps[i][1];
        }
        _motion = new MotionController();
        _clock = new FrameClock(method(:onTick));
        handle(_engine.start(System.getTimer()));
    }

    function onShow() as Void {
        _visible = true;
        schedule(System.getTimer());
    }

    //! Hidden (e.g. a notification): keep the session running at 1 s, no animation.
    function onHide() as Void {
        _visible = false;
        if (!_finished) {
            _clock.setInterval(MotionConfig.FRAME_IDLE_MS);
        }
    }

    hidden function schedule(nowMs as Number) as Void {
        if (_finished) {
            return;
        }
        _clock.setInterval(MotionConfig.frameMs(_visible && _motion.isAnimating(_engine, nowMs)));
    }

    function engine() as SessionEngine {
        return _engine;
    }

    function onTick() as Void {
        handle(_engine.tick(System.getTimer()));
    }

    //! Apply engine events: motion + haptics, redraw, and finish when done.
    function handle(evt as Number) as Void {
        var now = System.getTimer();
        _motion.onEvents(_engine, evt, now);
        if (_engine.isFinished()) {
            finish();
        } else {
            schedule(now);
            WatchUi.requestUpdate();
        }
    }

    hidden function finish() as Void {
        if (_finished) {
            return;
        }
        _finished = true;
        _clock.stop();
        var record = _engine.buildRecord(_startEpoch, _hrBefore, SensorManager.snapshotHr());
        var saved = false;
        if (_engine.state == SessionEngine.COMPLETED || record.get(Models.K_DUR) >= MIN_SAVE_SECONDS) {
            saved = HistoryRepository.append(record);
        }
        var summary = new SessionSummaryView(record, _engine.def, saved);
        WatchUi.switchToView(summary, new SessionSummaryDelegate(), WatchUi.SLIDE_LEFT);
    }

    // ---- Session HUD -------------------------------------------------------
    // 390-px grid, safe circle r160 (Theme.SAFE_HUD):
    //    34  clock                       54  exercise name (green)
    //   ring r88 around y186: phases (breathing) or step progress
    //   inside: 120 marker / 128-132 phase or type / 150-162 timer / 218 side
    //   animated exercise: figure centred at y150, timer (40 px) 194, label 236
    //   breathing: pulse disc r46..r76 behind the phase word and number
    //   286 state line (cue | Next: X | PAUSED | START: next)
    //   308 info row: icon + pattern or session time left, step n/N
    //   336 segmented bar, one segment per exercise

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.WHITE, Theme.BG);
        dc.clear();
        var st = _engine.state;
        var counting = (st == SessionEngine.COUNTDOWN) || (st == SessionEngine.PAUSED && _engine.countdownMs > 0);
        var paused = (st == SessionEngine.PAUSED);
        var safe = Theme.SAFE_HUD;
        var steps = _engine.steps;
        var ex = _engine.currentExercise();
        var ringCy = Theme.px(dc, Hud.RING_CY);
        var ringColor = paused ? Theme.AMBER : Theme.GREEN;
        var heroColor = paused ? Theme.GREY : Theme.WHITE;
        var breathing = !counting && ex != null && ex[ExerciseLibrary.F_TYPE] == Models.TYPE_BREATHING;
        var pattern = breathing ? ex[ExerciseLibrary.F_PATTERN] : null;
        var stepDur = _engine.stepDurationMs();
        var stepPermille = (stepDur > 0 && !counting) ? _engine.stepElapsedMs * 1000 / stepDur : 0;
        var now = System.getTimer();
        _motion.update(_engine);

        Theme.centerText(dc, Theme.px(dc, 34), Theme.label(), Theme.SOFT, Theme.clock());
        var title = counting ? "Get ready" : ((ex != null) ? ex[ExerciseLibrary.F_NAME] : "");
        Theme.fitLine(dc, Theme.px(dc, 54), title, Theme.title(), Theme.body(), safe, Theme.GREEN);

        var remainingStep = (_engine.stepRemainingMs() + 999) / 1000;
        var sessionLeft = _engine.plannedSeconds() - _engine.activeMs / 1000;

        if (counting) {
            // the ring sweeps through each countdown second
            var sweep = MotionConfig.smooth() ? (1000 - _engine.countdownMs % 1000) % 1000 : 0;
            Hud.segmentRing(dc, ringCy, _single, 0, sweep, Hud.RING_R, Hud.RING_PEN, ringColor);
            Theme.centerText(dc, Theme.px(dc, 128), Theme.label(), Theme.GREY, "STARTS IN");
            Theme.centerText(dc, Theme.px(dc, 150), Theme.hero(), heroColor,
                ((_engine.countdownMs + 999) / 1000).toString());
            var first = _engine.currentExercise();
            stateLine(dc, paused ? "PAUSED" : ((first != null) ? first[ExerciseLibrary.F_NAME] : ""),
                paused ? Theme.AMBER : Theme.GREY);
            infoRow(dc, Icons.CLOCK, Hud.mmss(_engine.plannedSeconds()));
            Hud.segmentBar(dc, Theme.px(dc, 336), Theme.px(dc, 56), _weights, 0, 0);
            return;
        }
        if (ex == null) {
            return;
        }

        if (breathing) {
            var phase = _engine.breathingPhase();
            var remainMs = BreathingCalculator.phaseRemainingMs(pattern, _engine.stepElapsedMs);
            var phaseMs = (phase == null) ? 0 : pattern[phase] * 1000;
            var phasePermille = (phaseMs > 0 && remainMs != null) ? (phaseMs - remainMs) * 1000 / phaseMs : 0;
            Hud.segmentRing(dc, ringCy, pattern, (phase == null) ? 0 : phase, phasePermille,
                Hud.RING_R, Hud.RING_PEN, ringColor);
            if (phase != null && MotionConfig.breathingAnim()) {
                var k = MotionConfig.smooth() ? phasePermille : 1000;
                BreathingPulse.draw(dc, Theme.cx(dc), ringCy,
                    BreathingPulse.radius(phase, k, Theme.px(dc, 46), Theme.px(dc, 76)));
            }
            if (phase == 0 || phase == 2) {
                Icons.draw(dc, (phase == 0) ? Icons.UP : Icons.DOWN, Theme.cx(dc), Theme.px(dc, 120), Theme.px(dc, 10),
                    paused ? Theme.GREY : Theme.GREEN);
            }
            var words = ["Inhale", "Hold", "Exhale", "Hold"];
            Theme.centerText(dc, Theme.px(dc, 132), Theme.title(), Theme.WHITE, (phase == null) ? "" : words[phase]);
            var phaseSec = ((remainMs == null) ? 0 : remainMs + 999) / 1000;
            Theme.centerText(dc, Theme.px(dc, 162), Theme.hero(), heroColor, phaseSec.toString());
            stateRow(dc, st, remainingStep, ex[ExerciseLibrary.F_CUE]);
            infoRow(dc, Icons.LUNGS, pattern[0].toString() + "-" + pattern[1] + "-" + pattern[2] + "-" + pattern[3]);
        } else if (_motion.sampler != null) {
            drawExercise(dc, st, ringCy, ringColor, heroColor, stepPermille, remainingStep, now);
            infoRow(dc, Icons.CLOCK, Hud.mmss(sessionLeft));
        } else {
            Hud.segmentRing(dc, ringCy, _single, 0, stepPermille, Hud.RING_R, Hud.RING_PEN, ringColor);
            Theme.centerText(dc, Theme.px(dc, 128), Theme.label(), Theme.GREEN, typeName(ex[ExerciseLibrary.F_TYPE]));
            Theme.centerText(dc, Theme.px(dc, 150), Theme.hero(), heroColor, Hud.mmss(remainingStep));
            var side = _engine.currentSide();
            if (side != null) {
                Theme.centerText(dc, Theme.px(dc, 218), Theme.label(), Theme.WHITE,
                    side.equals(Models.TAG_LEFT) ? "LEFT" : "RIGHT");
            }
            stateRow(dc, st, remainingStep, ex[ExerciseLibrary.F_CUE]);
            infoRow(dc, Icons.CLOCK, Hud.mmss(sessionLeft));
        }
        Hud.segmentBar(dc, Theme.px(dc, 336), Theme.px(dc, 56), _weights, _engine.stepIndex, stepPermille);
        if (st == SessionEngine.AWAITING_NEXT) {
            Theme.startHint(dc);
        }
    }

    //! Animated exercise inside the ring: figure, step timer, phase label.
    hidden function drawExercise(dc as Graphics.Dc, st as Number, ringCy as Number, ringColor as Number,
            heroColor as Number, stepPermille as Number, remainingStep as Number, now as Number) as Void {
        var sampler = _motion.sampler;
        Hud.segmentRing(dc, ringCy, _single, 0, stepPermille, Hud.RING_R, Hud.RING_PEN, ringColor);
        var mirror = _motion.isMirrored(_engine);
        var slide = _motion.slideOffset(now);
        var pxScale = dc.getHeight() / 390.0;
        _motion.renderer.draw(dc, sampler, Theme.cx(dc) + (mirror ? -slide : slide), Theme.px(dc, 150), pxScale,
            mirror, st != SessionEngine.PAUSED);
        Theme.centerText(dc, Theme.px(dc, 194), Theme.num(), heroColor, Hud.mmss(remainingStep));
        var label = sampler.label();
        var type = sampler.type();
        if (type == PoseSampler.TYPE_REPETITION || type == PoseSampler.TYPE_BREATH_SYNC) {
            label = label + " · " + (sampler.reps + 1).toString();
        }
        var side = _engine.currentSide();
        if (side != null) {
            label = label + " · " + (side.equals(Models.TAG_LEFT) ? "L" : "R");
        }
        Theme.centerText(dc, Theme.px(dc, 236), Theme.label(), Theme.GREEN, label);
        stateRow(dc, st, remainingStep, sampler.def[:cue]);
    }

    //! Info row: green icon + value on the left, step n/N on the right.
    hidden function infoRow(dc as Graphics.Dc, iconId as Number, value as String) as Void {
        var y = Theme.px(dc, 308);
        var leftX = Theme.cx(dc) - Theme.px(dc, 70);
        Icons.draw(dc, iconId, leftX, y + Theme.px(dc, 9), Theme.px(dc, 14), Theme.GREEN);
        Theme.text(dc, leftX + Theme.px(dc, Theme.SP_L), y, Theme.body(), Theme.WHITE, value, Graphics.TEXT_JUSTIFY_LEFT);
        var step = (_engine.stepIndex + 1).toString() + "/" + _engine.steps.size().toString();
        Theme.text(dc, Theme.cx(dc) + Theme.px(dc, 74), y, Theme.body(), Theme.WHITE, step, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    //! State line: PAUSED / START: next / Next: X (last 10 s) / cue.
    hidden function stateRow(dc as Graphics.Dc, st as Number, remainingStep as Number, info as String) as Void {
        if (st == SessionEngine.PAUSED) {
            stateLine(dc, "PAUSED", Theme.AMBER);
        } else if (st == SessionEngine.AWAITING_NEXT) {
            stateLine(dc, "START: next exercise", Theme.GREEN);
        } else if (remainingStep <= 10 && nextName() != null) {
            stateLine(dc, "Next: " + nextName(), Theme.GREEN);
        } else {
            stateLine(dc, info, Theme.GREY);
        }
    }

    hidden function stateLine(dc as Graphics.Dc, s as String, color as Number) as Void {
        Theme.fitLine(dc, Theme.px(dc, 286), s, Theme.small(), null, Theme.SAFE_HUD, color);
    }

    hidden function nextName() {
        var i = _engine.stepIndex + 1;
        if (i >= _engine.steps.size()) {
            return null;
        }
        var ex = ExerciseLibrary.get(_engine.steps[i][0]);
        return (ex == null) ? null : ex[ExerciseLibrary.F_NAME];
    }

    hidden function typeName(type as Number) as String {
        var names = ["BREATHING", "HOLD", "REPEAT", "ALTERNATE", "INTERVAL", "REST", "TRANSITION"];
        return (type >= 0 && type < names.size()) ? names[type] : "";
    }
}

//! START: pause/resume (or next in manual mode). DOWN: skip exercise.
//! BACK: confirm ending the session.
class SessionPlayerDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view as SessionPlayerView;

    function initialize(view as SessionPlayerView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        var e = _view.engine();
        var now = System.getTimer();
        _view.handle((e.state == SessionEngine.AWAITING_NEXT) ? e.next(now) : e.togglePause(now));
        return true;
    }

    function onNextPage() as Boolean {
        _view.handle(_view.engine().skip(System.getTimer()));
        return true;
    }

    function onBack() as Boolean {
        WatchUi.pushView(new WatchUi.Confirmation("End session?"), new EndSessionDelegate(_view), WatchUi.SLIDE_UP);
        return true;
    }
}

class EndSessionDelegate extends WatchUi.ConfirmationDelegate {

    hidden var _view as SessionPlayerView;

    function initialize(view as SessionPlayerView) {
        ConfirmationDelegate.initialize();
        _view = view;
    }

    //! The engine is cancelled here; the player's next timer tick (after the
    //! confirmation has closed) saves the record and shows the summary.
    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            _view.engine().cancel(System.getTimer());
        }
        return true;
    }
}
