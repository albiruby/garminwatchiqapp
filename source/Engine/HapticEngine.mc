import Toybox.Attention;
import Toybox.Lang;

//! Haptic cues. Forerunner devices use a single vibration strength, so cues
//! are distinguished by count and spacing, not intensity.
module HapticEngine {

    const PULSE_MS = 120;
    const GAP_MS = 140;

    function single() as Void {
        pulses(1, PULSE_MS);
    }

    function doublePulse() as Void {
        pulses(2, PULSE_MS);
    }

    function triple() as Void {
        pulses(3, 200);
    }

    //! Side change: one long pulse.
    function side() as Void {
        pulses(1, 400);
    }

    function pulses(count as Number, lengthMs as Number) as Void {
        if (!SettingsRepository.hapticsEnabled()) {
            return;
        }
        if (!(Attention has :vibrate)) {
            return;
        }
        var profile = [];
        for (var i = 0; i < count; i++) {
            if (i > 0) {
                profile.add(new Attention.VibeProfile(0, GAP_MS));
            }
            profile.add(new Attention.VibeProfile(50, lengthMs));
        }
        Attention.vibrate(profile);
    }

    //! Map engine event bits to a cue (highest priority wins).
    function forEvents(evt as Number) as Void {
        if ((evt & SessionEngine.EVT_COMPLETE) != 0) {
            triple();
        } else if ((evt & SessionEngine.EVT_STEP_START) != 0) {
            doublePulse();
        } else if ((evt & SessionEngine.EVT_SIDE) != 0) {
            side();
        } else if ((evt & SessionEngine.EVT_PHASE) != 0) {
            single();
        }
    }
}
