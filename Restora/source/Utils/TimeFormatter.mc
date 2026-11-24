import Toybox.Lang;

module TimeFormatter {

    //! Seconds -> "m:ss" (or "h:mm:ss" for an hour or more).
    function clock(seconds as Number) as String {
        if (seconds < 0) {
            seconds = 0;
        }
        var h = seconds / 3600;
        var m = (seconds % 3600) / 60;
        var s = seconds % 60;
        if (h > 0) {
            return h.format("%d") + ":" + m.format("%02d") + ":" + s.format("%02d");
        }
        return m.format("%d") + ":" + s.format("%02d");
    }

    //! Seconds -> "N min" rounded.
    function minutes(seconds as Number) as String {
        return RecordUtil.toMinutes(seconds).format("%d") + " min";
    }
}
