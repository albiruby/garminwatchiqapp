import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Render order: settings (look applied) -> metrics -> goals -> layout -> face.
// Faces live in source/faces; shared drawing helpers in Canvas, shared text in Readouts.
class PulseFormView extends WatchUi.WatchFace {

    private var _s as SettingsManager;
    private var _L as LayoutEngine;
    private var _audit as LayoutAudit;
    private var _canvas as Canvas;
    private var _sleeping as Boolean = false;
    private var _aodFont = null;   // light time font, loaded only while asleep
    private var _w as Number = 390;
    private var _h as Number = 390;

    function initialize() {
        WatchFace.initialize();
        _s = new SettingsManager();
        if (Preview.ON) {
            Preview.apply(_s);
        }
        _L = new LayoutEngine();
        _audit = new LayoutAudit();
        _canvas = new Canvas(_L, _audit);
    }

    function onLayout(dc as Dc) as Void {
        _w = dc.getWidth();
        _h = dc.getHeight();
        _L.compute(_w, _h, _s);
    }

    function reloadSettings() as Void {
        _s.load();
        if (Preview.ON) {
            Preview.apply(_s);
        }
        _L.compute(_w, _h, _s);
    }

    function onEnterSleep() as Void {
        _sleeping = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _sleeping = false;
        _aodFont = null;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var clock = System.getClockTime();
        var hour = clock.hour;
        var min = clock.min;
        var sec = clock.sec;
        var sleeping = _sleeping;
        if (Preview.ON) {
            hour = Preview.HOUR;
            min = Preview.MIN;
            sec = Preview.SEC;
            sleeping = Preview.SLEEP;
        }

        var m = MetricProvider.read();
        var steps = ActivityGoalEngine.evaluate(m.steps, ActivityGoalEngine.stepTarget(_s, m.stepGoal));
        var t = Readouts.clock(hour, min, _s);

        dc.setColor(ThemeManager.BLACK, ThemeManager.BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        var L = _L;
        if (sleeping && PowerManager.burnInDevice()) {
            drawAod(dc, t, hour, min, steps);
            return;
        }

        var c = _canvas;
        c.dc = dc;
        _audit.reset(Preview.ON);
        if (L.ringed && !L.linear) {
            ProgressRenderer.ring(dc, L, steps, _s);
        }
        var awakeSec = sleeping ? -1 : sec;
        var marker = (_s.showAmPm && !t[2].equals("")) ? t[2] : "";
        switch (L.preset) {
            case SettingsManager.LAYOUT_MINIMAL:
                MinimalFace.draw(c, _s, m, steps, t);
                break;
            case SettingsManager.LAYOUT_DIAL:
                DialFace.draw(c, _s, m, steps, hour, min, awakeSec, marker);
                break;
            case SettingsManager.LAYOUT_HORIZON:
                HorizonFace.draw(c, _s, m, steps, t);
                break;
            case SettingsManager.LAYOUT_STACK:
                StackFace.draw(c, _s, m, steps, t);
                break;
            default:
                SplitFace.draw(c, _s, m, steps, t, awakeSec);
                break;
        }
        if (_s.showBattery) {
            c.battery(m, L.preset == SettingsManager.LAYOUT_DENSE);
        }
        if (_audit.check(dc, L) >= 0 && Preview.ON) {
            var st = System.getSystemStats();
            System.println("MEM used=" + st.usedMemory + " total=" + st.totalMemory);
        }
    }

    // Always-on: once a minute, dim, shifted 2 px each minute against burn-in.
    // Dial keeps its hands; every other face shows stacked light numerals.
    private function drawAod(dc as Dc, t as Array<String>, hour as Number, min as Number, steps as Goal) as Void {
        var L = _L;
        var sh = PowerManager.shift(min);
        var dx = sh[0];
        var dy = sh[1];
        var CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        if (L.preset == SettingsManager.LAYOUT_DIAL) {
            DialFace.aod(dc, L, _s, hour, min, steps, dx, dy);
            return;
        }
        if (_aodFont == null) {
            _aodFont = WatchUi.loadResource(Rez.Fonts.TimeAod);
        }
        var half = dc.getFontHeight(_aodFont) / 2 + 4;
        dc.setColor(PowerManager.AOD_TIME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(L.cx + dx, L.cy - half + dy, _aodFont, t[0], CENTER);
        dc.drawText(L.cx + dx, L.cy + half + dy, _aodFont, t[1], CENTER);

        dc.setColor(PowerManager.AOD_TEXT, Graphics.COLOR_TRANSPARENT);
        if (_s.showDate) {
            dc.drawText(L.cx + dx, L.cy - 2 * half - 20 + dy, L.textFont, Readouts.date(false), CENTER);
        }
        if (_s.aodStyle == 0 && steps.hasTarget) {
            dc.drawText(L.cx + dx, L.cy + 2 * half + 20 + dy, L.textFont, FormatUtils.percent(steps.percent), CENTER);
            // thin progress line only, no track: few lit pixels
            dc.setPenWidth(2);
            dc.setColor(ThemeManager.accentDim(), ThemeManager.BLACK);
            ProgressRenderer.arc(dc, L.cx + dx, L.cy + dy, L.ringR, 240.0,
                                 ProgressRenderer.angleAt(ActivityGoalEngine.trackFraction(steps)));
            dc.setPenWidth(1);
        }
    }
}
