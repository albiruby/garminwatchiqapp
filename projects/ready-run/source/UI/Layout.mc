import Toybox.Lang;

// Layout — all Y positions derive from SafeZone. Views never hardcode y.
// Designed for a 390px round display (FR165) with a generous, collision-free
// vertical rhythm. Screens pick the zones they need; paginated pages use
// evenRows() to space a group of rows within a band. Pagination is a reserved
// bottom strip that normal content never enters.

class Layout {
    var sz as SafeZone;

    function initialize(safe as SafeZone) {
        sz = safe;
    }

    // Header title (e.g. "READY RUN", "BODY READINESS").
    function getHeaderY() as Number {
        return sz.cy - 135;
    }

    // Primary score (big number) + readiness-ring center. Hero band.
    function getScoreY() as Number {
        return sz.cy - 52;
    }

    // Status word under the score.
    function getStatusY() as Number {
        return sz.cy + 20;
    }

    // Divider between the status block and the supporting rows.
    function getDividerY() as Number {
        return sz.cy + 46;
    }

    // First supporting row (Level 2) below the divider.
    function getSecondaryY() as Number {
        return sz.cy + 70;
    }

    // Second supporting row.
    function getTertiaryY() as Number {
        return sz.cy + 104;
    }

    // Generic first content row (used by paginated metric pages).
    function getContentY() as Number {
        return getSecondaryY();
    }

    // Row y for the i-th content row given start y, row height + gap.
    function getRowY(startY as Number, index as Number, rowH as Number, gap as Number) as Number {
        return startY + index * (rowH + gap);
    }

    // Evenly space `count` row-centers within the band [top, bot]. Returns an
    // Array of Y positions. Used by paginated pages (BODY B, STATUS B, FORM B).
    function evenRows(count as Number, top as Number, bot as Number) as Array {
        var out = [] as Array<Number>;
        if (count <= 0) { return out; }
        if (count == 1) {
            out.add((top + bot) / 2);
            return out;
        }
        var step = (bot - top) / (count - 1);
        var i;
        for (i = 0; i < count; i++) {
            out.add(top + (step * i).toNumber());
        }
        return out;
    }

    // Spacing tokens (gaps between elements).
    function spTight() as Number { return 6; }
    function spSm() as Number { return 12; }
    function spMd() as Number { return 20; }

    // Pagination dots baseline (reserved strip, same on every screen).
    function getPaginationY() as Number {
        return sz.paginationTop + 6;
    }

    // A centered divider width that respects the safe circle at its y.
    function dividerHalfWidth(y as Number) as Number {
        var hw = sz.maxHalfWidthAt(y, 2);
        var w = hw - 12;
        if (w < 20) { w = 20; }
        return w;
    }
}