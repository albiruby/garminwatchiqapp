import Toybox.Graphics;
import Toybox.Lang;

// Centralized semantic color keys + palette. No color literals anywhere else.
// Semantic keys are what engines/models reference; Colors.arg() maps to ARGB.
// Never rely on color alone to convey meaning (paired with text labels).

module ColorKey {
    const MUTED = 0;
    const PRIMARY = 1;      // white text
    const SECONDARY = 2;    // gray text
    const READY = 3;        // green
    const MODERATE = 4;     // amber
    const WARNING = 5;      // orange
    const DANGER = 6;       // red
    const RECOVERY = 7;     // cyan
    const INFO = 8;         // blue
    const TRACK = 9;        // faint bar/ring track
    const DIVIDER = 10;     // faint divider line
    const BACKGROUND = 11;  // black
}

class Colors {
    // ARGB palette (AMOLED-friendly, restrained athletic tones).
    static const C_BACKGROUND = 0x000000;
    static const C_PRIMARY    = 0xFFFFFF;
    static const C_SECONDARY  = 0x9AA0A6;
    static const C_MUTED      = 0x5F6368;
    static const C_READY      = 0x30D158;  // green
    static const C_MODERATE   = 0xFFD60A;  // amber
    static const C_WARNING    = 0xFF9F0A;  // orange
    static const C_DANGER     = 0xFF453A;  // red
    static const C_RECOVERY   = 0x32D0D0;  // cyan
    static const C_INFO       = 0x0A84FF;  // blue
    static const C_TRACK      = 0x2A2C2E;  // faint track
    static const C_DIVIDER    = 0x3A3C3E;  // faint divider

    // Map a semantic ColorKey to an ARGB value.
    static function arg(key as Number) as Number {
        if (key == ColorKey.PRIMARY) { return C_PRIMARY; }
        if (key == ColorKey.SECONDARY) { return C_SECONDARY; }
        if (key == ColorKey.READY) { return C_READY; }
        if (key == ColorKey.MODERATE) { return C_MODERATE; }
        if (key == ColorKey.WARNING) { return C_WARNING; }
        if (key == ColorKey.DANGER) { return C_DANGER; }
        if (key == ColorKey.RECOVERY) { return C_RECOVERY; }
        if (key == ColorKey.INFO) { return C_INFO; }
        if (key == ColorKey.TRACK) { return C_TRACK; }
        if (key == ColorKey.DIVIDER) { return C_DIVIDER; }
        if (key == ColorKey.BACKGROUND) { return C_BACKGROUND; }
        return C_MUTED;
    }
}
