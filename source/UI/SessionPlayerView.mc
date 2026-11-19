import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

//! Active session: exercise, timer, breathing circle, side indicator,
//! progress ring. One 1 s timer drives redraws; elapsed time comes from
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

    function onUpdate(dc as Graphics.Dc) as Void {
        var cx = DeviceProfile.centerX(dc);
        var cy = DeviceProfile.centerY(dc);
        var h = dc.getHeight();
        var radius = (dc.getWidth() < h ? dc.getWidth() : h) / 2;
        dc.setColor(DeviceProfile.COLOR_TEXT, DeviceProfile.COLOR_BG);
        dc.clear();

        drawProgressRing(dc, cx, cy, radius - 6);

        var st = _engine.state;
        if (st == SessionEngine.COUNTDOWN || (st == SessionEngine.PAUSED && _engine.countdownMs > 0)) {
            dc.setColor(DeviceProfile.COLOR_SAGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 28 / 100, Graphics.FONT_TINY, "Get ready", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(DeviceProfile.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_NUMBER_HOT, ((_engine.countdownMs + 999) / 1000).toString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            drawPaused(dc, cx, h);
            return;
        }

        var ex = _engine.currentExercise();
        if (ex == null) {
            return;
        }
        var steps = _engine.steps;
        dc.setColor(DeviceProfile.COLOR_SAGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 12 / 100, Graphics.FONT_XTINY,
            (_engine.stepIndex + 1).toString() + "/" + steps.size(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(DeviceProfile.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        // Round screen: long names drop to a smaller font so they are not clipped.
        var name = ex[ExerciseLibrary.F_NAME];
        var nameFont = (dc.getTextWidthInPixels(name, Graphics.FONT_SMALL) > dc.getWidth() * 70 / 100)
            ? Graphics.FONT_XTINY : Graphics.FONT_SMALL;
        dc.drawText(cx, h * 19 / 100, nameFont, name, Graphics.TEXT_JUSTIFY_CENTER);

        if (ex[ExerciseLibrary.F_TYPE] == Models.TYPE_BREATHING) {
            drawBreathing(dc, cx, cy, radius, ex[ExerciseLibrary.F_PATTERN]);
        } else {
            dc.setColor(DeviceProfile.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - h * 4 / 100, Graphics.FONT_NUMBER_MEDIUM,
                TimeFormatter.clock((_engine.stepRemainingMs() + 999) / 1000),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            var side = _engine.currentSide();
            if (side != null) {
                dc.setColor(DeviceProfile.COLOR_SAGE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, cy + h * 9 / 100, Graphics.FONT_TINY,
                    side.equals(Models.TAG_LEFT) ? "LEFT SIDE" : "RIGHT SIDE", Graphics.TEXT_JUSTIFY_CENTER);
            }
            dc.setColor(DeviceProfile.COLOR_DIM, Graphics.COLOR_TRANSPARENT);
            var cue = Graphics.fitTextToArea(ex[ExerciseLibrary.F_CUE], Graphics.FONT_XTINY, dc.getWidth() * 70 / 100, h * 12 / 100, true);
            dc.drawText(cx, h * 66 / 100, Graphics.FONT_XTINY, cue, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (st == SessionEngine.AWAITING_NEXT) {
            dc.setColor(DeviceProfile.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 80 / 100, Graphics.FONT_XTINY, "START for next", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(DeviceProfile.COLOR_DIM, Graphics.COLOR_TRANSPARENT);
            var left = _engine.plannedSeconds() - _engine.activeMs / 1000;
            dc.drawText(cx, h * 80 / 100, Graphics.FONT_XTINY, TimeFormatter.clock(left > 0 ? left : 0) + " left",
                Graphics.TEXT_JUSTIFY_CENTER);
        }
        drawPaused(dc, cx, h);
    }

    hidden function drawPaused(dc as Graphics.Dc, cx as Number, h as Number) as Void {
        if (_engine.state == SessionEngine.PAUSED) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 87 / 100, Graphics.FONT_XTINY, "PAUSED", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawProgressRing(dc as Graphics.Dc, cx as Number, cy as Number, r as Number) as Void {
        dc.setPenWidth(4);
        dc.setColor(DeviceProfile.COLOR_FOREST, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
        var p = _engine.progressPercent();
        if (p > 0) {
            dc.setColor(DeviceProfile.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
            if (p >= 100) {
                dc.drawCircle(cx, cy, r);
            } else {
                dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, 90 - 360 * p / 100);
            }
        }
        dc.setPenWidth(1);
    }

    //! Circle grows on inhale, holds, shrinks on exhale, rests small on pause.
    hidden function drawBreathing(dc as Graphics.Dc, cx as Number, cy as Number, radius as Number, pattern) as Void {
        var labels = ["INHALE", "HOLD", "EXHALE", "PAUSE"];
        var phase = _engine.breathingPhase();
        var remainMs = BreathingCalculator.phaseRemainingMs(pattern, _engine.stepElapsedMs);
        if (phase == null || remainMs == null) {
            return;
        }
        var phaseMs = pattern[phase] * 1000;
        var frac = (phaseMs > 0) ? (phaseMs - remainMs) * 100 / phaseMs : 100; // 0..100 through phase
        var rMin = radius * 18 / 100;
        var rMax = radius * 48 / 100;
        var r = rMin;
        if (phase == 0) {
            r = rMin + (rMax - rMin) * frac / 100;
        } else if (phase == 1) {
            r = rMax;
        } else if (phase == 2) {
            r = rMax - (rMax - rMin) * frac / 100;
        }
        dc.setColor(DeviceProfile.COLOR_FOREST, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy + radius * 6 / 100, r);
        dc.setColor(DeviceProfile.COLOR_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy + radius * 6 / 100, r);
        dc.setPenWidth(1);
        dc.setColor(DeviceProfile.COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - radius * 6 / 100, Graphics.FONT_SMALL, labels[phase], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx, cy + radius * 14 / 100, Graphics.FONT_MEDIUM, ((remainMs + 999) / 1000).toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
