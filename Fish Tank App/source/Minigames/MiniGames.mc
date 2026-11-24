import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

module MiniGameRules {
    const DAILY = 3;     // rewarded plays per game per day
}

// Shared frame for the mini-games: intro card -> play -> result card.
class MiniGameView extends WatchUi.View {
    const P_INTRO = 0;
    const P_PLAY = 1;
    const P_RESULT = 2;
    var phase = 0;
    var gameId = "";
    var resultTitle = "";
    var resultBig = "";
    var resultLine = "";
    var _timer = null;
    var t = 0.0;
    var rewarded = false;   // this round pays (a daily play was used when it started)
    var _last = 0;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _last = 0;
        _timer.start(method(:onTick), 80, true);
    }

    function onHide() as Void {
        if (_timer != null) { _timer.stop(); }
    }

    // Game time follows the real clock, so a slow frame does not stretch a timed round;
    // a pause (notification, hidden view) is capped so nothing jumps.
    function onTick() as Void {
        var now = System.getTimer();
        var dt = _last > 0 ? (now - _last) / 1000.0 : 0.08;
        _last = now;
        if (dt > 0.2) { dt = 0.2; }
        if (dt < 0.01) { dt = 0.01; }
        t += dt;
        if (phase == P_PLAY) { update(dt); }
        else { warm(); }
        WatchUi.requestUpdate();
    }

    // overridden
    function update(dt) {
    }

    function warm() {
    }

    function name() {
        return "";
    }

    function rules() {
        return ["", ""];
    }

    function drawPlay(dc) {
    }

    function start() {
        phase = P_PLAY;
        t = 0.0;
        rewarded = Preview.ON ? false : Globals.engine.startGame(gameId);
    }

    // Pays through the engine's daily limit and shows the result card.
    function finish(title, coins, xp, line) {
        phase = P_RESULT;
        var paid = Globals.engine.finishGame(gameId, coins, xp, rewarded);
        resultTitle = title;
        resultBig = paid && coins > 0 ? "+" + coins.toString() + " coins" : (paid ? "No coins" : "Practice round");
        resultLine = paid ? line : "Daily rewards used - come back tomorrow";
        Util.buzz(Globals.engine, 150);
    }

    // input hooks
    function tap(x, y) {
        if (phase == P_INTRO) { start(); }
        else if (phase == P_RESULT) { Nav.pop(); }
        else { playTap(x, y); }
    }

    function action() {
        if (phase == P_INTRO) { start(); }
        else if (phase == P_RESULT) { Nav.pop(); }
        else { playAction(); }
    }

    function step(d) {
        if (phase == P_PLAY) { playStep(d); }
    }

    function playTap(x, y) {
    }

    function playAction() {
    }

    function playStep(d) {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        UIKit.background(dc);
        if (phase == P_PLAY) {
            drawPlay(dc);
            return;
        }
        UIKit.titlePill(dc, name(), UIKit.ACCENT);
        var cx = dc.getWidth() / 2;
        dc.setColor(UIKit.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(60, 110, 270, 170, 18);
        dc.setColor(phase == P_RESULT ? UIKit.GOLD : UIKit.BORDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(60, 110, 270, 170, 18);
        dc.setPenWidth(1);
        if (phase == P_INTRO) {
            var r = rules();
            var nf = UIKit.bestFit(dc, name(), [UIKit.font(1), UIKit.font(0)], 240, 1);
            UIKit.text(dc, cx, 150, nf[0], nf[1][0], 0xFFFFFF, UIKit.CENTER);
            UIKit.text(dc, cx, 192, UIKit.font(0), UIKit.fit(dc, r[0], UIKit.font(0), 250), UIKit.DIM, UIKit.CENTER);
            UIKit.text(dc, cx, 216, UIKit.font(0), UIKit.fit(dc, r[1], UIKit.font(0), 250), UIKit.DIM, UIKit.CENTER);
            var left = Globals.engine.gamesLeft(gameId);
            UIKit.text(dc, cx, 252, UIKit.font(0), left > 0 ? "TAP TO START" : "PRACTICE - TAP TO START", UIKit.ACCENT, UIKit.CENTER);
        } else {
            // title, headline (largest font that fits), result line wrapped to 2 lines
            var f0 = UIKit.font(0);
            UIKit.lines(dc, cx, 122, f0, [UIKit.fit(dc, resultTitle, f0, 240)], UIKit.GOLD);
            var big = UIKit.bestFit(dc, resultBig, [UIKit.font(2), UIKit.font(1), f0], 240, 1);
            UIKit.lines(dc, cx, 152, big[0], big[1], 0xFFFFFF);
            UIKit.lines(dc, cx, 198, f0, UIKit.wrap(dc, resultLine, f0, 240, 2), UIKit.DIM);
            UIKit.text(dc, cx, 262, f0, "TAP TO EXIT", UIKit.ACCENT, UIKit.CENTER);
        }
    }

    function hudLine(dc, left, right) {
        dc.setColor(UIKit.PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(110, 28, 170, 28, 10);
        dc.setColor(UIKit.BORDER, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(110, 28, 170, 28, 10);
        UIKit.text(dc, 160, 41, UIKit.font(0), UIKit.fit(dc, left, UIKit.font(0), 92), 0xFFFFFF, UIKit.CENTER);
        UIKit.text(dc, 236, 41, UIKit.font(0), UIKit.fit(dc, right, UIKit.font(0), 70), UIKit.ACCENT, UIKit.CENTER);
    }
}

class MiniGameDelegate extends WatchUi.BehaviorDelegate {
    var _v;

    function initialize(v) {
        BehaviorDelegate.initialize();
        _v = v;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var c = evt.getCoordinates();
        _v.tap(c[0], c[1]);
        return true;
    }

    function onSelect() as Boolean {
        _v.action();
        return true;
    }

    function onNextPage() as Boolean {
        _v.step(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _v.step(-1);
        return true;
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        return true;   // no accidental exits mid-game
    }

    function onBack() as Boolean {
        Nav.pop();
        return true;
    }
}

// ---- Bubble Pop ------------------------------------------------------------------------
// Pop bubbles of the target color as they rise. Tap them, or pick a lane with UP/DOWN and
// press START to pop the lowest bubble in it. 20 seconds.
class BubblePopView extends MiniGameView {
    const COLORS = [0xFFC93C, 0xFF6B9A, 0x7FE7FF];
    const NAMES = ["GOLD", "PINK", "BLUE"];
    const LANES = [125, 195, 265];
    const DURATION = 20.0;
    var bubbles;     // [x, y, r, color, vy]
    var score = 0;
    var target = 0;
    var lane = 1;
    var _spawn = 0.0;
    var _swap = 0.0;
    var pops;

    function initialize() {
        MiniGameView.initialize();
        gameId = "bp";
        bubbles = [];
        pops = [];
        target = Util.rnd(3);
    }

    function name() {
        return "BUBBLE POP";
    }

    function rules() {
        return ["Pop bubbles of the target color", "Wrong color costs a point"];
    }

    function update(dt) {
        _spawn += dt;
        _swap += dt;
        var speedUp = 1.0 + t / DURATION;
        if (_spawn > 0.55 / speedUp) {
            _spawn = 0.0;
            var c = Util.rnd(100) < 45 ? target : Util.rnd(3);
            bubbles.add([LANES[Util.rnd(3)] + Util.rf(-12.0, 12.0), 360.0, 15 + Util.rnd(5), c, Util.rf(55.0, 80.0) * speedUp]);
        }
        if (_swap > 6.0) {
            _swap = 0.0;
            target = (target + 1 + Util.rnd(2)) % 3;
        }
        var keep = [];
        for (var i = 0; i < bubbles.size(); i++) {
            var b = bubbles[i];
            b[1] -= b[4] * dt;
            b[0] += Math.sin(b[1] * 0.05) * 0.6;
            if (b[1] > 60) { keep.add(b); }
        }
        bubbles = keep;
        var kp = [];
        for (var i = 0; i < pops.size(); i++) {
            pops[i][2] -= dt;
            if (pops[i][2] > 0) { kp.add(pops[i]); }
        }
        pops = kp;
        if (t >= DURATION) { end(); }
    }

    function popAt(i) {
        var b = bubbles[i];
        var good = b[3] == target;
        score += good ? 1 : -1;
        if (score < 0) { score = 0; }
        pops.add([b[0], b[1], 0.5, good ? "+1" : "-1", good ? 0x5EE36A : 0xFF5A5A]);
        bubbles.remove(b);
        if (!good) { Util.buzz(Globals.engine, 60); }
    }

    function playTap(x, y) {
        for (var i = bubbles.size() - 1; i >= 0; i--) {
            var b = bubbles[i];
            var dx = x - b[0];
            var dy = y - b[1];
            if (dx * dx + dy * dy < (b[2] + 8) * (b[2] + 8)) { popAt(i); return; }
        }
    }

    function playStep(d) {
        lane = Util.clamp(lane + d, 0, 2);
    }

    function playAction() {
        var best = -1;
        var bestY = 0.0;
        for (var i = 0; i < bubbles.size(); i++) {
            var b = bubbles[i];
            if ((b[0] - LANES[lane]).abs() < 40 && b[1] < 330 && b[1] > bestY) { best = i; bestY = b[1]; }
        }
        if (best >= 0) { popAt(best); }
    }

    function end() {
        var s = Globals.engine.stats;
        if (score > s["bub"]) { s["bub"] = score; }
        QuestSystem.event(Globals.engine, QuestSystem.Q_BUBBLE, score);
        var coins = score > 25 ? 25 : score;
        finish("SCORE " + score.toString(), coins, score / 2, "Best " + s["bub"].toString());
    }

    function drawPlay(dc) {
        var left = (DURATION - t).toNumber();
        if (left < 0) { left = 0; }
        hudLine(dc, score.toString() + " pts", left.toString() + "s");
        // target banner
        UIKit.text(dc, 195, 76, UIKit.font(0), "POP " + NAMES[target], COLORS[target], UIKit.CENTER);
        // lane marker for button play
        PixelKit.rect(dc, 0x14244A, LANES[lane] - 30, 336, 60, 4);
        for (var i = 0; i < bubbles.size(); i++) {
            var b = bubbles[i];
            var x = b[0].toNumber();
            var y = b[1].toNumber();
            var r = b[2];
            dc.setColor(PixelKit.shade(COLORS[b[3]], 0.45), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, r);
            dc.setColor(COLORS[b[3]], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, r - 3);
            PixelKit.rect(dc, 0xFFFFFF, x - r / 2, y - r / 2, 4, 4);
        }
        for (var i = 0; i < pops.size(); i++) {
            var p = pops[i];
            UIKit.text(dc, p[0], p[1] - (0.5 - p[2]) * 40, UIKit.font(0), p[3], p[4], UIKit.CENTER);
        }
    }
}

// ---- Treasure Dive -------------------------------------------------------------------------
// Five depths, three caves each. One hides an eel. Choose with a tap (left/centre/right)
// or UP/DOWN + START. Three lives.
class TreasureDiveView extends MiniGameView {
    const CAVE_X = [115, 195, 275];
    var depth = 1;
    var lives = 3;
    var loot = 0;
    var pearlsFound = 0;
    var choice = 1;
    var outcome;        // per cave: 0 empty, 1 coins, 2 pearl, 3 eel
    var amounts;
    var reveal = -1.0;  // >= 0 while showing the result of a pick
    var picked = -1;

    function initialize() {
        MiniGameView.initialize();
        gameId = "td";
        roll();
    }

    function name() {
        return "TREASURE DIVE";
    }

    function rules() {
        return ["Pick a cave at each depth", "Avoid the eel - 3 lives"];
    }

    function roll() {
        outcome = [0, 1, 1];
        amounts = [0, 0, 0];
        var eel = Util.rnd(3);
        for (var i = 0; i < 3; i++) {
            if (i == eel) { outcome[i] = 3; continue; }
            var r = Util.rnd(100);
            if (r < 12) { outcome[i] = 2; }
            else if (r < 72) { outcome[i] = 1; amounts[i] = 4 + Util.rnd(6) + depth * 2; }
            else { outcome[i] = 0; }
        }
        picked = -1;
        reveal = -1.0;
    }

    function choose(i) {
        if (reveal >= 0) { return; }
        picked = i;
        reveal = 0.0;
        var o = outcome[i];
        if (o == 3) { lives -= 1; Util.buzz(Globals.engine, 120); }
        else if (o == 2) { pearlsFound += 1; }
        else if (o == 1) { loot += amounts[i]; }
    }

    function update(dt) {
        if (reveal < 0) { return; }
        reveal += dt;
        if (reveal < 1.3) { return; }
        if (lives <= 0) { end(false); return; }
        if (depth >= 5) { end(true); return; }
        depth += 1;
        roll();
    }

    function end(cleared) {
        var e = Globals.engine;
        var reached = cleared ? 5 : depth;
        if (reached > e.stats["dive"]) { e.stats["dive"] = reached; }
        var coins = cleared ? loot + 20 : loot / 2;
        if (coins > 80) { coins = 80; }
        if (rewarded && pearlsFound > 0) { e.pearls += pearlsFound; }
        var line = cleared ? "Full dive bonus +20" : "Eels took half the loot";
        if (pearlsFound > 0) { line = line + ", +" + pearlsFound.toString() + " pearl"; }
        finish(cleared ? "TREASURE FOUND" : "SURFACED AT DEPTH " + reached.toString(), coins, 5 + reached * 2, line);
    }

    function playTap(x, y) {
        if (x < 155) { choose(0); } else if (x > 235) { choose(2); } else { choose(1); }
    }

    function playStep(d) {
        if (reveal < 0) { choice = Util.clamp(choice + d, 0, 2); }
    }

    function playAction() {
        choose(choice);
    }

    function drawPlay(dc) {
        hudLine(dc, loot.toString() + "c", "D" + depth.toString() + "/5");
        for (var i = 0; i < 3; i++) {
            var hx = 172 + i * 16;
            if (i < lives) { AquariumHUD.icon(dc, SpriteData.ICON_HEART, hx, 64, 2); }
            else { PixelKit.rect(dc, 0x23314F, hx + 4, 68, 6, 6); }
        }
        // depth tint bands
        var shade = depth * 0.1;
        PixelKit.rect(dc, PixelKit.shade(0x0E3A6A, shade), 0, 90, 390, 230);
        PixelKit.rect(dc, PixelKit.shade(0x3A2E5A, shade), 0, 290, 390, 100);
        for (var i = 0; i < 3; i++) {
            var cx = CAVE_X[i];
            var sel = reveal < 0 && i == choice;
            // cave mouth
            dc.setColor(0x4A3F6B, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - 34, 170, 68, 110, 30);
            dc.setColor(0x06060C, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(cx - 24, 186, 48, 94, 22);
            if (sel) {
                dc.setColor(UIKit.ACCENT, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
                dc.drawRoundedRectangle(cx - 36, 168, 72, 114, 30);
                dc.setPenWidth(1);
            }
            if (reveal >= 0) {
                var o = outcome[i];
                var dim = i != picked;
                if (o == 3) {
                    IconKit.draw(dc, IconKit.GRID, SpriteData.ICON_FISH, cx, 232, dim ? 2 : 3);
                    UIKit.text(dc, cx, 300, UIKit.font(0), "EEL!", dim ? 0x8EA3C0 : 0xFF5A5A, UIKit.CENTER);
                } else if (o == 2) {
                    IconKit.draw(dc, IconKit.GRID, SpriteData.ICON_PEARL, cx, 232, dim ? 2 : 3);
                    UIKit.text(dc, cx, 300, UIKit.font(0), "PEARL", dim ? 0x8EA3C0 : 0xF4F0FF, UIKit.CENTER);
                } else if (o == 1) {
                    IconKit.draw(dc, IconKit.GRID, SpriteData.ICON_CHEST, cx, 232, dim ? 2 : 3);
                    UIKit.text(dc, cx, 300, UIKit.font(0), "+" + amounts[i].toString(), dim ? 0x8EA3C0 : UIKit.GOLD, UIKit.CENTER);
                } else {
                    UIKit.text(dc, cx, 300, UIKit.font(0), "empty", 0x8EA3C0, UIKit.CENTER);
                }
            }
        }
        UIKit.text(dc, 195, 120, UIKit.font(0), reveal < 0 ? "Choose a cave" : (lives <= 0 ? "Out of lives" : "Diving deeper..."), UIKit.DIM, UIKit.CENTER);
    }
}

// ---- Fish Racing ---------------------------------------------------------------------------
module FishRace {
    // Base speed from species, fish level, training (running) and evolution.
    function racerSpeed(f) {
        return 40 + FishDatabase.SPEED[f.sp] * 0.3 + f.level() * 2 + f.rs * 1.5 + (f.evo ? 5 : 0);
    }
}

// Your fish races three rivals across the screen. A meter swings back and forth: press
// START (or tap) while it is in the green zone for a boost; miss and your fish stumbles.
class FishRaceView extends MiniGameView {
    const LEN = 1000.0;
    const LANE_Y = [120, 170, 220, 270];
    var racer;
    var sp;         // species per lane (lane 0 = you)
    var pos;
    var speed;
    var boostT = 0.0;
    var stumbleT = 0.0;
    var cooldown = 0.0;
    var place = 0;
    var finishedOrder;
    var msg = "";
    var msgT = 0.0;

    function initialize(f) {
        MiniGameView.initialize();
        gameId = "fr";
        racer = f;
        sp = [f.sp];
        pos = [0.0, 0.0, 0.0, 0.0];
        speed = [FishRace.racerSpeed(f), 0.0, 0.0, 0.0];
        finishedOrder = [];
        var base = 46 + Globals.engine.lv * 1.5;
        for (var i = 1; i < 4; i++) {
            sp.add(Util.rnd(12));
            speed[i] = base + Util.rf(-4.0, 8.0);
        }
    }

    function name() {
        return "FISH RACING";
    }

    function rules() {
        return ["Boost when the meter is green", "Train fish with running points"];
    }

    function warm() {
        for (var i = 0; i < sp.size(); i++) {
            if (!SpriteData.warmSpecies(sp[i])) { return; }
        }
        if (racer.evo) { SpriteData.get(racer.sp, true); }
    }

    function meter() {
        return (Math.sin(t * 2.6) + 1.0) / 2.0;
    }

    function update(dt) {
        warm();
        if (boostT > 0) { boostT -= dt; }
        if (stumbleT > 0) { stumbleT -= dt; }
        if (cooldown > 0) { cooldown -= dt; }
        if (msgT > 0) { msgT -= dt; }
        for (var i = 0; i < 4; i++) {
            if (finishedOrder.indexOf(i) >= 0) { continue; }
            var v = speed[i];
            if (i == 0) {
                if (boostT > 0) { v *= 1.8; }
                if (stumbleT > 0) { v *= 0.5; }
            } else {
                v *= 0.9 + 0.2 * Math.sin(t * (1.3 + i * 0.4) + i);
            }
            pos[i] += v * dt;
            if (pos[i] >= LEN) {
                pos[i] = LEN;
                finishedOrder.add(i);
            }
        }
        if (finishedOrder.indexOf(0) >= 0 && place == 0) {
            place = finishedOrder.indexOf(0) + 1;
            end();
        }
    }

    function end() {
        var e = Globals.engine;
        var coins = [30, 15, 8, 3][place - 1] * Mods.raceMul;
        var xp = [15, 8, 4, 2][place - 1];
        racer.fxp += 5;
        if (place == 1) {
            e.stats["raceW"] = e.stats["raceW"] + 1;
            QuestSystem.event(e, QuestSystem.Q_RACE_WIN, 1);
        }
        var names = ["1st place!", "2nd place", "3rd place", "4th place"];
        finish(names[place - 1], coins, xp, racer.name() + " +5 fish XP");
    }

    function playAction() {
        if (cooldown > 0) { return; }
        cooldown = 1.2;
        var m = meter();
        if (m >= 0.68 && m <= 0.9) {
            boostT = 1.4;
            msg = "PERFECT BOOST!";
            Util.buzz(Globals.engine, 50);
        } else {
            stumbleT = 0.8;
            msg = "Too early!";
            if (m > 0.9) { msg = "Too late!"; }
        }
        msgT = 1.0;
    }

    function playTap(x, y) {
        playAction();
    }

    function drawPlay(dc) {
        var e = Globals.engine;
        var you = (pos[0] / LEN * 100).toNumber();
        hudLine(dc, "You " + you.toString() + "%", boostT > 0 ? "BOOST" : "");
        // lanes and finish line
        for (var i = 0; i < 4; i++) {
            PixelKit.rect(dc, i == 0 ? 0x14244A : 0x0E1830, 40, LANE_Y[i] - 18, 310, 36);
        }
        for (var y = 104; y < 290; y += 8) { PixelKit.rect(dc, (y / 8) % 2 == 0 ? 0xFFFFFF : 0x0B0B14, 336, y, 6, 8); }
        for (var i = 3; i >= 0; i--) {
            var x = 56 + (pos[i] / LEN * 270).toNumber();
            var evo = i == 0 && racer.evo;
            var spr = SpriteData.peek(sp[i], evo);
            if (spr == null) { continue; }
            var pal = spr[:pal];
            if (i == 0 && (racer.variant & 123) != 0) {
                var p = SpriteData.palette(sp[i], evo, racer.variant, 0);
                if (p != null) { pal = p; }
            }
            PixelKit.drawSprite(dc, spr, pal, x, LANE_Y[i], 2, false, ((t * 8).toNumber() % 2) == 0);
        }
        // boost meter
        var mx = 95;
        var mw = 200;
        PixelKit.rect(dc, 0x1A2238, mx, 312, mw, 10);
        PixelKit.rect(dc, 0x2F7A3A, mx + (mw * 0.68).toNumber(), 312, (mw * 0.22).toNumber(), 10);
        var nx = mx + (meter() * mw).toNumber();
        PixelKit.rect(dc, 0xFFFFFF, nx - 2, 306, 4, 22);
        if (msgT > 0) {
            UIKit.text(dc, 195, 344, UIKit.font(0), msg, boostT > 0 ? 0x5EE36A : 0xFF9F43, UIKit.CENTER);
        } else {
            UIKit.text(dc, 195, 344, UIKit.font(0), cooldown > 0 ? "..." : "START / TAP = BOOST", UIKit.DIM, UIKit.CENTER);
        }
    }
}
