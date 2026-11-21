import Toybox.ActivityMonitor;
import Toybox.Activity;
import Toybox.Application;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class NusantaraView extends WatchUi.WatchFace {

    const LOW_BATTERY = 20.0;

    private var _engine as PatternEngine;
    private var _bufRef as Graphics.BufferedBitmapReference?;
    private var _bufKey as Number = -1;
    private var _builtCell as Number = 0;
    private var _sleeping as Boolean = false;

    private var _w as Number = 0;
    private var _h as Number = 0;
    private var _cx as Number = 0;
    private var _cy as Number = 0;
    private var _r as Number = 0;
    private var _round as Boolean = true;
    private var _mono as Boolean = false;
    private var _mip as Boolean = false;
    private var _sub as Graphics.BoundingBox? = null;
    // where the four slots were last drawn, for press-and-hold
    private var _hitPlateY as Number = 0;
    private var _hitLX as Number = 0;
    private var _hitRX as Number = 0;
    private var _hitLR as Number = 0;
    private var _hitRR as Number = 0;

    private var _colorway as Number = 0;
    private var _density as Number = 1;
    private var _timeStyle as Number = 0;
    private var _topSlot as Number = 0;
    private var _bottomSlot as Number = 0;
    private var _leftSlot as Number = 0;
    private var _rightSlot as Number = 0;

    // Pridi weights (OFL), baked as bitmap fonts per screen size: Medium for plaques,
    // SemiBold for digital time, Light for always-on time (fewer lit pixels).
    private var _fontSmall as Graphics.FontType = Graphics.FONT_XTINY;
    private var _fontTime as Graphics.FontType = Graphics.FONT_NUMBER_MEDIUM;
    private var _fontAod as Graphics.FontType = Graphics.FONT_NUMBER_MEDIUM;
    private var _fontRing as Graphics.FontType = Graphics.FONT_XTINY;
    private var _fontLabel as Graphics.FontType = Graphics.FONT_XTINY;

    function initialize() {
        WatchFace.initialize();
        _engine = new PatternEngine();
        reloadSettings();
    }

    function reloadSettings() as Void {
        _colorway = readProp("Colorway", 0, 3, 0);
        _density = readProp("Density", 0, 2, 1);
        _timeStyle = readProp("TimeStyle", 0, 1, 0);
        _topSlot = readProp("TopSlot", 0, 6, 0);
        _bottomSlot = readProp("BottomSlot", 0, 8, 0);
        _leftSlot = readProp("LeftSlot", 0, 10, 0);
        _rightSlot = readProp("RightSlot", 0, 6, 0);
        _bufKey = -1;
    }

    private function readProp(key as String, lo as Number, hi as Number, def as Number) as Number {
        var v = Application.Properties.getValue(key);
        if (v instanceof Number && v >= lo && v <= hi) {
            return v;
        }
        return def;
    }

    function onLayout(dc as Dc) as Void {
        _w = dc.getWidth();
        _h = dc.getHeight();
        _cx = _w / 2;
        _cy = _h / 2;
        _r = (_w < _h ? _w : _h) / 2;
        _builtCell = 0;
        _bufRef = null;
        _bufKey = -1;
        _fontSmall = WatchUi.loadResource(Rez.Fonts.PridiSmall) as WatchUi.FontResource;
        _fontTime = WatchUi.loadResource(Rez.Fonts.PridiTime) as WatchUi.FontResource;
        _fontAod = WatchUi.loadResource(Rez.Fonts.PridiAod) as WatchUi.FontResource;
        _fontRing = WatchUi.loadResource(Rez.Fonts.PridiRing) as WatchUi.FontResource;
        _fontLabel = WatchUi.loadResource(Rez.Fonts.PridiLabel) as WatchUi.FontResource;

        // Display adaptation: shape (round / semi-octagon / rectangle), panel (AMOLED vs MIP),
        // monochrome Instinct panels and their subscreen window.
        var ds = System.getDeviceSettings();
        _round = ds.screenShape != System.SCREEN_SHAPE_RECTANGLE;
        _mono = ds.screenShape == System.SCREEN_SHAPE_SEMI_OCTAGON;
        _mip = !((ds has :requiresBurnInProtection) && ds.requiresBurnInProtection);
        _sub = (WatchUi has :getSubscreen) ? WatchUi.getSubscreen() : null;
        _engine.mono = _mono;
    }

    function onEnterSleep() as Void {
        _sleeping = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _sleeping = false;
        WatchUi.requestUpdate();
    }

    private function cellSize() as Number {
        switch (_density) {
            case 0:
                return _w / 7;
            case 2:
                return _w / 13;
            default:
                return _w / 10;
        }
    }

    private function burnInDevice() as Boolean {
        var s = System.getDeviceSettings();
        return (s has :requiresBurnInProtection) && s.requiresBurnInProtection;
    }

    function onUpdate(dc as Dc) as Void {
        if (Preview.ON) { _timeStyle = Preview.STYLE; _sleeping = Preview.SLEEP; _colorway = Preview.COLORWAY; _topSlot = Preview.TOP; _bottomSlot = Preview.BOTTOM; _leftSlot = Preview.LEFT; _rightSlot = Preview.RIGHT; } // store screenshots (tools/capture.ps1); Preview.ON is false in releases
        var clock = System.getClockTime();
        var pal = Palette.forDisplay(_colorway, _mip, _mono);

        if (_sleeping && burnInDevice()) {
            drawAod(dc, pal, clock);
            return;
        }

        var cell = cellSize();
        if (cell != _builtCell) {
            _engine.build(_w, _h, cell, _round);
            _builtCell = cell;
            _bufKey = -1;
        }

        var steps = 0;
        var goal = 0;
        var info = ActivityMonitor.getInfo();
        if (info.steps != null) {
            steps = info.steps as Number;
        }
        if (info.stepGoal != null) {
            goal = info.stepGoal as Number;
        }
        // Awakening runs ahead at double speed: 50% = everything awake, half in bloom.
        if (Preview.ON) { steps = Preview.STEPS; goal = 10000; } // store screenshots (tools/capture.ps1); Preview.ON is false in releases
        var total = _engine.units.size();
        var st = Living.stages(steps, goal, total);
        var bloom = st[0];
        var awake = st[1];
        var complete = goal > 0 && steps >= goal;
        var key = (bloom * 1024 + awake) * 8 + _colorway * 2 + (complete ? 1 : 0);

        drawPattern(dc, pal, bloom, awake, complete, key);

        var stats = System.getSystemStats();
        drawBatteryJewel(dc, pal, stats.battery);
        drawMedallion(dc, pal, clock, steps, goal, stats.battery);
        drawSubscreen(dc, pal, steps, goal);

        if (_timeStyle == 0) {
            Dial.drawHands(dc, pal, _cx, _cy, _r, clock.hour, clock.min);
        }
    }

    // Pattern layer from the graphics pool; re-rendered only when its key changes.
    private function drawPattern(dc as Dc, pal as Array<Number>, bloom as Number, awake as Number, complete as Boolean, key as Number) as Void {
        var bmp = null as Graphics.BufferedBitmap?;
        if (Graphics has :createBufferedBitmap) {
            var ref = _bufRef;
            if (ref != null) {
                bmp = ref.get() as Graphics.BufferedBitmap?;
            }
            if (bmp == null) {
                ref = Graphics.createBufferedBitmap({:width => _w, :height => _h});
                _bufRef = ref;
                bmp = ref.get() as Graphics.BufferedBitmap?;
                _bufKey = -1;
            }
        }
        if (bmp == null) {
            _engine.draw(dc, pal, _colorway, bloom, awake, complete);
            return;
        }
        if (key != _bufKey) {
            _engine.draw(bmp.getDc(), pal, _colorway, bloom, awake, complete);
            _bufKey = key;
        }
        dc.drawBitmap(0, 0, bmp);
    }

    private function drawBatteryJewel(dc as Dc, pal as Array<Number>, battery as Float) as Void {
        var y = _round ? (_r * 0.09).toNumber() + (_cy - _r) : (_h * 0.04).toNumber();
        var s = (_r * 0.035).toNumber();
        dc.setColor(pal[Palette.BG], Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, y, s + 3);
        dc.setColor(battery < LOW_BATTERY ? pal[Palette.WARN] : pal[Palette.ACCENT], Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[_cx, y - s], [_cx + s, y], [_cx, y + s], [_cx - s, y]]);
    }

    private function drawMedallion(dc as Dc, pal as Array<Number>, clock as System.ClockTime, steps as Number, goal as Number, battery as Float) as Void {
        // Half-width of whatever sits in the centre, so the side rings can keep clear of it.
        var centreHalf = (_r * 0.08).toNumber();
        if (_timeStyle == 1) {
            centreHalf = drawPlaque(dc, pal, _cy, timeText(clock), pal[Palette.LIGHT], _fontTime, Palette.MID, 1.0, 1.45) / 2;
        } else {
            // small hub behind the hand pivot
            dc.setColor(pal[Palette.BG], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_cx, _cy, centreHalf);
        }

        // Between the centre and the battery jewel: clear of the hands' busiest zone,
        // with breathing room from the bezel.
        // Rectangular screens are taller than the fitted circle: use half the height there.
        var plateY = _round ? (_r * 0.68).toNumber() : (_h / 2 * 0.78).toNumber();
        drawPlaque(dc, pal, _cy - plateY, Slots.top(_topSlot), pal[Palette.ACCENT], _fontSmall, Palette.DARK, 1.6, 1.7);
        drawPlaque(dc, pal, _cy + plateY, Slots.bottom(_bottomSlot), pal[Palette.TEXT], _fontSmall, Palette.DARK, 1.6, 1.7);

        var l = Slots.left(_leftSlot);
        var rt = Slots.right(_rightSlot);
        var lr = ringRadius(dc, l[0], l[1]);
        var rr = ringRadius(dc, rt[0], rt[1]);
        _hitPlateY = plateY;
        _hitLX = _cx - ringOffset(centreHalf, lr);
        _hitRX = _cx + ringOffset(centreHalf, rr);
        _hitLR = lr;
        _hitRR = rr;
        drawRing(dc, pal, _hitLX, lr, l[0], l[1]);
        drawRing(dc, pal, _hitRX, rr, rt[0], rt[1]);
    }

    // Native screen for the slot under (x, y), or null. Zones are a little larger than the
    // drawn shapes so a fingertip finds them easily.
    function targetAt(x as Number, y as Number) as Complications.Type? {
        var pad = (_r * 0.06).toNumber();
        var dl = (x - _hitLX) * (x - _hitLX) + (y - _cy) * (y - _cy);
        if (dl < (_hitLR + pad) * (_hitLR + pad)) {
            return Slots.leftTarget(_leftSlot);
        }
        var dr = (x - _hitRX) * (x - _hitRX) + (y - _cy) * (y - _cy);
        if (dr < (_hitRR + pad) * (_hitRR + pad)) {
            return Slots.rightTarget(_rightSlot);
        }
        var halfH = (_r * 0.13).toNumber();
        var halfW = (_r * 0.50).toNumber();
        if ((x - _cx).abs() < halfW) {
            if ((y - (_cy - _hitPlateY)).abs() < halfH) {
                return Slots.topTarget(_topSlot);
            }
            if ((y - (_cy + _hitPlateY)).abs() < halfH) {
                return Slots.bottomTarget(_bottomSlot);
            }
        }
        return null;
    }

    // Ring grows with its widest line, between a base size and a cap.
    private function ringRadius(dc as Dc, value as String, label as String) as Number {
        var vw = dc.getTextWidthInPixels(value, _fontRing);
        var lw = dc.getTextWidthInPixels(label, _fontLabel);
        var need = (vw > lw ? vw : lw) / 2 + (_r * 0.045).toNumber();
        var base = (_r * 0.20).toNumber();
        var cap = (_r * 0.27).toNumber();
        return need < base ? base : (need > cap ? cap : need);
    }

    // Ring centre distance from the middle: default spot, pushed out to clear the centre,
    // pulled back in to stay inside the bezel.
    private function ringOffset(centreHalf as Number, radius as Number) as Number {
        var x = (_r * 0.66).toNumber();
        var clear = centreHalf + (_r * 0.04).toNumber() + radius;
        if (x < clear) {
            x = clear;
        }
        var limit = (_r * 0.96).toNumber() - radius;
        return x > limit ? limit : x;
    }

    // Round metric slot: value over a small gold label, on a dark disc with a gold rim.
    private function drawRing(dc as Dc, pal as Array<Number>, x as Number, rr as Number, value as String, label as String) as Void {
        dc.setColor(pal[Palette.BG], Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, _cy, rr);
        // quiet rim: the data, not the frame, should be the brightest thing in the slot
        dc.setColor(pal[Palette.MID], Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(x, _cy, rr);
        dc.setPenWidth(1);
        var valueH = dc.getFontHeight(_fontRing);
        var labelH = dc.getFontHeight(_fontLabel);
        var gap = (_r * 0.02).toNumber();
        var top = _cy - (valueH + gap + labelH) / 2;
        dc.setColor(pal[Palette.TEXT], Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, top + valueH / 2, _fontRing, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(pal[Palette.ACCENT], Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, top + valueH + gap + labelH / 2, _fontLabel, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Text on a dark rounded plate with a thin rim, so it reads over the motif.
    // The plate hugs its text but never leaves the round screen: long text is shortened
    // with "..". Returns the plate width.
    private function drawPlaque(dc as Dc, pal as Array<Number>, y as Number, text as String, color as Number, font as Graphics.FontType, rim as Number, padX as Float, padY as Float) as Number {
        var dims = dc.getTextDimensions(text, font);
        // padding scales with the text so the plate frames it instead of hugging it
        var padW = (dims[1] * padX).toNumber();
        var h = (dims[1] * padY).toNumber();
        var dy = (y - _cy).abs() + h / 2;
        var maxW = _r * _r > dy * dy ? (2 * (Math.sqrt(_r * _r - dy * dy) - _r * 0.05)).toNumber() : 0;
        var sub = _sub;
        if (!_round) {
            maxW = _w - (_r * 0.2).toNumber();
        }
        if (sub != null && top0(y, h) < (sub.y as Number) + (sub.height as Number)) {
            // keep clear of the Instinct subscreen window
            var room = 2 * ((sub.x as Number) - _cx - 3);
            maxW = room < maxW ? room : maxW;
        }
        var w = dims[0] + padW;
        var core = text;
        while (w > maxW && core.length() > 3) {
            core = core.substring(0, core.length() - 1) as String;
            text = core + "..";
            w = dc.getTextWidthInPixels(text, font) + padW;
        }
        var x = _cx - w / 2;
        var top = y - h / 2;
        var radius = h / 2 < 20 ? h / 2 : 20;
        dc.setColor(pal[Palette.BG], Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, top, w, h, radius);
        dc.setColor(pal[rim], Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(x, top, w, h, radius);
        dc.setPenWidth(1);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        return w;
    }

    // Instinct subscreen window: daily step goal %, the number the motif visualises.
    private function drawSubscreen(dc as Dc, pal as Array<Number>, steps as Number, goal as Number) as Void {
        var sub = _sub;
        if (sub == null) {
            return;
        }
        var sw = sub.width as Number;
        var sh = sub.height as Number;
        var x = (sub.x as Number) + sw / 2;
        var y = (sub.y as Number) + sh / 2;
        var rr = (sw < sh ? sw : sh) / 2;
        dc.setColor(pal[Palette.BG], pal[Palette.BG]);
        dc.fillCircle(x, y, rr);
        var pct = goal > 0 ? (steps.toLong() * 100 / goal).toNumber() : 0;
        var valueH = dc.getFontHeight(_fontRing);
        var labelH = dc.getFontHeight(_fontLabel);
        var top = y - (valueH + 2 + labelH) / 2;
        dc.setColor(pal[Palette.TEXT], Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, top + valueH / 2, _fontRing, pct.format("%d") + "%", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(pal[Palette.ACCENT], Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, top + valueH + 2 + labelH / 2, _fontLabel, "GOAL", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function top0(y as Number, h as Number) as Number {
        return y - h / 2;
    }

    private function timeText(clock as System.ClockTime) as String {
        var h = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            h = h % 12;
            if (h == 0) {
                h = 12;
            }
        }
        return h.format("%02d") + ":" + clock.min.format("%02d");
    }


    // Always-on: black field, outline-only flower and time, shifted each minute for burn-in.
    private function drawAod(dc as Dc, pal as Array<Number>, clock as System.ClockTime) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        var m = clock.min;
        var dx = ((m % 5) - 2) * 4;
        var dy = (((m / 5) % 5) - 2) * 4;
        var cx = _cx + dx;
        var cy = _cy + dy;

        dc.setPenWidth(1);
        dc.setColor(pal[Palette.DARK], Graphics.COLOR_TRANSPARENT);
        if (_timeStyle == 1) {
            Dial.flowerOutline(dc, cx, cy - (_r * 0.42).toNumber(), (_r * 0.30).toNumber());
            dc.setColor(pal[Palette.MID], Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, _fontAod, timeText(clock), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            // hour dots give orientation for a few dozen pixels
            dc.setColor(pal[Palette.MID], Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 12; i++) {
                if (i == 0) {
                    continue;
                }
                var a = i * Math.PI / 6;
                var rr = _r * 0.86;
                dc.fillCircle(cx + (rr * Math.sin(a)).toNumber(), cy - (rr * Math.cos(a)).toNumber(), i % 3 == 0 ? 3 : 1);
            }
            dc.setColor(pal[Palette.DARK], Graphics.COLOR_TRANSPARENT);
            Dial.flowerOutline(dc, cx, cy - (_r * 0.80).toNumber(), (_r * 0.16).toNumber());
            var hAng = ((clock.hour % 12) + clock.min / 60.0) * Math.PI / 6;
            var mAng = clock.min * Math.PI / 30;
            dc.setColor(pal[Palette.MID], Graphics.COLOR_TRANSPARENT);
            PatternEngine.stroke(dc, Dial.handPoints(cx, cy, hAng, _r * 0.50, _r * 0.03, _r * 0.06));
            PatternEngine.stroke(dc, Dial.handPoints(cx, cy, mAng, _r * 0.78, _r * 0.022, _r * 0.08));
            dc.drawCircle(cx, cy, (_r * 0.03).toNumber());
        }
    }
}
