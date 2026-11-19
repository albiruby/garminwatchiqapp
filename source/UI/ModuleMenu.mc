import Toybox.Lang;
import Toybox.WatchUi;

//! Session list for one module: name, then duration and step count.
module ModuleMenu {
    function build(cat as Number) as WatchUi.CustomMenu {
        var menu = MenuKit.newMenu(Models.categoryName(cat));
        var ids = SessionLibrary.idsFor(cat);
        for (var i = 0; i < ids.size(); i++) {
            var def = SessionLibrary.get(ids[i]);
            if (def != null) {
                var steps = def[SessionLibrary.F_STEPS].size();
                menu.addItem(new RowItem(ids[i], def[SessionLibrary.F_NAME].toUpper(),
                    steps.toString() + (steps == 1 ? " STEP" : " STEPS"), RowItem.ICON_NONE,
                    Hud.mmss(SessionLibrary.totalSeconds(def))));
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
