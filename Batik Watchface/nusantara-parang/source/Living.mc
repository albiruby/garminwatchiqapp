import Toybox.Lang;

// Pure helpers for the Living Pattern: progress mapping and coordinate packing.
// Kept free of device APIs so they can be unit tested.
module Living {

    // Number of motif units to light for a given progress value.
    function litCount(value as Number, goal as Number, total as Number) as Number {
        if (total <= 0 || goal <= 0 || value <= 0) {
            return 0;
        }
        if (value >= goal) {
            return total;
        }
        return (value.toLong() * total / goal).toNumber();
    }

    // [bloom, awake] unit counts. Awakening runs at double speed, so at 50% the whole
    // motif is gilded and half of it is in bloom; at 100% everything blooms.
    function stages(steps as Number, goal as Number, total as Number) as [Number, Number] {
        var awakeSteps = steps > 0x3FFFFFFF ? steps : steps * 2;
        return [litCount(steps, goal, total), litCount(awakeSteps, goal, total)];
    }

    // Two signed 16-bit coordinates in one Number (saves an Array per unit).
    function pack(x as Number, y as Number) as Number {
        return ((x & 0xFFFF) << 16) | (y & 0xFFFF);
    }

    function unpackX(p as Number) as Number {
        var x = (p >> 16) & 0xFFFF;
        return x >= 0x8000 ? x - 0x10000 : x;
    }

    function unpackY(p as Number) as Number {
        var y = p & 0xFFFF;
        return y >= 0x8000 ? y - 0x10000 : y;
    }
}
