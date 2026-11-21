import Toybox.Lang;

//! Entry point for sensor snapshots around a session. Respects the user's
//! "HR before/after" setting (off by default).
module SensorManager {

    function snapshotHr() {
        if (!SettingsRepository.hrSnapshot()) {
            return null;
        }
        return HeartRateProvider.current();
    }
}
