import Toybox.Lang;

// Time-based decay applied in one step for any elapsed time (offline or live).
// Never punishing: fish cannot die, health bottoms out at HP_FLOOR.
module HealthSystem {
    const SAT_DECAY = 6.0;      // satiety lost per hour
    const HAPPY_DRIFT = 10.0;   // happiness moves toward its target this fast per hour
    const HP_FLOOR = 35.0;
    const MAX_HOURS = 168.0;

    // decorBonus: from placed decorations; synergy: fish's habitat match.
    function targetHappy(sat, clean, decorBonus, synergy) {
        var b = decorBonus > 20 ? 20 : decorBonus;
        if (synergy) { b += HabitatSystem.SYN_BONUS; }
        return Util.clamp(sat * 0.45 + clean * 0.4 + 5 + b, 0.0, 100.0);
    }

    // Updates every fish in place and returns the new cleanliness.
    function advance(list, clean, decorBonus, hours) {
        if (hours <= 0) { return clean; }
        if (hours > MAX_HOURS) { hours = MAX_HOURS; }
        var n = list.size();
        var dirtRate = 2.5;
        if (n > 2) { dirtRate += (n - 2) * 0.6; }
        clean = Util.clamp(clean - dirtRate * Mods.dirt * hours, 0.0, 100.0);

        for (var i = 0; i < n; i++) {
            var f = list[i];
            f.sat = Util.clamp(f.sat - SAT_DECAY * hours, 0.0, 100.0);

            var target = targetHappy(f.sat, clean, decorBonus, f.syn);
            var dh = target - f.hap;
            var step = HAPPY_DRIFT * hours;
            if (dh.abs() <= step) { f.hap = target; }
            else if (dh > 0) { f.hap += step; }
            else { f.hap -= step; }

            if (f.sat < 20 || clean < 25) {
                f.hp = Util.clamp(f.hp - 3.0 * hours, HP_FLOOR, 100.0);
            } else {
                f.hp = Util.clamp(f.hp + 5.0 * hours, HP_FLOOR, 100.0);
            }

            if (f.sat > 40 && f.hp > 60) {
                f.gr = Util.clamp(f.gr + 1.5 * Mods.growth * hours, 0.0, 100.0);
            }
        }
        return clean;
    }
}
