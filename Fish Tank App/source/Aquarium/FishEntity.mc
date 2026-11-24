import Toybox.Lang;

// One fish: persistent stats plus runtime swim state.
class FishEntity {
    // persistent
    var sp;
    var sat;      // satiety 0-100 (100 = full)
    var hap;      // happiness 0-100
    var hp;       // health 0-100, never below HealthSystem.HP_FLOOR
    var gr;       // growth 0-100 -> stage
    var fxp;      // fish XP -> fish level
    var variant;  // bits 0-1 color variant (SpriteData.VARIANT_NAME), bit 2 giant
    var evo;      // evolved form
    var rs;       // race skill (trained with training points)
    var id;       // persistent id (breeding, profile)

    // runtime
    var uid;
    var syn = false;     // habitat synergy satisfied (HabitatSystem.refresh)
    var x;
    var y;
    var vx = 0.0;
    var vy = 0.0;
    var tx;
    var ty;
    var face = 1;
    var phase;
    var pause = 0.0;
    var z;               // depth layer for Pseudo-3D: < 0.5 back, >= 0.5 front
    var petCd = 0.0;

    // a = [species, satiety, happiness, health, growth, fishXp, variant, evolved, raceSkill, id]
    function initialize(a) {
        sp = a[0];
        sat = a[1].toFloat();
        hap = a[2].toFloat();
        hp = a[3].toFloat();
        gr = a[4].toFloat();
        fxp = a.size() > 5 ? a[5].toFloat() : 0.0;
        variant = a.size() > 6 ? a[6] : 0;
        evo = a.size() > 7 ? a[7] : false;
        rs = a.size() > 8 ? a[8] : 0;
        id = a.size() > 9 ? a[9] : 0;
        uid = Globals.nextUid;
        Globals.nextUid += 1;
        x = Util.rf(110.0, 280.0);
        y = Util.rf(120.0, 240.0);
        tx = x;
        ty = y;
        phase = Util.rf(0.0, 6.0);
        z = Util.rnd(2) == 0 ? 0.25 : 0.75;
        face = Util.rnd(2) == 0 ? 1 : -1;
    }

    function stage() {
        if (gr < 30) { return 0; }
        if (gr < 70) { return 1; }
        return 2;
    }

    function stageName() {
        var s = stage();
        if (s == 0) { return "Baby"; }
        if (s == 1) { return "Young"; }
        return "Adult";
    }

    function level() {
        var l = 1 + (fxp / 25).toNumber();
        return l > 10 ? 10 : l;
    }

    function name() {
        return FishDatabase.NAME[sp];
    }

    function colorVariant() {
        return variant & 3;
    }

    // Event edition id (0 = none), see EventSystem.edition.
    function edition() {
        return (variant >> 3) & 15;
    }

    function giant() {
        return (variant & 4) != 0;
    }

    function personality() {
        return FishDatabase.PERS[sp];
    }

    function toArr() {
        return [sp, sat, hap, hp, gr, fxp, variant, evo, rs, id];
    }
}
