import Toybox.Lang;
import Toybox.WatchUi;

//! On-watch settings (same properties as the phone settings page).
//! Rows show their value on the right: ON (mint) / OFF (grey) / 3S.
module SettingsMenu {
    function build() as WatchUi.CustomMenu {
        var menu = MenuKit.newMenu("SETTINGS");
        menu.addItem(toggle(:haptics, "HAPTICS", "VIBRATION CUES", SettingsRepository.hapticsEnabled()));
        var cd = new RowItem(:countdown, "COUNTDOWN", "BEFORE START", RowItem.ICON_NONE,
            SettingsRepository.countdownSec().toString() + "S");
        cd.valueOn = true;
        menu.addItem(cd);
        menu.addItem(toggle(:autoAdvance, "AUTO NEXT", "ADVANCE EXERCISES", SettingsRepository.autoAdvance()));
        menu.addItem(toggle(:hrSnapshot, "HR CHECK", "GARMIN HR BEFORE/AFTER", SettingsRepository.hrSnapshot()));
        return menu;
    }

    function toggle(id, name as String, sub as String, on as Boolean) as RowItem {
        var item = new RowItem(id, name, sub, RowItem.ICON_NONE, on ? "ON" : "OFF");
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
            row.value = nextVal.toString() + "S";
        } else {
            var on = !row.valueOn;
            SettingsRepository.set(SettingsMenu.keyFor(id), on);
            row.valueOn = on;
            row.value = on ? "ON" : "OFF";
        }
        WatchUi.requestUpdate();
    }
}
