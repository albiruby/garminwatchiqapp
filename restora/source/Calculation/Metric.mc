import Toybox.Lang;

//! Where a metric value comes from. Derived values must never be presented
//! as Garmin measurements.
module MetricSource {
    const MEASURED = 0;   // read from a Garmin sensor / API
    const CALCULATED = 1; // derived by the RESTORA Calculation Engine
    const USER = 2;       // configured or entered by the user
}

//! A single metric value with its unit and provenance.
//! `value` is null when the input data is not available - it is never
//! replaced by an estimate.
class Metric {
    var label as String;
    var value;
    var unit as String;
    var source as Number;

    function initialize(label as String, value, unit as String, source as Number) {
        self.label = label;
        self.value = value;
        self.unit = unit;
        self.source = source;
    }

    function isAvailable() as Boolean {
        return value != null;
    }

    function sourceLabel() as String {
        if (source == MetricSource.MEASURED) {
            return "Garmin";
        } else if (source == MetricSource.USER) {
            return "You";
        }
        return "RESTORA calc";
    }

    //! Display text; "--" when unavailable.
    function display() as String {
        if (value == null) {
            return "--";
        }
        if (value instanceof Float || value instanceof Double) {
            return value.format("%.2f") + unit;
        }
        return value.toString() + unit;
    }
}
