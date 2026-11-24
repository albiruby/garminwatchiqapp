import Toybox.Lang;
import Toybox.WatchUi;

// Touch and the five FR165 buttons both route to the view:
// tap/START select, UP/DOWN move focus or change a picker, long-press UP opens the menu,
// swipe up opens the menu, BACK leaves (saving first).
class FishTankDelegate extends WatchUi.BehaviorDelegate {
    var _v;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _v = view;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var c = Scale.canvas(evt.getCoordinates());
        _v.handleTap(c[0], c[1]);
        return true;
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        return _v.handleSwipe(evt.getDirection());
    }

    function onSelect() as Boolean {
        _v.handleSelect();
        return true;
    }

    function onNextPage() as Boolean {
        _v.handleStep(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _v.handleStep(-1);
        return true;
    }

    function onMenu() as Boolean {
        _v.handleMenu();
        return true;
    }

    function onBack() as Boolean {
        return _v.handleBack();
    }
}
