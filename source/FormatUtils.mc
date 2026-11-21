import Toybox.Lang;

module FormatUtils {

    // 12345 -> "12,345"
    function thousands(n as Number) as String {
        var neg = n < 0;
        var v = neg ? -n : n;
        var s = "";
        while (v >= 1000) {
            s = "," + (v % 1000).format("%03d") + s;
            v = v / 1000;
        }
        return (neg ? "-" : "") + v.toString() + s;
    }

    // Compact count for tight spots: 950, 9.5K, 12K
    function compact(n as Number) as String {
        if (n < 1000) {
            return n.toString();
        }
        if (n < 10000) {
            var tenths = n / 100;
            return (tenths / 10).toString() + "." + (tenths % 10).toString() + "K";
        }
        return (n / 1000).toString() + "K";
    }

    // Centimetres -> "5.24" (km or mi); 2 decimals below 10, 1 below 100, else none.
    function distance(cm as Number, metric as Boolean) as String {
        var d = cm / (metric ? 100000.0 : 160934.4);
        if (d < 10.0) {
            return trunc(d, 100).format("%.2f");
        }
        if (d < 100.0) {
            return trunc(d, 10).format("%.1f");
        }
        return d.toNumber().toString();
    }

    // Rounds down so a shown distance never exceeds what was covered.
    function trunc(v as Float, scale as Number) as Float {
        return (v * scale).toNumber().toFloat() / scale;
    }

    function distanceUnit(metric as Boolean) as String {
        return metric ? "KM" : "MI";
    }

    // Returns [time, marker]: marker is "AM"/"PM" in 12-hour mode, else "".
    function clock(hour as Number, min as Number, twelve as Boolean) as Array<String> {
        if (!twelve) {
            return [hour.format("%02d") + ":" + min.format("%02d"), ""];
        }
        var h = hour % 12;
        if (h == 0) {
            h = 12;
        }
        return [h.toString() + ":" + min.format("%02d"), hour < 12 ? "AM" : "PM"];
    }

    function percent(p as Number) as String {
        return p.toString() + "%";
    }
}
