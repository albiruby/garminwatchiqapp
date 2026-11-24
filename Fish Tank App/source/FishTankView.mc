import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Frame interval tiers in ms (15, 12, 10 and 7.5 fps), see FishTankView.pace.
module FramePace {
    const TIERS = [66, 83, 100, 133];
}

// The aquarium screen. Also hosts the style/theme pickers (with a live preview of the
// tank behind them), reward cards, the tutorial coach and the decoration builder, so the
// tank stays visible behind everything.
class FishTankView extends WatchUi.View {
    var eng;
    var mode = 0;
    var focus = 0;
    var onboarding = false;
    var pickPos = 0;           // position in the picker's option list
    var buildSlot = 0;
    var _origStyle = 0;
    var _origTheme = 3;
    var _timer = null;
    var _frontRef = null;      // scene shown on screen
    var _backRef = null;       // scene being rebuilt (null if the graphics pool has no room)
    var _triedBack = false;
    var _building = false;
    var _stage = 0;
    var _haveScene = false;
    var _idle = 0.0;
    var _shown = false;
    var _previewScreen = 0;

    function initialize(engine) {
        View.initialize();
        eng = engine;
    }

    function onShow() as Void {
        applyTimer();
        if (!_shown) {
            _shown = true;
            if (Preview.ON) {
                if (Preview.MODE == Modes.STYLE) { enterPicker(Modes.STYLE, false); }
                else if (Preview.MODE == Modes.THEME) { enterPicker(Modes.THEME, false); }
                else if (Preview.MODE == 5) { enterBuild(); }
                else if (eng.cards.size() > 0) { mode = Modes.CARD; }
                _previewScreen = Preview.SCREEN;
                return;
            }
            if (eng.needsOnboarding()) { beginOnboarding(); }
            else if (eng.cards.size() > 0) { mode = Modes.CARD; }
        } else if (eng.needsOnboarding() && !onboarding) {
            beginOnboarding();
        } else if (mode == Modes.PLAY && eng.cards.size() > 0) {
            mode = Modes.CARD;
        }
    }

    function onHide() as Void {
        if (_timer != null) { _timer.stop(); }
        _interval = 0;          // onShow restarts the timer
        _lastMs = 0;
        eng.save();
    }

    function startTimer(ms) {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.stop();
        _timer.start(method(:onTick), ms, true);
    }

    // ---- frame pacing -------------------------------------------------------------
    // The frame interval adapts to the watch: the pacer measures how long each frame's
    // simulation and drawing really take and picks the fastest tier that leaves headroom,
    // so a quick watch gets fluid motion and a slower one (or a busy scene) never queues
    // frames. Motion advances by the real time between frames, so speed is the same at any
    // frame rate and a late frame no longer makes the fish jump or stall.
    const ACTIVE_S = 20.0;              // 15 fps only within this long after input
    const IDLE_S = 90.0;                // then 5 fps while nobody touches the watch
    const SLEEP_S = 300.0;              // and 2 fps after 5 minutes
    var _tier = 1;
    var _interval = 0;
    var _lastMs = 0;
    var _cost = 30.0;                   // smoothed ms of work per frame
    var _tickMs = 0;
    var _frames = 0;

    // Low Animation Mode runs the tank at 2 frames per second.
    function applyTimer() {
        var ms = 500;
        if (!eng.lowAnim && _idle <= SLEEP_S) {
            if (_idle > IDLE_S) {
                ms = 200;
            } else {
                var t = _tier;
                if (t == 0 && _idle > ACTIVE_S) { t = 1; }
                ms = FramePace.TIERS[t];
            }
        }
        if (ms != _interval) {
            _interval = ms;
            startTimer(ms);
        }
    }

