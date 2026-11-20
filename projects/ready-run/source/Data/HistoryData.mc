import Toybox.Application;
import Toybox.Lang;

// HistoryData — stored trend values across launches (Application.Storage).
// V1 stores a short rolling history of readiness / form / load to derive
// trends (Improving / Stable / Declining). Empty history => NOT AVAILABLE.

module HistoryData {
    const KEY_READINESS = "rr.readinessHistory";   // Array of Number (scores)
    const KEY_FORM = "rr.formHistory";
    const KEY_COUNT = 6;

    // Load a stored array of Numbers, or empty array.
    function loadInts(key as String) as Array {
        var stored = Application.Storage.getValue(key);
        if (stored == null) {
            return [] as Array<Number>;
        }
        if (stored instanceof Array) {
            return stored;
        }
        return [] as Array<Number>;
    }

    // Append a value, keeping the last KEY_COUNT entries.
    function push(key as String, value as Number) as Void {
        var arr = loadInts(key);
        var out = [] as Array<Number>;
        var start = arr.size() - (KEY_COUNT - 1);
        var i;
        if (start < 0) { start = 0; }
        for (i = start; i < arr.size(); i++) {
            out.add(arr[i]);
        }
        out.add(value);
        Application.Storage.setValue(key, out);
    }

    // Trend from the stored series: +1 improving, 0 stable, -1 declining, 2 n/a.
    // Compares the average of the back half vs the front half.
    function trendOf(key as String) as Number {
        var arr = loadInts(key);
        if (arr.size() < 3) {
            return 2;  // not enough data
        }
        var n = arr.size();
        var half = n / 2;
        if (half < 1) { half = 1; }
        var sumA = 0;
        var sumB = 0;
        var i;
        for (i = 0; i < half; i++) { sumA = sumA + arr[i]; }
        for (i = n - half; i < n; i++) { sumB = sumB + arr[i]; }
        var avgA = sumA / half;
        var avgB = sumB / half;
        var delta = avgB - avgA;
        if (delta >= 3) { return 1; }
        if (delta <= -3) { return -1; }
        return 0;
    }
}
