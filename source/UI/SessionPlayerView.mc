import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

//! Active session HUD. One 1 s timer drives redraws; elapsed time comes from
//! System.getTimer() deltas inside SessionEngine.
class SessionPlayerView extends WatchUi.View {

    const MIN_SAVE_SECONDS = 10; // don't log accidental starts

    hidden var _engine as SessionEngine;
    hidden var _timer;
    hidden var _startEpoch as Number = 0;
    hidden var _hrBefore = null;
    hidden var _finished as Boolean = false;

    function initialize(id, def) {
        View.initialize();
        _engine = new SessionEngine(id, def, SettingsRepository.countdownSec(), SettingsRepository.autoAdvance());
        _hrBefore = SensorManager.snapshotHr();
        _startEpoch = Time.now().value();
        HapticEngine.single();
        handle(_engine.start(System.getTimer()));
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
    }

    function engine() as SessionEngine {
        return _engine;
    }

    function onTick() as Void {
        handle(_engine.tick(System.getTimer()));
    }

    //! Apply engine events: haptics, redraw, and finish when done.
    function handle(evt as Number) as Void {
        HapticEngine.forEvents(evt);
        if (_engine.isFinished()) {
            finish();
        } else {
            WatchUi.requestUpdate();
        }
    }

    hidden function finish() as Void {
        if (_finished) {
            return;
        }
        _finished = true;
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
        var record = _engine.buildRecord(_startEpoch, _hrBefore, SensorManager.snapshotHr());
        var saved = false;
        if (_engine.state == SessionEngine.COMPLETED || record.get(Models.K_DUR) >= MIN_SAVE_SECONDS) {
            saved = HistoryRepository.append(record);
        }
        var summary = new SessionSummaryView(record, _engine.def, saved);
        WatchUi.switchToView(summary, new SessionSummaryDelegate(), WatchUi.SLIDE_LEFT);
    }

