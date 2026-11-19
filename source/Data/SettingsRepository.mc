import Toybox.Application;
import Toybox.Lang;

//! User settings stored in Application.Properties (editable from the phone
//! via Connect IQ settings, or on the watch via SettingsView).
module SettingsRepository {

    function getBool(key as String, dflt as Boolean) as Boolean {
        try {
            var v = Application.Properties.getValue(key);
            return (v == null) ? dflt : (v as Boolean);
        } catch (e) {
            return dflt;
        }
    }

    function getNum(key as String, dflt as Number) as Number {
        try {
            var v = Application.Properties.getValue(key);
            return (v == null) ? dflt : (v as Number);
        } catch (e) {
            return dflt;
        }
    }

    function set(key as String, value) as Void {
        try {
            Application.Properties.setValue(key, value);
        } catch (e) {
            // Keep running with the previous value.
        }
    }

    function hapticsEnabled() as Boolean { return getBool("haptics", true); }
    function autoAdvance() as Boolean { return getBool("autoAdvance", true); }
    function hrSnapshot() as Boolean { return getBool("hrSnapshot", false); }
    function countdownSec() as Number { return getNum("countdown", 3); }
}