    // Called after each drawn frame with the ms it cost (tick + draw).
    function pace(ms) {
        _cost = _cost * 0.9 + ms * 0.1;
        _frames += 1;
        if (_frames < 15) { return; }
        _frames = 0;
        var t = _tier;
        if (t < FramePace.TIERS.size() - 1 && _cost > FramePace.TIERS[t] * 0.6) { t += 1; }
        else if (t > 0 && _cost < FramePace.TIERS[t - 1] * 0.45) { t -= 1; }
        _tier = t;
        // even the slowest tier is tight: thin out ambient bubbles and sparkles
        var slow = FramePace.TIERS[FramePace.TIERS.size() - 1];
        if (_cost > slow * 0.6) { eng.fxLite = true; }
        else if (_cost < slow * 0.35) { eng.fxLite = false; }
        applyTimer();
    }

    function onTick() as Void {
        if (_previewScreen > 0) {
            var n = _previewScreen;
            _previewScreen = 0;
            PreviewScreens.open(n);
            return;
        }
        var t0 = System.getTimer();
        var dt = _lastMs > 0 ? (t0 - _lastMs) / 1000.0 : _interval / 1000.0;
        _lastMs = t0;
        var maxDt = _interval >= 200 ? 0.6 : 0.25;    // after a pause: no big jump
        if (dt > maxDt) { dt = maxDt; }
        if (dt < 0.01) { dt = 0.01; }
        eng.tick(dt);
        _idle += dt;
        _tickMs = System.getTimer() - t0;
        if (_idle > IDLE_S) { applyTimer(); }     // idle: slow down to save battery
        if (mode == Modes.PLAY && eng.tutorialActive()) {
            var tb = AquariumHUD.COACH_BTN[eng.tutorial];
            if (tb >= 0) { focus = tb; }
        }
        if (mode == Modes.PLAY && eng.cards.size() > 0 && !eng.tutorialActive()) {
            mode = Modes.CARD;
        }
        if (mode == Modes.CARD && eng.cards.size() > 0) {
            var c = eng.cards[0];
            if (c[:i] == RewardSystem.IC_FISH) { IconKit.warm(IconKit.FISH, c[:a]); }
        }
        WatchUi.requestUpdate();
    }

    // Input: back to full speed, and draw right away so taps feel instant.
    function poke() {
        _idle = 0.0;
        applyTimer();
        WatchUi.requestUpdate();
    }

    // ---- drawing ----------------------------------------------------------------
    function newBuffer(dc) {
        try {
            return Graphics.createBufferedBitmap({:width => dc.getWidth(), :height => dc.getHeight()});
        } catch (e) {
            return null;
        }
    }

    // Returns the scene bitmap to show. Rebuilds advance one stage per frame; with a back
    // buffer the old scene stays on screen until the new one is complete.
    function sceneBitmap(dc) {
        if (!(Graphics has :createBufferedBitmap)) { return null; }
        var front = _frontRef != null ? _frontRef.get() : null;
        if (front == null) {
            _frontRef = newBuffer(dc);
            front = _frontRef != null ? _frontRef.get() : null;
            if (front == null) { return null; }
            _haveScene = false;
            eng.sceneDirty = true;
        }
        if (!_triedBack) {
            _triedBack = true;
            _backRef = newBuffer(dc);
        }
        var back = _backRef != null ? _backRef.get() : null;

        if (eng.sceneDirty) {
            eng.sceneDirty = false;
            _building = true;
            _stage = 0;
        }
        if (_building) {
            var useBack = back != null && _haveScene;
            var target = useBack ? back : front;
            eng.renderer.drawStage(target.getDc(), eng, _stage);
            _stage += 1;
            if (_stage >= eng.renderer.stageCount(eng)) {
                _building = false;
                _haveScene = true;
                if (useBack) {
                    var tmp = _frontRef;
                    _frontRef = _backRef;
                    _backRef = tmp;
                    front = back;
                }
            }
        }
        return front;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var t0 = System.getTimer();
        var r = eng.renderer;
        var bmp = sceneBitmap(dc);
        if (bmp != null) {
            dc.drawBitmap(0, 0, bmp);
        } else {
            r.drawStage(dc, eng, 0);
        }

        for (var i = 0; i < eng.foods.size(); i++) { r.drawFood(dc, eng.foods[i]); }

        var list = eng.fishList();
        if (r.layered) {
            for (var i = 0; i < list.size(); i++) { if (list[i].z < 0.5) { r.drawFish(dc, list[i], eng); } }
            for (var i = 0; i < list.size(); i++) { if (list[i].z >= 0.5) { r.drawFish(dc, list[i], eng); } }
        } else {
            for (var i = 0; i < list.size(); i++) { r.drawFish(dc, list[i], eng); }
        }

        if (eng.visitor != null && eng.preview == null) { r.drawFish(dc, eng.visitor, eng); }
        for (var i = 0; i < eng.bubbles.size(); i++) { r.drawBubble(dc, eng.bubbles[i]); }
        r.drawFront(dc, eng);
        AquariumHUD.drawEffects(dc, eng);

        if (mode == Modes.PLAY) {
            AquariumHUD.drawPlay(dc, eng, focus);
        } else if (mode == Modes.CARD) {
            AquariumHUD.drawCard(dc, eng);
        } else if (mode == Modes.BUILD) {
            AquariumHUD.drawBuild(dc, eng, buildSlot);
        } else {
            var opts = options();
            var idx = mode == Modes.STYLE ? eng.style : eng.theme;
            AquariumHUD.drawPicker(dc, eng, mode, idx, pickPos, opts.size(), onboarding);
        }
        pace(System.getTimer() - t0 + _tickMs);
        _tickMs = 0;
    }

