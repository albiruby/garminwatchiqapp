import Toybox.Lang;
import Toybox.WatchUi;

// MainDelegate — navigation. UP/DOWN move through the flattened page list
// (sub-pages first, then next screen). START refreshes data. BACK returns.
// Fully usable without touch; no critical function behind tiny targets.

class MainDelegate extends WatchUi.BehaviorDelegate {
    var _nav as NavModel;
    var _state as AppState;

    function initialize(nav as NavModel, state as AppState) {
        BehaviorDelegate.initialize();
        _nav = nav;
        _state = state;
    }

    function onNextPage() as Boolean {
        _nav.next();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Boolean {
        _nav.prev();
        WatchUi.requestUpdate();
        return true;
    }

    // START: re-run data + engines.
    function onSelect() as Boolean {
        _state.refresh();
        WatchUi.requestUpdate();
        return true;
    }

    // BACK: pop to previous page; on HOME let the system close the app.
    function onBack() as Boolean {
        if (_nav.currentPage == 0) {
            return false;  // exit app from HOME
        }
        _nav.prev();
        WatchUi.requestUpdate();
        return true;
    }
}
