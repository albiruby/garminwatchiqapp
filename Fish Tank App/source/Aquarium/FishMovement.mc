import Toybox.Lang;
import Toybox.Math;

// Wander between random targets inside the round glass; chase sinking food when hungry.
// Personality shapes the wandering: Active roams fast, Calm drifts, Independent keeps its
// distance, Playful follows tank-mates, Territorial guards its own third of the tank.
module FishMovement {
    const CX = 195;
    const CY = 195;
    const R2 = 158 * 158;

    const P_PLAYFUL = 0;
    const P_INDEPENDENT = 1;
    const P_ACTIVE = 2;
    const P_CALM = 3;
    const P_TERRITORIAL = 4;

    function update(f, eng, dt) {
        var r = eng.renderer;
        if (f.petCd > 0) { f.petCd -= dt; }

        var seeking = false;
        if (f.sat < 95 && eng.foods.size() > 0) {
            var best = 1.0e9;
            for (var i = 0; i < eng.foods.size(); i++) {
                var p = eng.foods[i];
                if (p[3] >= 5.0) { continue; }
                var dx = p[0] - f.x;
                var dy = p[1] - f.y;
                var d2 = dx * dx + dy * dy;
                if (d2 < best) {
                    best = d2;
                    f.tx = p[0] - f.face * 8;
                    f.ty = p[1];
                    seeking = true;
                }
            }
        }

        var pers = f.personality();
        var jelly = FishDatabase.SHAPE[f.sp] == FishDatabase.SH_JELLY;
        var sp = FishDatabase.SPEED[f.sp] * r.speedMul;
        if (pers == P_ACTIVE) { sp *= 1.3; }
        else if (pers == P_CALM) { sp *= 0.75; }
        if (f.hp < 50) { sp *= 0.6; }
        if (eng.glow) { sp *= 1.2; }
        if (seeking) { sp *= jelly ? 2.5 : 1.9; }

        // Steering and drag were tuned per 0.1 s frame; scaling them by the real frame time
        // keeps the swimming identical at any frame rate.
        var fr = dt * 10.0;
        if (!seeking && f.pause > 0) {
            f.pause -= dt;
            var drag = 1.0 - 0.08 * fr;
            if (drag < 0.0) { drag = 0.0; }
            f.vx *= drag;
            f.vy *= drag;
        } else {
            var dx = f.tx - f.x;
            var dy = f.ty - f.y;
            var d = Math.sqrt(dx * dx + dy * dy);
            if (!seeking && d < 6) {
                pickTarget(f, eng);
                var maxPause = jelly ? 0.5 : 1.8;
                if (pers == P_CALM) { maxPause = 3.0; }
                else if (pers == P_ACTIVE) { maxPause = 0.6; }
                f.pause = Util.rf(0.2, maxPause);
            } else if (d > 0.01) {
                var k = (jelly ? 0.05 : 0.12) * fr;
                if (k > 1.0) { k = 1.0; }
                f.vx += (dx / d * sp - f.vx) * k;
                f.vy += (dy / d * sp * 0.7 - f.vy) * k;
            }
        }

        f.x += f.vx * dt;
        f.y += f.vy * dt;
        var b = r.bounds(f, eng);
        f.x = Util.clamp(f.x, b[0], b[2]);
        f.y = Util.clamp(f.y, b[1], b[3]);

        if (f.vx > 3) { f.face = 1; }
        else if (f.vx < -3) { f.face = -1; }
        var spd = f.vx.abs() + f.vy.abs();
        f.phase += dt * (1.0 + spd / 25.0);
    }

    function inGlass(x, y) {
        var dx = x - CX;
        var dy = y - CY;
        return dx * dx + dy * dy < R2;
    }

    function pickTarget(f, eng) {
        if (eng.renderer.layered && Util.rnd(5) == 0) {
            f.z = 1.0 - f.z;
        }
        var b = eng.renderer.bounds(f, eng);
        var pers = f.personality();
        var list = eng.fishList();

        // Playful: swim over to a random tank-mate
        if (pers == P_PLAYFUL && list.size() > 1 && Util.rnd(100) < 40) {
            var o = list[Util.rnd(list.size())];
            if (o != f) {
                f.tx = Util.clamp(o.x + Util.rf(-30.0, 30.0), b[0], b[2]);
                f.ty = Util.clamp(o.y + Util.rf(-20.0, 20.0), b[1], b[3]);
                return;
            }
        }

        var x0 = b[0];
        var x1 = b[2];
        // Territorial: stay in one third of the tank
        if (pers == P_TERRITORIAL) {
            var third = (x1 - x0) / 3.0;
            var zone = f.id % 3;
            x0 = x0 + third * zone;
            x1 = x0 + third;
        }

        var bestX = f.x;
        var bestY = f.y;
        var bestScore = -1.0;
        var tries = pers == P_INDEPENDENT ? 4 : 1;
        for (var i = 0; i < 8 && tries > 0; i++) {
            var tx = Util.rf(x0, x1);
            var ty = Util.rf(b[1], b[3]);
            if (!inGlass(tx, ty)) { continue; }
            tries -= 1;
            var score = 0.0;
            if (pers == P_INDEPENDENT) {
                // prefer the spot farthest from other fish
                score = 1.0e9;
                for (var j = 0; j < list.size(); j++) {
                    if (list[j] == f) { continue; }
                    var dx = list[j].x - tx;
                    var dy = list[j].y - ty;
                    var d2 = dx * dx + dy * dy;
                    if (d2 < score) { score = d2; }
                }
            }
            if (score > bestScore) {
                bestScore = score;
                bestX = tx;
                bestY = ty;
            }
        }
        f.tx = bestX;
        f.ty = bestY;
    }
}
