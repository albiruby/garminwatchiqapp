import Toybox.Lang;
import Toybox.Math;
import Toybox.Attention;
import Toybox.System;
import Toybox.Time;

// Shared handles so screens and delegates can reach the one engine and tank view.
module Globals {
    var engine = null;
    var view = null;
    var nextUid = 1;
}

module Modes {
    const PLAY = 0;
    const STYLE = 1;
    const THEME = 2;
    const CARD = 3;     // reward / info cards queued in the engine
    const BUILD = 4;    // decoration builder on the live tank
}

// Local calendar days and Monday-based weeks, consistent for live time and run start times.
module TimeUtil {
    function tzOffset() {
        return System.getClockTime().timeZoneOffset;
    }

    function now() {
        return Time.now().value();
    }

    function dayOf(sec) {
        return (sec + tzOffset()) / 86400;
    }

    function today() {
        return dayOf(now());
    }

    // day 0 (1970-01-01) was a Thursday
    function weekOf(day) {
        return (day + 3) / 7;
    }

    function weekday(day) {
        return (day + 3) % 7;
    }
}

module Util {
    function rnd(n) {
        if (n <= 0) { return 0; }
        return Math.rand() % n;
    }

    function rf(a, b) {
        return a + (Math.rand() % 10000) / 10000.0 * (b - a);
    }

    function clamp(v, lo, hi) {
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }

    function str(n) {
        return n.toNumber().toString();
    }

    // 12500 -> "12,500"
    function thousands(n) {
        n = n.toNumber();
        if (n < 1000) { return n.toString(); }
        return (n / 1000).toString() + "," + (n % 1000).format("%03d");
    }

    function buzz(eng, ms) {
        if (eng != null && !eng.haptics) { return; }
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(60, ms)]);
        }
    }
}

// Deterministic generator so cached scenery and daily quests are the same every time.
class Rng {
    var s;

    function initialize(seed) {
        s = seed * 7919 + 13;
    }

    function next(n) {
        s = (s * 1103515245 + 12345) & 0x7FFFFFFF;
        if (n <= 0) { return 0; }
        return (s >> 7) % n;
    }
}