    // ---- Session HUD -------------------------------------------------------
    // 390-px grid. Rings: bezel r190 (steps), r177 (breathing phases).
    // All text stays inside Theme.SAFE_HUD (r160), >= 13 px clear of the rings.
    //    56  STEP 04/05              (label, sage)
    //    79  EXERCISE NAME           (body, shrinks to label if long)
    //   114  ---- hairline ----
    //   117  INHALE                  (title, breathing only)
    //   114 / 134  hero timer        (80 px mono; ink 140-199 / 160-219)
    //   208  HOLD POSITION / RIGHT SIDE
    //   228  cue | NEXT: X | PAUSED | START: NEXT
    //   260  ---- hairline ----
    //   266/285  LEFT 04:24 | DONE 56%   (label over body value)
    //   324  haptic mark

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.IVORY, Theme.BG);
        dc.clear();
        var st = _engine.state;
        var counting = (st == SessionEngine.COUNTDOWN) || (st == SessionEngine.PAUSED && _engine.countdownMs > 0);
        var paused = (st == SessionEngine.PAUSED);
        var heroColor = paused ? Theme.GREY : Theme.IVORY;
        var safe = Theme.SAFE_HUD;

        drawStepRing(dc);

        var steps = _engine.steps;
        var ex = _engine.currentExercise();
        var top = counting ? "GET READY"
            : "STEP " + (_engine.stepIndex + 1).format("%02d") + "/" + steps.size().format("%02d");
        Theme.fitLine(dc, Theme.px(dc, 56), top, Theme.label(), null, safe, Theme.SAGE);
        if (ex != null) {
            Theme.fitLine(dc, Theme.px(dc, 79), ex[ExerciseLibrary.F_NAME].toUpper(), Theme.body(), Theme.label(), safe, Theme.IVORY);
        }
        Theme.divider(dc, Theme.px(dc, 114), safe, 0);

        if (counting) {
            heroText(dc, 114, ((_engine.countdownMs + 999) / 1000).toString(), heroColor);
            statusRow(dc, paused ? "PAUSED" : "START TO PAUSE", paused ? Theme.AMBER : Theme.GREY);
            bottom(dc, "STEPS", steps.size().toString(), "TOTAL", Hud.mmss(_engine.plannedSeconds()));
            return;
        }
        if (ex == null) {
            return;
        }

        var remainingStep = (_engine.stepRemainingMs() + 999) / 1000;
        var sessionLeft = _engine.plannedSeconds() - _engine.activeMs / 1000;

        if (ex[ExerciseLibrary.F_TYPE] == Models.TYPE_BREATHING) {
            var pattern = ex[ExerciseLibrary.F_PATTERN];
            var phase = _engine.breathingPhase();
            var remainMs = BreathingCalculator.phaseRemainingMs(pattern, _engine.stepElapsedMs);
            drawPhaseRing(dc, pattern, phase, remainMs);
            var words = ["INHALE", "HOLD", "EXHALE", "HOLD"];
            Theme.centerText(dc, Theme.px(dc, 117), Theme.title(), paused ? Theme.GREY : Theme.MINT,
                (phase == null) ? "" : words[phase]);
            var phaseSec = ((remainMs == null) ? 0 : remainMs + 999) / 1000;
            heroText(dc, 134, phaseSec.format("%02d"), heroColor);
            var cycles = _engine.cycles;
            var cur = BreathingCalculator.completedCycles(pattern, _engine.stepElapsedMs);
            if (cur != null) {
                cycles += cur;
            }
            stateRow(dc, st, remainingStep,
                "PATTERN " + pattern[0] + "-" + pattern[1] + "-" + pattern[2] + "-" + pattern[3]);
            bottom(dc, "CYCLES", cycles.format("%02d"), "LEFT", Hud.mmss(sessionLeft));
        } else {
            heroText(dc, 114, Hud.mmss(remainingStep), heroColor);
            var side = _engine.currentSide();
            var typeLabel = typeName(ex[ExerciseLibrary.F_TYPE]);
            if (side != null) {
                typeLabel = side.equals(Models.TAG_LEFT) ? "LEFT SIDE" : "RIGHT SIDE";
            }
            Theme.centerText(dc, Theme.px(dc, 208), Theme.label(), (side != null) ? Theme.MINT : Theme.SAGE, typeLabel);
            stateRow(dc, st, remainingStep, ex[ExerciseLibrary.F_CUE]);
            bottom(dc, "LEFT", Hud.mmss(sessionLeft), "DONE", _engine.progressPercent().toString() + "%");
        }
        if (st == SessionEngine.AWAITING_NEXT) {
            Theme.startHint(dc);
        }
    }

    hidden function heroText(dc as Graphics.Dc, y as Number, s as String, color as Number) as Void {
        Theme.centerText(dc, Theme.px(dc, y), Theme.hero(), color, s);
    }

    hidden function bottom(dc as Graphics.Dc, l1 as String, v1 as String, l2 as String, v2 as String) as Void {
        Theme.divider(dc, Theme.px(dc, 260), Theme.SAFE_HUD, 0);
        Hud.fieldPair(dc, 266, 285, 52, l1, v1, l2, v2, Theme.body());
        Hud.hapticMark(dc, 324);
    }

    //! Row under the timer: PAUSED / START: NEXT / NEXT: X (last 10 s) / info.
    hidden function stateRow(dc as Graphics.Dc, st as Number, remainingStep as Number, info as String) as Void {
        if (st == SessionEngine.PAUSED) {
            statusRow(dc, "PAUSED", Theme.AMBER);
        } else if (st == SessionEngine.AWAITING_NEXT) {
            statusRow(dc, "START: NEXT", Theme.MINT);
        } else if (remainingStep <= 10 && nextName() != null) {
            statusRow(dc, "NEXT: " + nextName(), Theme.MINT);
        } else {
            statusRow(dc, info, Theme.GREY);
        }
    }

    hidden function statusRow(dc as Graphics.Dc, s as String, color as Number) as Void {
        Theme.fitLine(dc, Theme.px(dc, 228), s.toUpper(), Theme.label(), null, Theme.SAFE_HUD, color);
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
        var names = ["BREATHING", "HOLD POSITION", "REPEAT GENTLY", "ALTERNATE SIDES", "INTERVAL", "REST", "TRANSITION"];
        return (type >= 0 && type < names.size()) ? names[type] : "";
    }

    //! Bezel: one segment per exercise, sized by duration.
    hidden function drawStepRing(dc as Graphics.Dc) as Void {
        var steps = _engine.steps;
        var weights = new [steps.size()];
        for (var i = 0; i < steps.size(); i++) {
            weights[i] = steps[i][1];
        }
        var dur = _engine.stepDurationMs();
        var permille = (dur > 0) ? (_engine.stepElapsedMs * 1000 / dur) : 0;
        var active = _engine.isFinished() ? steps.size() : _engine.stepIndex;
        if (_engine.state == SessionEngine.COUNTDOWN) {
            permille = 0;
        }
        Hud.segmentRing(dc, weights, active, permille, Hud.BEZEL_R, 6,
            (_engine.state == SessionEngine.PAUSED) ? Theme.AMBER : Theme.SAGE);
    }

    //! Inner ring for breathing: segments = phase lengths, active phase fills.
    hidden function drawPhaseRing(dc as Graphics.Dc, pattern, phase, remainMs) as Void {
        if (phase == null || remainMs == null) {
            return;
        }
        var phaseMs = pattern[phase] * 1000;
        var permille = (phaseMs > 0) ? (phaseMs - remainMs) * 1000 / phaseMs : 1000;
        Hud.segmentRing(dc, pattern, phase, permille, Hud.PHASE_R, 8,
            (_engine.state == SessionEngine.PAUSED) ? Theme.AMBER : Theme.MINT);
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
