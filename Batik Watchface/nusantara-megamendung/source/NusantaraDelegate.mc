import Toybox.Lang;
import Toybox.WatchUi;

// Press-and-hold a slot to open its native Garmin screen (heart rate, Body Battery,
// weather, ...), like Garmin's own watch faces.
class NusantaraDelegate extends WatchUi.WatchFaceDelegate {

    private var _view as WeakReference;

    function initialize(view as NusantaraView) {
        WatchFaceDelegate.initialize();
        _view = view.weak();
    }

    function onPress(clickEvent as WatchUi.ClickEvent) as Boolean {
        var v = _view.get();
        if (!(v instanceof NusantaraView)) {
            return false;
        }
        var c = clickEvent.getCoordinates();
        return Slots.open(v.targetAt(c[0], c[1]));
    }
}
