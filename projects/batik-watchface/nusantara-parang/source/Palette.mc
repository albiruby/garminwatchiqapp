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
            case 2: // Silver Indigo
                return [0x000000, 0x000055, 0x0000AA, 0x5555AA, 0xFFFFFF, 0xAAAAFF, 0xFFFFFF, 0xFF5500];
            case 3: // Sogan Brown
                return [0x000000, 0x550000, 0x550000, 0xAA5500, 0xFFAA55, 0xAA5500, 0xFFFFAA, 0xFF0000];
            default: // Keraton Gold
                return [0x000000, 0x555500, 0x550000, 0xAA5500, 0xFFAA55, 0xFFAA00, 0xFFFFAA, 0xFF0000];
        }
    }

    function get(colorway as Number) as Array<Number> {
        switch (colorway) {
            case 1: // Bronze
                return [0x050302, 0x6A4628, 0x5C3317, 0x9C5B2E, 0xD99A62, 0xC07A45, 0xF0D9C4, 0xE04A2F];
            case 2: // Silver Indigo
                return [0x02040A, 0x3A5288, 0x22335E, 0x5C6F9E, 0xD6DDEA, 0xA9B6CF, 0xEEF2F8, 0xE0603A];
            case 3: // Sogan Brown
                return [0x0A0603, 0x6A4A2C, 0x4E2E14, 0x8A5A2B, 0xE3C38E, 0xB9844A, 0xF2E2C4, 0xD8432E];
            default: // Keraton Gold
                return [0x000000, 0x6E5426, 0x6B4A12, 0xB8862B, 0xF2D27A, 0xD9AE4F, 0xF6E7BE, 0xD0452F];
        }
    }
}
