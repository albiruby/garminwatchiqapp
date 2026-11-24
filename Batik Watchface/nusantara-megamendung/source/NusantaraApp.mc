import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class NusantaraApp extends Application.AppBase {

    private var _view as NusantaraView?;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new NusantaraView();
        _view = view;
        if (WatchUi has :WatchFaceDelegate) {
            return [view, new NusantaraDelegate(view)];
        }
        return [view];
    }

    function onSettingsChanged() as Void {
        var view = _view;
        if (view != null) {
            view.reloadSettings();
        }
        WatchUi.requestUpdate();
    }
}
