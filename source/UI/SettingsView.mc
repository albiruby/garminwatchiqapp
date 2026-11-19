import Toybox.Lang;
import Toybox.WatchUi;

//! On-watch settings (same properties as the phone settings page).
module SettingsMenu {
    function build() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => "SETTINGS"});
        menu.addItem(new WatchUi.ToggleMenuItem("Haptics", null, :haptics, SettingsRepository.hapticsEnabled(), null));
        menu.addItem(new WatchUi.MenuItem("Countdown", SettingsRepository.countdownSec().toString() + " sec", :countdown, null));
        menu.addItem(new WatchUi.ToggleMenuItem("Auto-advance", null, :autoAdvance, SettingsRepository.autoAdvance(), null));
        menu.addItem(new WatchUi.ToggleMenuItem("HR before/after", "Garmin HR, optional", :hrSnapshot, SettingsRepository.hrSnapshot(), null));
        return menu;
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :countdown) {
            var cur = SettingsRepository.countdownSec();
            var nextVal = (cur == 3) ? 5 : ((cur == 5) ? 10 : 3);
            SettingsRepository.set("countdown", nextVal);
            item.setSubLabel(nextVal.toString() + " sec");
            WatchUi.requestUpdate();
        } else if (item instanceof WatchUi.ToggleMenuItem) {
            var key = (id == :haptics) ? "haptics" : ((id == :autoAdvance) ? "autoAdvance" : "hrSnapshot");
            SettingsRepository.set(key, item.isEnabled());
        }
    }
}
