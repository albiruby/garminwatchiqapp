import Toybox.Lang;

// Looks are full visual treatments, not colour swaps: each one sets the neutral
// palette, the numeral style, the divider style, the needle shape, the track scale and
// how the accent behaves. The accent colour itself can follow the look or be chosen.
// apply() is called whenever settings load; everything else reads the current tokens.
module ThemeManager {

    const BLACK = 0x000000;
    const WARN = 0xFF5757;       // low battery only (6.75:1 on black)

    const LOOK_CARBON = 0;
    const LOOK_REFLECTIVE = 1;
    const LOOK_FIELD = 2;
    const LOOK_SIGNAL = 3;

    const NUM_SOLID = 0;
    const NUM_OUTLINE = 1;
    const NUM_LIGHT = 2;

    const DIV_HAIRLINE = 0;
    const DIV_DASHED = 1;
    const DIV_NONE = 2;
    const DIV_BOLD = 3;

    const NEEDLE_LINE = 0;
    const NEEDLE_CHEVRON = 1;
    const NEEDLE_DOT = 2;
    const NEEDLE_BLOCK = 3;

    const SCALE_TICKS = 0;
    const SCALE_DOTS = 1;
    const SCALE_HEAVY = 2;

    // text, muted, faint, track, divider, numerals, divider style, needle, scale,
    // default accent, signal (accent only once the goal is met)
    // Text and muted colours are all >= 6:1 on black.
    const LOOKS = [
        // CARBON: instrument panel, solid numerals, hairlines
        [0xF4F5F6, 0x858A93, 0x4A4E55, 0x24272D, 0x2C2F35, 0, 0, 0, 0, 0, false],
        // REFLECTIVE: running-gear reflectives, outline numerals, dashed rules, chevron
        [0xFFFFFF, 0x9DA3AD, 0x50555D, 0x1E2126, 0x3A3F47, 1, 1, 1, 1, 4, false],
        // FIELD: warm and quiet, light numerals, spacing instead of rules, round cursor
        [0xEDE6D6, 0xA39C8E, 0x5A544A, 0x2A2620, 0x2A2620, 2, 2, 2, 1, 6, false],
        // SIGNAL: monochrome until the goal is met, bold rules, block cursor
        [0xFFFFFF, 0x8E8E93, 0x48484A, 0x2C2C2E, 0x3A3A3C, 0, 3, 3, 2, 5, true]
    ];

    // [accent, dim accent for the START track]. Accents are >= 5.9:1 on black.
    const ACCENTS = [
        [0xB7F34A, 0x5E7D26],   // Electric Lime
        [0x47D7F2, 0x246B79],   // Arctic Cyan
        [0xFF9D42, 0x80501F],   // Burnt Orange
        [0xF4F5F6, 0x7A7B7C],   // Pure White
        [0xE4FF1A, 0x72800D],   // Volt
        [0xFF3B30, 0x801E18],   // Signal Red
        [0xFF7C5C, 0x803E2E],   // Terracotta
        [0xA99BFF, 0x554E80]    // Ice Violet
    ];

    var look as Number = 0;
    var TEXT as Number = 0xF4F5F6;
    var MUTED as Number = 0x858A93;
    var FAINT as Number = 0x4A4E55;
    var TRACK as Number = 0x24272D;
    var DIVIDER as Number = 0x2C2F35;
    var numerals as Number = 0;
    var dividerStyle as Number = 0;
    var needleStyle as Number = 0;
    var scaleStyle as Number = 0;
    var signal as Boolean = false;
    var accentIndex as Number = 0;

    // accentChoice: 0 = the look's own accent, 1..8 = ACCENTS[0..7]
    function apply(lookId as Number, accentChoice as Number) as Void {
        look = (lookId >= 0 && lookId < LOOKS.size()) ? lookId : 0;
        var l = LOOKS[look] as Array;
        TEXT = l[0] as Number;
        MUTED = l[1] as Number;
        FAINT = l[2] as Number;
        TRACK = l[3] as Number;
        DIVIDER = l[4] as Number;
        numerals = l[5] as Number;
        dividerStyle = l[6] as Number;
        needleStyle = l[7] as Number;
        scaleStyle = l[8] as Number;
        signal = l[10] as Boolean;
        accentIndex = (accentChoice >= 1 && accentChoice <= ACCENTS.size()) ? accentChoice - 1 : l[9] as Number;
    }

    function accent() as Number {
        return (ACCENTS[accentIndex] as Array<Number>)[0];
    }

    function accentDim() as Number {
        return (ACCENTS[accentIndex] as Array<Number>)[1];
    }

    // Text colour for a percentage or goal word. Signal keeps it neutral until the goal
    // is met. Always the full accent, never the dim tone (that one is below 4.5:1).
    function textAccent(state as Number) as Number {
        if (signal && state < ActivityGoalEngine.STATE_COMPLETED) {
            return TEXT;
        }
        return accent();
    }

    // Track and bar fill for a goal state: START stays calm, later states use the accent.
    function progressColor(state as Number) as Number {
        if (signal) {
            if (state >= ActivityGoalEngine.STATE_COMPLETED) {
                return accent();
            }
            return state == ActivityGoalEngine.STATE_START ? MUTED : TEXT;
        }
        return state == ActivityGoalEngine.STATE_START ? accentDim() : accent();
    }

    // Overshoot lap: the look's text colour, or lime when the accent is white itself.
    function lapColor() as Number {
        if (signal) {
            return accent();
        }
        return accentIndex == 3 ? 0xB7F34A : TEXT;
    }
}
