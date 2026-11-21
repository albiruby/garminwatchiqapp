import Toybox.Application;
import Toybox.Lang;

//! Local, bounded session history in Application.Storage.
//! Stored oldest -> newest; the oldest record is dropped beyond MAX_RECORDS.
module HistoryRepository {

    const KEY_HISTORY = "history";
    const KEY_LAST = "lastSession";
    const MAX_RECORDS = 100;

    function load() as Array {
        try {
            var h = Application.Storage.getValue(KEY_HISTORY);
            if (h instanceof Array) {
                return h;
            }
        } catch (e) {
        }
        return [];
    }

    //! Append a record; returns false if storage failed (e.g. full).
    function append(record as Dictionary) as Boolean {
        var h = load();
        h.add(record);
        while (h.size() > MAX_RECORDS) {
            h = h.slice(1, null);
        }
        try {
            Application.Storage.setValue(KEY_HISTORY, h);
            Application.Storage.setValue(KEY_LAST, record.get(Models.K_ID));
            return true;
        } catch (e) {
            return false;
        }
    }

    function lastSessionId() {
        try {
            return Application.Storage.getValue(KEY_LAST);
        } catch (e) {
            return null;
        }
    }

    function clear() as Void {
        try {
            Application.Storage.deleteValue(KEY_HISTORY);
            Application.Storage.deleteValue(KEY_LAST);
        } catch (e) {
        }
    }
}
