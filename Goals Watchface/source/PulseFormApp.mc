import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class PulseFormApp extends Application.AppBase {

    private var _view as PulseFormView?;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var v = new PulseFormView();
        _view = v;
        return [v];
    }

    function onSettingsChanged() as Void {
        if (_view != null) {
            _view.reloadSettings();
        }
        WatchUi.requestUpdate();
    }
}
