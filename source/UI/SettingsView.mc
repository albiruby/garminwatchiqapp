import Toybox.Lang;
import Toybox.WatchUi;

//! On-watch settings (same properties as the phone settings page).
//! Rows show their value on the right: On (green) / Off (grey) / 3 s.
module SettingsMenu {
    function build() as WatchUi.CustomMenu {
        var menu = MenuKit.newMenu("Settings", null, false);
        menu.addItem(toggle(:haptics, "Haptics", "Vibration cues", SettingsRepository.hapticsEnabled()));
        var cd = new RowItem(:countdown, "Countdown", "Before start", RowItem.ICON_NONE,
            SettingsRepository.countdownSec().toString() + " s");
        cd.valueOn = true;
        menu.addItem(cd);
        menu.addItem(toggle(:autoAdvance, "Auto next", "Advance exercises", SettingsRepository.autoAdvance()));
        menu.addItem(toggle(:hrSnapshot, "HR check", "Garmin HR before/after", SettingsRepository.hrSnapshot()));
        return menu;
    }

    function toggle(id, name as String, sub as String, on as Boolean) as RowItem {
        var item = new RowItem(id, name, sub, RowItem.ICON_NONE, on ? "On" : "Off");
        item.valueOn = on;
        return item;
    }

    function keyFor(id) as String {
        if (id == :haptics) {
            return "haptics";
        } else if (id == :autoAdvance) {
            return "autoAdvance";
        }
        return "hrSnapshot";
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var row = item as RowItem;
        var id = item.getId();
        if (id == :countdown) {
            var cur = SettingsRepository.countdownSec();
            var nextVal = (cur == 3) ? 5 : ((cur == 5) ? 10 : 3);
            SettingsRepository.set("countdown", nextVal);
            row.value = nextVal.toString() + " s";
        } else {
            var on = !row.valueOn;
            SettingsRepository.set(SettingsMenu.keyFor(id), on);
            row.valueOn = on;
            row.value = on ? "On" : "Off";
        }
        WatchUi.requestUpdate();
    }
}
