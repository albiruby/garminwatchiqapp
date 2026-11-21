import Toybox.Lang;

class NeedPaceBuffer {
    hidden var mRefreshInterval = 5.0;
    hidden var mChangeThreshold = 2.0;
    hidden var mLastUpdate     = 0.0;
    hidden var mLastRawPace    = 0.0;

    function reset() {
        mLastUpdate  = 0.0;
        mLastRawPace = 0.0;
    }

    function updatePace(needPaceRaw, currentTime) {
        if (needPaceRaw <= 0.0) { return 0.0; }

        var dt = currentTime - mLastUpdate;
        var dp = needPaceRaw - mLastRawPace;
        if (dp < 0) { dp = -dp; }

        var forceRefresh = (dt >= mRefreshInterval);
        var changedEnough = (dp >= mChangeThreshold);
        var firstUpdate = (mLastUpdate <= 0.0);

        if (firstUpdate || forceRefresh || changedEnough) {
            mLastRawPace = needPaceRaw;
            mLastUpdate  = currentTime;
        }

        return mLastRawPace;
    }

    function getDisplayPace() {
        return mLastRawPace;
    }
}
