import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

class FishTankApp extends Application.AppBase {
    var _eng = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        // The glance runs in a tiny memory budget; it cannot run Scale.init(), so stop
        // before the full-app setup.
        if (System.getDeviceSettings().isGlanceModeEnabled == true) { return; }
        Scale.init();
        PixelKit.warmHudIcons();
        Math.srand(Time.now().value());
        _eng = new AquariumEngine();
        _eng.load();
        Globals.engine = _eng;
    }

    function onStop(state as Dictionary?) as Void {
        if (_eng != null) { _eng.save(); }
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        if (_eng == null) {
            _eng = new AquariumEngine();
            _eng.load();
            Globals.engine = _eng;
        }
        var v = new FishTankView(_eng);
        Globals.view = v;
        return [v, new FishTankDelegate(v)];
    }

    // Appears in the glance list when the user presses UP/DOWN from the watch face.
    (:glance)
    function getGlanceView() {
        return [new FishTankGlanceView()];
    }
}
