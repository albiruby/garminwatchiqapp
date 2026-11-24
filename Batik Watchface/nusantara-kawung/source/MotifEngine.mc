import Toybox.Graphics;
import Toybox.Lang;

// Common shape of every batik motif engine. The view only talks to this class, so a motif
// is swapped by creating a different engine; only the selected motif lives in memory.
class MotifEngine {

    var units as Array<Number> = [] as Array<Number>; // packed x/y, in lighting order
    var cell as Number = 0;
    // Monochrome panels (Instinct) use line work instead of solid fills.
    var mono as Boolean = false;

    function initialize() {
    }

    function build(w as Number, h as Number, cellSize as Number, round as Boolean) as Void {
    }

    // bloom: units fully in bloom; awake: units at least awakening (awake >= bloom).
    function draw(dc as Dc, pal as Array<Number>, colorway as Number, bloom as Number, awake as Number, complete as Boolean) as Void {
    }

    // One motif unit as outline only, for the always-on face (cheap in lit pixels).
    function ornament(dc as Dc, x as Number, y as Number, size as Number) as Void {
    }
}

module Motifs {
    enum {
        KAWUNG,
        PARANG,
        MEGA_MENDUNG
    }

    function create(motif as Number) as MotifEngine {
        switch (motif) {
            case PARANG:
                return new ParangEngine();
            case MEGA_MENDUNG:
                return new MegaMendungEngine();
            default:
                return new KawungEngine();
        }
    }
}
