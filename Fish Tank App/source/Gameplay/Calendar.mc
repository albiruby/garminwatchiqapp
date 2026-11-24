import Toybox.Lang;
import Toybox.Math;

// Pure date math on local day numbers (days since 1970-01-01, see TimeUtil.dayOf).
// Everything is computed, so events keep working for any year without app updates.
module CalendarUtil {
    const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const SYNODIC = 29.530588853;    // mean lunar month in days

    // Gregorian date -> day number (H. Hinnant's civil algorithm).
    function daysFromCivil(y, m, d) {
        if (m <= 2) { y -= 1; }
        var era = y / 400;
        var yoe = y - era * 400;
        var mp = (m + 9) % 12;
        var doy = (153 * mp + 2) / 5 + d - 1;
        var doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
        return era * 146097 + doe - 719468;
    }

    // Day number -> [year, month, day].
    function civilFromDays(z) {
        z += 719468;
        var era = z / 146097;
        var doe = z - era * 146097;
        var yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
        var y = yoe + era * 400;
        var doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        var mp = (5 * doy + 2) / 153;
        var d = doy - (153 * mp + 2) / 5 + 1;
        var m = mp < 10 ? mp + 3 : mp - 9;
        return [m <= 2 ? y + 1 : y, m, d];
    }

    function year(day) {
        return civilFromDays(day)[0];
    }

    // First weekday `wd` (0 = Monday) of a month.
    function firstWeekday(y, m, wd) {
        var d = daysFromCivil(y, m, 1);
        while (TimeUtil.weekday(d) != wd) { d += 1; }
        return d;
    }

    // Tabular Islamic calendar -> day number. Usually within 1-2 days of the official
    // (sighting-based) date, which is close enough for a week-long game event.
    function islamicDays(hy, hm, hd) {
        var jdn = (11 * hy + 3) / 30 + 354 * hy + 30 * hm - (hm - 1) / 2 + hd + 1948440 - 385;
        return jdn - 2440588;
    }

    // Hijri years whose month `hm` could start in Gregorian year gy.
    function hijriCandidates(gy) {
        var y0 = (gy - 622) * 33 / 32;
        return [y0 - 1, y0, y0 + 1];
    }

    // Lunar New Year: the second new moon after the December solstice, China time.
    // Uses the mean new moon, so it can be a day off in rare years.
    function lunarNewYear(gy) {
        var solstice = daysFromCivil(gy - 1, 12, 21) + 0.63;
        var ref = daysFromCivil(2000, 1, 6) + 0.7597;     // new moon 2000-01-06 18:14 UTC
        var k = Math.ceil((solstice - ref) / SYNODIC);
        var nm2 = ref + (k + 1) * SYNODIC;
        return Math.floor(nm2 + 8.0 / 24.0).toNumber();
    }

    // "14 Aug"
    function fmt(day) {
        var c = civilFromDays(day);
        return c[2].toString() + " " + MONTHS[c[1] - 1];
    }

    function fmtYear(day) {
        var c = civilFromDays(day);
        return c[2].toString() + " " + MONTHS[c[1] - 1] + " " + c[0].toString();
    }
}

// Gameplay modifiers in force today, set by EventSystem.refresh from the weekly current and
// any active events. Defaults mean "no modifier", so systems work unchanged without events.
module Mods {
    const WARM = 0;        // fish grow faster
    const PLANKTON = 1;    // cheaper food
    const CLEAR = 2;       // tank dirties slower
    const TREASURE = 3;    // more mystery finds
    const FAST = 4;        // racing pays double
    const DEEP = 5;        // deep-sea fish in eggs
    const FULLMOON = 6;    // rare variants twice as likely
    const BREED = 7;       // breeding cheaper and quicker

    var growth = 1.0;
    var dirt = 1.0;
    var foodPrice = 1.0;
    var mystery = 8;       // % chance per run
    var raceMul = 1;
    var deep = false;
    var variantMul = 1;
    var breedFast = false;
    var runMul = 1.0;
    var spotlight = "";    // mini-game with double coins this week

    function reset() {
        growth = 1.0;
        dirt = 1.0;
        foodPrice = 1.0;
        mystery = 8;
        raceMul = 1;
        deep = false;
        variantMul = 1;
        breedFast = false;
        runMul = 1.0;
        spotlight = "";
    }

    function apply(m) {
        if (m == WARM) { growth = 1.5; }
        else if (m == PLANKTON) { foodPrice = 0.5; }
        else if (m == CLEAR) { dirt = 0.5; }
        else if (m == TREASURE) { mystery = 20; }
        else if (m == FAST) { raceMul = 2; }
        else if (m == DEEP) { deep = true; }
        else if (m == FULLMOON) { variantMul = 2; }
        else if (m == BREED) { breedFast = true; }
    }
}