    // ---- pickers ------------------------------------------------------------------
    // Styles are all available; themes depend on the expedition.
    function options() {
        var out = [];
        if (mode == Modes.STYLE) {
            for (var i = 0; i < CustomizationManager.STYLE_COUNT; i++) { out.add(i); }
        } else {
            for (var i = 0; i < ThemeDatabase.COUNT; i++) {
                if (ExpeditionSystem.themeUnlocked(eng, i)) { out.add(i); }
            }
        }
        return out;
    }

    function beginOnboarding() {
        onboarding = true;
        mode = Modes.STYLE;
        pickPos = eng.style;
        eng.startPreview(eng.theme);
    }

    function enterPicker(m, ob) {
        onboarding = ob;
        mode = m;
        _origStyle = eng.style;
        _origTheme = eng.theme;
        var opts = options();
        var cur = m == Modes.STYLE ? eng.style : eng.theme;
        pickPos = opts.indexOf(cur);
        if (pickPos < 0) { pickPos = 0; }
        poke();
    }

    function stepPick(d) {
        var opts = options();
        var n = opts.size();
        pickPos = (pickPos + d + n) % n;
        if (mode == Modes.STYLE) {
            eng.setStyle(opts[pickPos]);
        } else {
            eng.setTheme(opts[pickPos]);
            if (onboarding) { eng.startPreview(opts[pickPos]); }
        }
    }

    function confirmPick() {
        if (onboarding && mode == Modes.STYLE) {
            mode = Modes.THEME;
            var opts = options();
            pickPos = opts.indexOf(eng.theme);
            if (pickPos < 0) { pickPos = 0; }
            return;
        }
        if (onboarding) {
            onboarding = false;
            mode = Modes.PLAY;
            eng.finishOnboarding();
            return;
        }
        var label = mode == Modes.STYLE ? CustomizationManager.STYLE_NAME[eng.style] : ThemeDatabase.NAME[eng.theme];
        mode = Modes.PLAY;
        eng.save();
        eng.toast(label + " - progress kept", 0x7FE7FF);
    }

    // Returns false when BACK should leave the app.
    function cancelPick() {
        if (onboarding) {
            if (mode == Modes.THEME) {
                mode = Modes.STYLE;
                pickPos = eng.style;
                return true;
            }
            return false;
        }
        eng.setStyle(_origStyle);
        eng.setTheme(_origTheme);
        mode = Modes.PLAY;
        return true;
    }

