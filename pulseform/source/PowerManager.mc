import Toybox.Lang;
import Toybox.System;

// Always-on rules for AMOLED: once-per-minute updates (no timers, no partial updates;
// FR165 is not in onPartialUpdate's device list), dim colours, and a small position
// shift every minute so no pixel stays lit in the same place.
module PowerManager {

    const AOD_TIME = 0x9DA1A8;
    const AOD_TEXT = 0x7C8088;   // 5.3:1 on black (WCAG AA)

    const SHIFTS = [[0, 0], [2, 0], [2, 2], [0, 2], [-2, 2], [-2, 0], [-2, -2], [0, -2], [2, -2]];

    function burnInDevice() as Boolean {
        var s = System.getDeviceSettings();
        return (s has :requiresBurnInProtection) && s.requiresBurnInProtection;
    }

    function shift(minute as Number) as Array<Number> {
        return SHIFTS[minute % SHIFTS.size()] as Array<Number>;
    }
}
