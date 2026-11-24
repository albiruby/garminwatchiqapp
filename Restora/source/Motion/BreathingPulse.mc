import Toybox.Graphics;
import Toybox.Lang;

//! Breathing visual: a disc that expands on inhale, stays full on the hold
//! after inhale, contracts on exhale and stays small on the pause. Driven by
//! the Session Engine's phase and phase progress, so it is always in step
//! with the haptic cues and never drifts.
module BreathingPulse {

    //! Disc radius for phase 0..3 and progress 0..1000 (eased, in-out sine).
    function radius(phase as Number, permille as Number, rMin as Number, rMax as Number) as Number {
        var k = Easing.apply(Easing.IN_OUT_SINE, permille / 1000.0);
        if (phase == 0) {
            return (rMin + (rMax - rMin) * k).toNumber();
        } else if (phase == 1) {
            return rMax;
        } else if (phase == 2) {
            return (rMax - (rMax - rMin) * k).toNumber();
        }
        return rMin;
    }

    function draw(dc as Graphics.Dc, cx as Number, cy as Number, r as Number) as Void {
        dc.setColor(Theme.SURFACE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(Theme.GREEN_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy, r);
        dc.setPenWidth(1);
    }
}
