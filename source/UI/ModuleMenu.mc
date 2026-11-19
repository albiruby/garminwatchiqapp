import Toybox.Lang;
import Toybox.WatchUi;

//! Session list for one module: name, then "5 steps · 10 min".
module ModuleMenu {
    function build(cat as Number) as WatchUi.CustomMenu {
        var ids = SessionLibrary.idsFor(cat);
        var menu = MenuKit.newMenu(Models.categoryName(cat), ids.size().toString() + " SESSIONS", false);
        for (var i = 0; i < ids.size(); i++) {
            var def = SessionLibrary.get(ids[i]);
            if (def != null) {
                var steps = def[SessionLibrary.F_STEPS].size();
                menu.addItem(new RowItem(ids[i], def[SessionLibrary.F_NAME],
                    steps.toString() + (steps == 1 ? " step" : " steps") + " · "
                        + RecordUtil.toMinutes(SessionLibrary.totalSeconds(def)).toString() + " min",
                    RowItem.ICON_NONE, null));
            }
        }
        return menu;
    }
}

class ModuleMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        SessionDetail.push(item.getId());
    }
}
