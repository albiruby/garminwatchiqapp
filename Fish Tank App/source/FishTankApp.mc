import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.WatchUi;

class FishTankApp extends Application.AppBase {
    var _eng = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
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
        var v = new FishTankView(_eng);
        Globals.view = v;
        return [v, new FishTankDelegate(v)];
    }
}
