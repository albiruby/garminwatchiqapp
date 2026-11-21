import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class RestoraApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() {
        return [HomeMenu.build(), new HomeMenuDelegate()];
    }
}

function getApp() as RestoraApp {
    return Application.getApp() as RestoraApp;
}
