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
        menu.addItem(toggle(:motion, "Motion", "Animations on/off", MotionConfig.enabled()));
        menu.addItem(toggle(:reducedMotion, "Reduced motion", "Key poses only", MotionConfig.reduced()));
        menu.addItem(toggle(:exerciseAnim, "Figure guide", "Animated exercise figure",
            SettingsRepository.getBool("exerciseAnim", true)));
        menu.addItem(toggle(:breathingAnim, "Breath pulse", "Pulse with each breath",
            SettingsRepository.getBool("breathingAnim", true)));
        var detail = new RowItem(:motionDetail, "Motion detail", "Low saves battery", RowItem.ICON_NONE,
            detailName(MotionConfig.detail()));
        detail.valueOn = true;
        menu.addItem(detail);
        return menu;
    }

    function toggle(id, name as String, sub as String, on as Boolean) as RowItem {
        var item = new RowItem(id, name, sub, RowItem.ICON_NONE, on ? "On" : "Off");
        item.valueOn = on;
        return item;
    }

    function detailName(d as Number) as String {
        return (d == MotionConfig.DETAIL_LOW) ? "Low" : "Std";
    }

    function keyFor(id) as String {
        if (id == :haptics) {
            return "haptics";
        } else if (id == :autoAdvance) {
            return "autoAdvance";
        } else if (id == :motion) {
            return "motion";
        } else if (id == :reducedMotion) {
            return "reducedMotion";
        } else if (id == :exerciseAnim) {
            return "exerciseAnim";
        } else if (id == :breathingAnim) {
            return "breathingAnim";
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
        } else if (id == :motionDetail) {
            var d = (MotionConfig.detail() == MotionConfig.DETAIL_LOW) ? MotionConfig.DETAIL_STANDARD : MotionConfig.DETAIL_LOW;
            SettingsRepository.set("motionDetail", d);
            row.value = SettingsMenu.detailName(d);
        } else {
            var on = !row.valueOn;
            SettingsRepository.set(SettingsMenu.keyFor(id), on);
            row.valueOn = on;
            row.value = on ? "On" : "Off";
        }
        WatchUi.requestUpdate();
    }
}
