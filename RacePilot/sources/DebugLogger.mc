import Toybox.Lang;

class DebugLogger {
    var enabled = false;
    private var mLogBuf as Array<String?> = new Array<String?>[20];
    private var mLogIdx as Number = 0;
    private var mLogCnt as Number = 0;

    public function initialize() {
        reset();
    }

    function reset() {
        mLogBuf = new Array<String?>[20];
        mLogIdx = 0;
        mLogCnt = 0;
    }

    function log(entry as String) as Void {
        if (!enabled) { return; }
        mLogBuf[mLogIdx] = entry;
        mLogIdx = (mLogIdx + 1) % 20;
        if (mLogCnt < 20) { mLogCnt += 1; }
    }

    function logFrame(conf as Number, state as String, pace as Float, dist as Float, time as Float) as Void {
        if (!enabled) { return; }
        var entry = state + " C:" + conf + " P:" + pace.format("%.1f") + " D:" + dist.format("%.0f") + " T:" + time.format("%.0f");
        log(entry);
    }

    function getLastEntry() as String? {
        if (mLogCnt == 0) { return null; }
        var actualIdx = (mLogIdx - 1 + 20) % 20;
        return mLogBuf[actualIdx];
    }

    function getLogCount() as Number {
        return mLogCnt;
    }
}
