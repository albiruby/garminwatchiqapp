import Toybox.Lang;

module EconomySystem {
    const STAGE_MUL = [0.5, 1.0, 1.5];
    const MAX_INCOME_HOURS = 12.0;
    const KEY_PEARLS = 3;          // pearls per treasure key in the shop

    // Small passive coins over `hours`; capped so long absences do not flood the economy.
    // Running (ActivitySystem) is the main income.
    function income(list, hours) {
        if (hours > MAX_INCOME_HOURS) { hours = MAX_INCOME_HOURS; }
        if (hours <= 0) { return 0.0; }
        var sum = 0.0;
        for (var i = 0; i < list.size(); i++) {
            var f = list[i];
            var rate = FishDatabase.INCOME[FishDatabase.RARITY[f.sp]];
            sum += rate * STAGE_MUL[f.stage()] * (0.3 + 0.7 * f.hap / 100.0) * hours;
        }
        return sum;
    }

    function daily(streak, lv) {
        var s = streak > 7 ? 7 : streak;
        return 15 + 5 * s + 2 * lv;
    }

    function releaseValue(sp) {
        return FishDatabase.price(sp) * 4 / 10;
    }
}
