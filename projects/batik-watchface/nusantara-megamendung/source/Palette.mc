import Toybox.Lang;

// Locked colorways. Index order is shared by every renderer.
module Palette {
    enum {
        BG,
        SKELETON,   // unlit petal outline
        DARK,       // lit petal edge, centre seed
        MID,        // lit petal body
        LIGHT,      // lit petal highlight, hands
        ACCENT,     // medallion ring, completion ring
        TEXT,
        WARN        // low battery
    }

    // Palette matched to the panel: full colour for AMOLED, the 64-colour MIP gamut
    // (channels 00/55/AA/FF) so gold stays gold, and pure black/white for mono Instinct.
    function forDisplay(colorway as Number, mip as Boolean, mono as Boolean) as Array<Number> {
        if (mono) {
            return [0x000000, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF];
        }
        if (!mip) {
            return get(colorway);
        }
        switch (colorway) {
            case 1: // Bronze
                return [0x000000, 0x550000, 0x550000, 0xAA5500, 0xFFAA55, 0xFF5500, 0xFFFFAA, 0xFF0000];
            case 2: // Cirebon Red
                return [0x000000, 0x550000, 0xAA0055, 0xFF0055, 0xFFAAAA, 0xFF55AA, 0xFFFFFF, 0xFFAA00];
            case 3: // Sogan Brown
                return [0x000000, 0x550000, 0x550000, 0xAA5500, 0xFFAA55, 0xAA5500, 0xFFFFAA, 0xFF0000];
            default: // Cirebon Blue
                return [0x000000, 0x000055, 0x0000AA, 0x0055FF, 0xAAFFFF, 0x55AAFF, 0xFFFFFF, 0xFF5500];
        }
    }

    function get(colorway as Number) as Array<Number> {
        switch (colorway) {
            case 1: // Bronze
                return [0x050302, 0x6A4628, 0x5C3317, 0x9C5B2E, 0xD99A62, 0xC07A45, 0xF0D9C4, 0xE04A2F];
            case 2: // Cirebon Red
                return [0x12040A, 0x7A2E46, 0x7A1E3A, 0xC2405E, 0xFFD6E0, 0xE88AA6, 0xFFEFF3, 0xFFAA00];
            case 3: // Sogan Brown
                return [0x0A0603, 0x6A4A2C, 0x4E2E14, 0x8A5A2B, 0xE3C38E, 0xB9844A, 0xF2E2C4, 0xD8432E];
            default: // Cirebon Blue
                return [0x03061A, 0x34509A, 0x1E3C8C, 0x3A6FD0, 0xD6E8FF, 0x7FB0F0, 0xEAF2FF, 0xFF7A3A];
        }
    }
}
