import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.Sensor;

//! Capability checks only. Sensors are an optional enrichment: nothing in the
//! session engine or calculators depends on them.
//!
//! Stress / Body Battery (Toybox.SensorHistory) need the SensorHistory
//! permission and are planned for V1.1 after on-device validation on FR165,
//! so they are intentionally not referenced yet.
module SensorAvailability {

    //! Recent wrist HR samples from the daily monitor.
    function hasHeartRateHistory() as Boolean {
        return ActivityMonitor has :getHeartRateHistory;
    }

    //! Live heart rate (Sensor.getInfo().heartRate).
    function hasLiveHeartRate() as Boolean {
        return Sensor has :getInfo;
    }

    //! Beat-to-beat intervals for HRV (Sensor.registerSensorDataListener).
    function hasBeatIntervals() as Boolean {
        return Sensor has :registerSensorDataListener;
    }

    //! "HR + HRV", "HR", or "None" for the Settings screen.
    function summary() as String {
        if (hasLiveHeartRate() && hasBeatIntervals()) {
            return "HR + HRV";
        }
        if (hasLiveHeartRate() || hasHeartRateHistory()) {
            return "HR";
        }
        return "None";
    }
}
