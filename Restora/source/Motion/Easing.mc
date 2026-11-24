import Toybox.Lang;
import Toybox.Math;

//! Interpolation and easing curves (MotionInterpolator). t in 0..1 -> 0..1.
module Easing {

    const LINEAR = 0;
    const IN_OUT_SINE = 1;   // breathing-like, symmetric
    const OUT_CUBIC = 2;     // quick start, soft landing (transitions)
    const IN_OUT_QUAD = 3;   // gentle repetitions

    function clamp01(t) as Float {
        if (t < 0) {
            return 0.0;
        }
        return (t > 1) ? 1.0 : t.toFloat();
    }

    function apply(kind as Number, t) as Float {
        var x = clamp01(t);
        if (kind == IN_OUT_SINE) {
            return (0.5 - 0.5 * Math.cos(Math.PI * x)).toFloat();
        } else if (kind == OUT_CUBIC) {
            var u = 1.0 - x;
            return 1.0 - u * u * u;
        } else if (kind == IN_OUT_QUAD) {
            if (x < 0.5) {
                return 2 * x * x;
            }
            var v = 1.0 - x;
            return 1.0 - 2 * v * v;
        }
        return x;
    }

    function lerp(a, b, t) as Float {
        return (a + (b - a) * t).toFloat();
    }
}
