import Toybox.Lang;
import Toybox.Math;

// Food particles: [x, y, type, restSeconds, wobblePhase]
module FeedingSystem {
    const REST_LIMIT = 5.0;
    const MAX_FOOD = 12;

    function drop(eng, x, y) {
        var type = eng.selFood;
        if (type > 0 && eng.food[type] <= 0) {
            eng.toast("Out of " + ItemDatabase.FOOD_NAME[type] + ", using flakes", 0xFFC04D);
            type = 0;
            eng.selFood = 0;
        }
        if (eng.foods.size() >= MAX_FOOD) { return; }
        if (type > 0) { eng.food[type] -= 1; }
        if (y < 92) { y = 92; }
        for (var i = 0; i < 3; i++) {
            eng.foods.add([x + (i - 1) * 9 + Util.rf(-3.0, 3.0), y + Util.rf(-4.0, 4.0), type, 0.0, Util.rf(0.0, 6.28)]);
        }
        QuestSystem.event(eng, QuestSystem.Q_FEED, 1);
        eng.tutorialEvent(0);
    }

    function update(eng, dt) {
        var floor = eng.renderer.restY();
        var list = eng.fishList();
        var keep = [];
        for (var i = 0; i < eng.foods.size(); i++) {
            var p = eng.foods[i];
            if (p[1] < floor) {
                p[1] += 22 * dt;
                p[4] += dt * 4;
                p[0] += Math.sin(p[4]) * 0.4;
            } else {
                p[1] = floor;
                p[3] += dt;
            }
            var eaten = false;
            if (p[3] < REST_LIMIT) {
                for (var j = 0; j < list.size(); j++) {
                    var f = list[j];
                    if (f.sat >= 95) { continue; }
                    var dx = f.x + f.face * 10 - p[0];
                    var dy = f.y - p[1];
                    if (dx * dx + dy * dy < 196) {
                        eat(eng, f, p[2]);
                        eaten = true;
                        break;
                    }
                }
            }
            if (!eaten) {
                if (p[3] >= REST_LIMIT) {
                    eng.addDirt(1.2);   // uneaten food fouls the water
                } else {
                    keep.add(p);
                }
            }
        }
        eng.foods = keep;
    }

    function eat(eng, f, type) {
        var before = f.sat;
        var stageBefore = f.stage();
        var fav = FishDatabase.FAV[f.sp] == type;
        var happy = ItemDatabase.FOOD_HAPPY[type] * (fav ? 2.0 : 1.0);
        f.sat = Util.clamp(f.sat + ItemDatabase.FOOD_SAT[type], 0.0, 100.0);
        f.hap = Util.clamp(f.hap + happy, 0.0, 100.0);
        f.gr = Util.clamp(f.gr + ItemDatabase.FOOD_GROW[type], 0.0, 100.0);
        for (var k = 0; k < 3; k++) {
            eng.particle(f.x + f.face * 12, f.y, Util.rf(-20.0, 20.0), Util.rf(-25.0, 5.0), 0.5, ItemDatabase.FOOD_COLOR[type], 0);
        }
        if (fav) { eng.particle(f.x, f.y - 18, 0.0, -25.0, 0.9, 0xFF5A7A, 1); }
        if (eng.preview == null && before < 70) {
            f.fxp += 1.0;
            eng.addXp(1);
        }
        if (f.stage() > stageBefore) {
            eng.toast(f.name() + " grew up!", 0x9BF08A);
            Util.buzz(eng, 120);
        }
    }
}
