import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// MainView — thin renderer. NO business logic here. It reads the precomputed
// AppState (engines already ran in AppState.refresh) + NavModel, then draws the
// current screen via its component. All calculation happens outside onUpdate.

class MainView extends WatchUi.View {
    var _state as AppState;
    var _nav as NavModel;
    var _sz as SafeZone or Null;
    var _layout as Layout or Null;
    var _initialized as Boolean;

    function initialize(state as AppState, nav as NavModel) {
        View.initialize();
        _state = state;
        _nav = nav;
        _sz = null;
        _layout = null;
        _initialized = false;
    }

    function onLayout(dc as Dc) as Void {
        // Build the safe-zone + layout system from the real device dimensions.
        _sz = new SafeZone(dc.getWidth(), dc.getHeight());
        _layout = new Layout(_sz);
        _initialized = true;
    }

    function onUpdate(dc as Dc) as Void {
        // Guard: if layout not built yet (edge case), build now.
        if (!_initialized || _sz == null) {
            onLayout(dc);
        }

        // 1) Clear background.
        dc.setColor(Colors.arg(ColorKey.BACKGROUND), Colors.arg(ColorKey.BACKGROUND));
        dc.clear();

        // 2) Dispatch to the current screen (render only).
        var screen = _nav.screenOf(_nav.currentPage);
        var sub = _nav.subOf(_nav.currentPage);
        if (screen == ScreenId.HOME) {
            HomeScreen.draw(dc, _sz, _layout, _state, sub);
        } else if (screen == ScreenId.BODY) {
            BodyReadinessScreen.draw(dc, _sz, _layout, _state, sub);
        } else if (screen == ScreenId.STATUS) {
            TrainingStatusScreen.draw(dc, _sz, _layout, _state, sub);
        } else if (screen == ScreenId.FORM) {
            TrainingFormScreen.draw(dc, _sz, _layout, _state, sub);
        } else {
            TodayScreen.draw(dc, _sz, _layout, _state, sub);
        }

        // 3) Pagination dots (reflect current screen's sub-pages).
        Pagination.draw(dc, _sz, _layout, sub, _nav.subCountOf(_nav.currentPage));

        // 4) Optional dev overlay (disabled in production).
        DevOverlay.draw(dc, _sz, _layout);
    }
}
