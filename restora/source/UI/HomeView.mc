import Toybox.Lang;
import Toybox.WatchUi;

//! Home: continue last session, six modules, history, settings.
//! Any session is reachable in <= 3 presses: module -> session -> START.
module HomeMenu {
    function build() as WatchUi.CustomMenu {
        var menu = MenuKit.newMenu("RESTORA", "RECOVERY COMPANION", true);
        var lastId = HistoryRepository.lastSessionId();
        var last = SessionLibrary.get(lastId);
        if (last != null) {
            menu.addItem(new RowItem(:continue, "Continue", last[SessionLibrary.F_NAME] + " · "
                + RecordUtil.toMinutes(SessionLibrary.totalSeconds(last)).toString() + " min", Icons.PLAY, null));
        }
        for (var c = 0; c < Models.CAT_COUNT; c++) {
            menu.addItem(new RowItem(c, Models.categoryName(c), Models.categorySubtitle(c), c, null));
        }
        menu.addItem(new RowItem(:history, "History", "Week and sessions", Icons.HISTORY, null));
        menu.addItem(new RowItem(:settings, "Settings", "Haptics, countdown", Icons.SETTINGS, null));
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
            WatchUi.pushView(HistoryList.build(), new HistoryListDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :settings) {
            WatchUi.pushView(SettingsMenu.build(), new SettingsMenuDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id instanceof Number) {
            WatchUi.pushView(ModuleMenu.build(id), new ModuleMenuDelegate(), WatchUi.SLIDE_LEFT);
        }
    }
}
