import Toybox.Lang;

//! Input validation and safe arithmetic. Every function passes null through
//! and returns null instead of inventing a value.
module MetricValidator {

    const HR_MIN = 25;
    const HR_MAX = 250;

    //! Returns v if lo <= v <= hi, otherwise null.
    function inRange(v, lo, hi) {
        if (v == null) {
            return null;
        }
        if (v < lo || v > hi) {
            return null;
        }
        return v;
    }

    function validHr(v) {
        return inRange(v, HR_MIN, HR_MAX);
    }

    //! Garmin Stress and Body Battery are both 0..100.
    function validScale100(v) {
        return inRange(v, 0, 100);
    }

    //! num / den as Float, or null if either is null or den is 0.
    function safeDivide(num, den) {
        if (num == null || den == null || den == 0) {
            return null;
        }
        return num.toFloat() / den.toFloat();
    }

    //! Rounded integer percentage part/whole*100, or null if whole is 0.
    function percent(part, whole) {
        if (part == null || whole == null || whole <= 0 || part < 0) {
            return null;
        }
        return (part * 100 + whole / 2) / whole;
    }

    //! Rounded integer mean of a non-empty Number array, or null.
    function roundedMean(sum, count) {
        if (sum == null || count == null || count <= 0) {
            return null;
        }
        return (sum + count / 2) / count;
    }
}
