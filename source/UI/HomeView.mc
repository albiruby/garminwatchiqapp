import Toybox.Lang;
import Toybox.WatchUi;

//! Home: six modules, quick access to the last session, history, settings.
//! Any session is reachable in <= 3 presses: module -> session -> start.
module HomeMenu {
    function build() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => "RESTORA"});
        var lastId = HistoryRepository.lastSessionId();
        var last = SessionLibrary.get(lastId);
        if (last != null) {
            menu.addItem(new WatchUi.MenuItem("Continue", last[SessionLibrary.F_NAME] + " - "
                + TimeFormatter.minutes(SessionLibrary.totalSeconds(last)), :continue, null));
        }
        for (var c = 0; c < Models.CAT_COUNT; c++) {
            menu.addItem(new WatchUi.MenuItem(Models.categoryName(c), Models.categorySubtitle(c), c, null));
        }
        menu.addItem(new WatchUi.MenuItem("HISTORY", "Your practice", :history, null));
        menu.addItem(new WatchUi.MenuItem("SETTINGS", "Haptics, countdown", :settings, null));
        return menu;
    }
}

class HomeMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :continue) {
            var lastId = HistoryRepository.lastSessionId();
            if (SessionLibrary.get(lastId) != null) {
                SessionDetail.push(lastId);
            }
        } else if (id == :history) {
            var hv = new HistoryView();
            WatchUi.pushView(hv, new HistoryDelegate(hv), WatchUi.SLIDE_LEFT);
        } else if (id == :settings) {
            WatchUi.pushView(SettingsMenu.build(), new SettingsMenuDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id instanceof Number) {
            WatchUi.pushView(ModuleMenu.build(id), new ModuleMenuDelegate(), WatchUi.SLIDE_LEFT);
        }
    }
}
