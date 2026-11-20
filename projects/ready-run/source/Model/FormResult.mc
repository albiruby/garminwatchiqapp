import Toybox.Lang;

// FormResult — output of FormEngine. FORM = FITNESS - FATIGUE, normalized 0..100.

class FormResult {
    var score as Number or Null;   // 0..100 or null
    var status as String;          // POOR / LOW / MODERATE / HIGH / PRIME / NOT AVAILABLE
    var colorKey as Number;
    var available as Boolean;

    var fitnessPct as Number or Null;   // 0..100
    var fatiguePct as Number or Null;   // 0..100
    var trend as String;                // IMPROVING / STABLE / DECLINING / NOT AVAILABLE
    var trendColorKey as Number;
    var balance as String;              // GOOD / EVEN / POOR / NOT AVAILABLE
    var balanceColorKey as Number;

    function initialize() {
        score = null;
        status = "NOT AVAILABLE";
        colorKey = ColorKey.MUTED;
        available = false;
        fitnessPct = null;
        fatiguePct = null;
        trend = "NOT AVAILABLE";
        trendColorKey = ColorKey.MUTED;
        balance = "NOT AVAILABLE";
        balanceColorKey = ColorKey.MUTED;
    }
}
