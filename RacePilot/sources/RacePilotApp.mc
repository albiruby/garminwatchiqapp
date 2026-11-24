import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.WatchUi;

class RacePilotApp extends Application.AppBase {
    private var mEngine as PaceEngine;

    public function initialize() {
        AppBase.initialize();
        mEngine = new PaceEngine();
    }

    public function onStart(state as Dictionary?) as Void {
        loadUserSettings();
    }

    public function onStop(state as Dictionary?) as Void {
    }

    public function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        loadUserSettings();
        return [new RacePilotView(mEngine)];
    }

    public function onSettingsChanged() as Void {
        loadUserSettings();
        WatchUi.requestUpdate();
    }

    public function loadUserSettings() as Void {
        var racePrefs = getSafeNumberProperty("RacePrefs", 0);
        var customDistM = getSafeNumberProperty("CustomDistM", 5000);
        var customTimeMin = getSafeNumberProperty("CustomTimeMin", 30);
        var runType = getSafeNumberProperty("RunType", 0);
        var treadmillCalib = getSafeNumberProperty("TreadmillCalib", 100);
        var trackLapLen = getSafeNumberProperty("TrackLapLen", 400);
        var paceSmoothing = getSafeNumberProperty("PaceSmoothing", 50);
        var debugMode = getSafeBooleanProperty("DebugMode", false);

        mEngine.applySettings(
            racePrefs,
            customDistM,
            customTimeMin,
            runType,
            treadmillCalib,
            trackLapLen,
            paceSmoothing,
            debugMode
        );

        var units = getSafeNumberProperty("Units", 0);
        var alerts = getSafeBooleanProperty("Alerts", true);
        var theme = getSafeNumberProperty("Theme", 0);
        var accent = getSafeNumberProperty("Accent", 0);
        var layoutMode = getSafeNumberProperty("LayoutMode", 0);
        mEngine.applyDisplaySettings(units, alerts, theme, accent, layoutMode);
    }

    private function getSafeNumberProperty(key as String, defaultVal as Number) as Number {
        try {
            var val = Properties.getValue(key);
            if (val != null) {
                return val.toNumber();
            }
        } catch (ex) {
        }
        return defaultVal;
    }

    private function getSafeBooleanProperty(key as String, defaultVal as Boolean) as Boolean {
        try {
            var val = Properties.getValue(key);
            if (val instanceof Boolean) {
                return val;
            }
            if (val != null) {
                return (val.toNumber() != 0);
            }
        } catch (ex) {
        }
        return defaultVal;
    }
}
