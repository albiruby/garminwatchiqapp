import Toybox.Lang;

// NavModel — linear navigation over a flattened page list. Each screen may own
// several sub-pages; DOWN advances through a screen's sub-pages FIRST, then to
// the next screen. Pagination dots reflect the current screen's sub-pages only.
//
// Screen order: HOME -> BODY READINESS -> TRAINING STATUS -> TRAINING FORM -> TODAY

module ScreenId {
    const HOME = 0;
    const BODY = 1;
    const STATUS = 2;
    const FORM = 3;
    const TODAY = 4;
}

class NavModel {
    // Sub-page count per screen (index = ScreenId).
    var subCounts as Array<Number>;
    var screenCount as Number;
    var currentPage as Number;   // flattened index
    var totalPages as Number;

    function initialize() {
        // HOME 1, BODY 2, STATUS 2, FORM 2, TODAY 1  => 8 pages.
        subCounts = [1, 2, 2, 2, 1] as Array<Number>;
        screenCount = 5;
        currentPage = 0;
        totalPages = 0;
        var i;
        for (i = 0; i < subCounts.size(); i++) {
            totalPages = totalPages + (subCounts[i] as Number);
        }
    }

    function next() as Void {
        currentPage = currentPage + 1;
        if (currentPage >= totalPages) { currentPage = 0; }  // wrap
    }

    function prev() as Void {
        currentPage = currentPage - 1;
        if (currentPage < 0) { currentPage = totalPages - 1; }  // wrap
    }

    function goHome() as Void {
        currentPage = 0;
    }

    // Screen id for the current flattened page.
    function screenOf(page as Number) as Number {
        var acc = 0;
        var i;
        for (i = 0; i < subCounts.size(); i++) {
            acc = acc + (subCounts[i] as Number);
            if (page < acc) { return i; }
        }
        return screenCount - 1;
    }

    // Sub-page index (0-based) of the current flattened page within its screen.
    function subOf(page as Number) as Number {
        var acc = 0;
        var i;
        var start;
        for (i = 0; i < subCounts.size(); i++) {
            start = acc;
            acc = acc + (subCounts[i] as Number);
            if (page < acc) { return page - start; }
        }
        return 0;
    }

    // Number of sub-pages for the screen that owns `page`.
    function subCountOf(page as Number) as Number {
        return subCounts[screenOf(page)] as Number;
    }
}
