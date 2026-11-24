import Toybox.Lang;

//! Read helpers for history records (see Models K_* keys).
module RecordUtil {

    function getNum(record as Dictionary, key as String, dflt) {
        var v = record.get(key);
        return (v == null) ? dflt : v;
    }

    function tagSeconds(record as Dictionary, tag as String) {
        var tags = record.get(Models.K_TAGS);
        if (tags == null) {
            return 0;
        }
        var v = tags.get(tag);
        return (v == null) ? 0 : v;
    }

    //! True if from <= start < to (epoch seconds).
    function inWindow(record as Dictionary, from as Number, to as Number) as Boolean {
        var s = record.get(Models.K_START);
        return s != null && s >= from && s < to;
    }

    function isCompleted(record as Dictionary) as Boolean {
        return getNum(record, Models.K_STATUS, Models.STATUS_CANCELLED) == Models.STATUS_COMPLETED;
    }

    //! Local day index: days since epoch in the user's time zone.
    function dayIndex(epoch as Number, tzOffset as Number) as Number {
        return (epoch + tzOffset) / Models.SECONDS_PER_DAY;
    }

    //! Local hour of day 0..23.
    function localHour(epoch as Number, tzOffset as Number) as Number {
        return ((epoch + tzOffset) % Models.SECONDS_PER_DAY) / 3600;
    }

    //! UTC epoch of local midnight for a local day index.
    function dayStart(dayIdx as Number, tzOffset as Number) as Number {
        return dayIdx * Models.SECONDS_PER_DAY - tzOffset;
    }

    //! Sum of actual durations (seconds) of records in [from, to).
    function sumDuration(history as Array, from as Number, to as Number) {
        var total = 0;
        for (var i = 0; i < history.size(); i++) {
            if (inWindow(history[i], from, to)) {
                total += getNum(history[i], Models.K_DUR, 0);
            }
        }
        return total;
    }

    //! Sum of seconds for a tag across records in [from, to).
    function sumTag(history as Array, tag as String, from as Number, to as Number) {
        var total = 0;
        for (var i = 0; i < history.size(); i++) {
            if (inWindow(history[i], from, to)) {
                total += tagSeconds(history[i], tag);
            }
        }
        return total;
    }

    //! Rounded minutes from seconds.
    function toMinutes(seconds as Number) as Number {
        return (seconds + 30) / 60;
    }
}