    // ---- build mode ---------------------------------------------------------------
    function enterBuild() {
        mode = Modes.BUILD;
        buildSlot = 0;
        poke();
    }

    function buildPick() {
        Nav.push(new DecorPickScreen(buildSlot));
    }

    // ---- cards ----------------------------------------------------------------------
    function nextCard() {
        if (eng.cards.size() > 0) { eng.cards = eng.cards.slice(1, null); }
        if (eng.cards.size() == 0) { mode = Modes.PLAY; }
    }

    // ---- input (called by FishTankDelegate) ------------------------------------
    function openMenu() {
        eng.tutorialEvent(3);
        Nav.push(new MainScreen());
    }

    function activate(i) {
        focus = i;
        if (i == 0) { eng.feedAt(Util.rf(130.0, 260.0), 100.0); }
        else if (i == 1) { eng.startClean(); }
        else { openMenu(); }
    }

    function handleTap(x, y) {
        poke();
        if (mode == Modes.CARD) { nextCard(); return; }
        if (mode == Modes.BUILD) {
            var n = HabitatSystem.slotCount(eng);
            for (var i = 0; i < n; i++) {
                var dx = x - ItemDatabase.SLOT_X[i];
                var dy = y - (eng.renderer.slotBottom(eng, i) - 26);
                if (dx * dx + dy * dy < 36 * 36) {
                    if (i == buildSlot) { buildPick(); } else { buildSlot = i; }
                    return;
                }
            }
            if (y < 140) { buildPick(); }
            return;
        }
        if (mode != Modes.PLAY) {
            if (x < 110) { stepPick(-1); }
            else if (x > 280) { stepPick(1); }
            else { confirmPick(); }
            return;
        }
        if (eng.tutorialActive() && eng.tutorial == 2) { eng.tutorialEvent(2); return; }
        for (var i = 0; i < 3; i++) {
            var dx = x - AquariumHUD.BTN_X[i];
            var dy = y - AquariumHUD.BTN_Y;
            var hr = AquariumHUD.BTN_R + 3;
            if (dx * dx + dy * dy < hr * hr) {
                activate(i);
                return;
            }
        }
        var f = eng.fishAt(x, y);
        if (f != null) {
            eng.showInfo(f);
            return;
        }
        if (eng.tapFeed && y > 80 && y < eng.renderer.floorY) {
            eng.feedAt(x, y);
        }
    }

    function handleSelect() {
        poke();
        if (mode == Modes.CARD) { nextCard(); }
        else if (mode == Modes.BUILD) { buildPick(); }
        else if (mode == Modes.PLAY) {
            if (eng.tutorialActive() && eng.tutorial == 2) { eng.tutorialEvent(2); return; }
            activate(focus);
        }
        else { confirmPick(); }
    }

    function handleStep(d) {
        poke();
        if (mode == Modes.PLAY) {
            focus = (focus + d + 3) % 3;
        } else if (mode == Modes.BUILD) {
            var n = HabitatSystem.slotCount(eng);
            buildSlot = (buildSlot + d + n) % n;
        } else if (mode != Modes.CARD) {
            stepPick(d);
        }
    }

    function handleSwipe(dir) {
        poke();
        if (mode == Modes.PLAY) {
            if (dir == WatchUi.SWIPE_UP) {
                openMenu();
                return true;
            }
            return false;
        }
        if (mode == Modes.CARD || mode == Modes.BUILD) { return true; }
        if (dir == WatchUi.SWIPE_LEFT || dir == WatchUi.SWIPE_UP) { stepPick(1); }
        else { stepPick(-1); }
        return true;
    }

    function handleMenu() {
        poke();
        if (mode == Modes.PLAY) { openMenu(); }
    }

    function handleBack() {
        poke();
        if (mode == Modes.CARD) { nextCard(); return true; }
        if (mode == Modes.BUILD) { mode = Modes.PLAY; eng.save(); return true; }
        if (mode != Modes.PLAY) { return cancelPick(); }
        eng.save();
        return false;
    }
}
