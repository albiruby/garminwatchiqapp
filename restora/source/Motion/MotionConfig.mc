import Toybox.Lang;

//! Motion settings and the frame-interval policy.
//!
//! Animation never owns session timing: SessionEngine measures real elapsed
//! time (System.getTimer deltas), so changing the frame interval, disabling
//! motion or dropping frames cannot change when an exercise or session ends.
module MotionConfig {

    const DETAIL_LOW = 0;
    const DETAIL_STANDARD = 1;

    const FRAME_STANDARD_MS = 125;  // ~8 fps while something is animating
    const FRAME_LOW_MS = 250;       // ~4 fps in low detail
    const FRAME_IDLE_MS = 1000;     // static screens: once per second

    function enabled() as Boolean { return SettingsRepository.getBool("motion", true); }
    function reduced() as Boolean { return SettingsRepository.getBool("reducedMotion", false); }
    function detail() as Number { return SettingsRepository.getNum("motionDetail", DETAIL_STANDARD); }

    function exerciseAnim() as Boolean {
        return enabled() && SettingsRepository.getBool("exerciseAnim", true);
    }

    function breathingAnim() as Boolean {
        return enabled() && SettingsRepository.getBool("breathingAnim", true);
    }

    //! True when interpolated (in-between) frames should be drawn.
    function smooth() as Boolean {
        return enabled() && !reduced();
    }

    //! Frame interval for a screen; `animating` = something on it is moving.
    function frameMs(animating as Boolean) as Number {
        if (!animating || !smooth()) {
            return FRAME_IDLE_MS;
        }
        return (detail() == DETAIL_LOW) ? FRAME_LOW_MS : FRAME_STANDARD_MS;
    }
}
