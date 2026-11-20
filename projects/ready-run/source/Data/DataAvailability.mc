import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.ActivityMonitor;

// DataAvailability — capability checks for each metric on THIS device/SDK.
// Devices and API versions differ; we verify before using. Nothing is ever
// fabricated: an unavailable metric yields MISSING and the engines skip it.

class DataAvailability {
    var hasBodyBattery as Boolean;
    var hasStress as Boolean;
    var hasHeartRate as Boolean;
    var hasSleep as Boolean;
    var hasHrv as Boolean;
    var hasVo2 as Boolean;
    var hasRecovery as Boolean;
    var hasTrainingLoad as Boolean;

    function initialize() {
        // SensorHistory-based metrics (confirmed present in this SDK).
        hasBodyBattery = (SensorHistory has :getBodyBatteryHistory);
        hasStress = (SensorHistory has :getStressHistory);
        hasHeartRate = (SensorHistory has :getHeartRateHistory) || (ActivityMonitor has :getHeartRateHistory);
        // The following require Toybox.Health, which is NOT exposed by this
        // SDK's api.db for fr165. Guarded so the app degrades gracefully.
        hasSleep = false;
        hasHrv = false;
        hasVo2 = false;
        hasRecovery = false;
        hasTrainingLoad = false;
    }

    // Refresh capability flags (call at startup / on show).
    function refresh() as Void {
        hasBodyBattery = (SensorHistory has :getBodyBatteryHistory);
        hasStress = (SensorHistory has :getStressHistory);
        hasHeartRate = (SensorHistory has :getHeartRateHistory) || (ActivityMonitor has :getHeartRateHistory);
    }
}
