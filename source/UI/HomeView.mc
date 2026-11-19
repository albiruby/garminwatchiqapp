import Toybox.Lang;
import Toybox.WatchUi;

//! Home: continue last session, six modules, history, settings.
//! Any session is reachable in <= 3 presses: module -> session -> START.
module HomeMenu {
    function build() as WatchUi.CustomMenu {
        var menu = MenuKit.newMenu("RESTORA");
        var lastId = HistoryRepository.lastSessionId();
        var last = SessionLibrary.get(lastId);
        if (last != null) {
            menu.addItem(new RowItem(:continue, "CONTINUE", last[SessionLibrary.F_NAME].toUpper() + "  "
                + Hud.mmss(SessionLibrary.totalSeconds(last)), RowItem.ICON_PLAY, null));
        }
        for (var c = 0; c < Models.CAT_COUNT; c++) {
            menu.addItem(new RowItem(c, Models.categoryName(c), Models.categorySubtitle(c).toUpper(), c, null));
        }
        menu.addItem(new RowItem(:history, "HISTORY", "THIS WEEK", RowItem.ICON_HISTORY, null));
        menu.addItem(new RowItem(:settings, "SETTINGS", "HAPTICS, COUNTDOWN", RowItem.ICON_SETTINGS, null));
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
