import Toybox.ActivityMonitor;
import Toybox.Lang;

//! Capability checks only. Sensors are an optional enrichment: nothing in the
//! session engine or calculators depends on them.
//!
//! Stress / Body Battery (Toybox.SensorHistory) need the SensorHistory
//! permission and are planned for V1.1 after on-device validation on FR165,
//! so they are intentionally not referenced yet.
module SensorAvailability {

    function hasHeartRateHistory() as Boolean {
        return ActivityMonitor has :getHeartRateHistory;
    }
}
