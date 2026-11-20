import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class ReadyRunApp extends Application.AppBase {
    var _state as AppState;
    var _nav as NavModel;

    function initialize() {
        AppBase.initialize();
        _state = new AppState();
        _nav = new NavModel();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new MainView(_state, _nav), new MainDelegate(_nav, _state)];
    }
}
