import Toybox.Lang;
import Toybox.WatchUi;

//! Session list for one module.
module ModuleMenu {
    function build(cat as Number) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => Models.categoryName(cat)});
        var ids = SessionLibrary.idsFor(cat);
        for (var i = 0; i < ids.size(); i++) {
            var def = SessionLibrary.get(ids[i]);
            if (def != null) {
                menu.addItem(new WatchUi.MenuItem(def[SessionLibrary.F_NAME],
                    TimeFormatter.minutes(SessionLibrary.totalSeconds(def)) + " - " + def[SessionLibrary.F_DESC],
                    ids[i], null));
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
