import Toybox.Lang;

// Theme = habitat content (water, substrate, plants, species pool). Independent of art style.
// Themes 4 (Frozen Ocean) and 5 (Deep Sea) unlock through the Ocean Expedition.
module ThemeDatabase {
    const TROPICAL = 0;
    const FRESHWATER = 1;
    const FANTASY = 2;
    const MIXED = 3;
    const FROZEN = 4;
    const DEEP = 5;
    const COUNT = 6;

    const NAME = ["Tropical Ocean", "Freshwater", "Fantasy", "Mixed Collection", "Frozen Ocean", "Deep Sea"];
    const DESC = ["Clownfish, tangs & coral", "Goldfish, koi & plants", "Glowfish & crystal jellies",
                  "Every habitat together", "Ice spires & cold-water fish", "Lanterns in the dark"];
    // Expedition region that unlocks the theme.
    const REGION = [0, 0, 0, 0, 2, 3];

    // 0 water top, 1 water bottom, 2 sand, 3 sand dark, 4 sand light, 5 pebble accent,
    // 6-8 plant colors, 9 UI accent
    const PAL = [
        [0x1565C0, 0x0A2A5E, 0xE2C27D, 0xB8955A, 0xF2DDA4, 0xF29E7A, 0xFF6F91, 0xFF9F43, 0xB667F1, 0x7FE7FF],
        [0x1F6E5C, 0x0A2621, 0x6E5E4E, 0x4A3F35, 0x8F7C68, 0xA58F6F, 0x48B04E, 0x2E7D32, 0x8BD45E, 0x9BF08A],
        [0x3A2380, 0x0C0626, 0x3B2F6B, 0x241B47, 0x5E4BA8, 0x8A6BE0, 0x3AF7E0, 0xFF4FD8, 0x9A7BFF, 0xFF8BEF],
        [0x1A4A8F, 0x081A3A, 0x5A4A8A, 0x382C5E, 0x8A7BC0, 0xC0A0E8, 0x2FD6C0, 0x1E9E8E, 0x9F6BFF, 0x7FE7FF],
        [0x4F94C4, 0x0E2F4F, 0xD6E4EE, 0xA2B8CC, 0xF4FAFF, 0x9FD8FF, 0x9FE8FF, 0x6FC9C9, 0xC9B8FF, 0xBFEFFF],
        [0x0E2048, 0x02040C, 0x24243A, 0x14141F, 0x3E3E5C, 0x5E4B8A, 0x3AF7E0, 0x4F7BFF, 0xFF6B9A, 0x7FE7FF]
    ];

    // Plant kinds per slot (PlantKit constants). Slots fill as the aquarium level grows.
    const KINDS = [
        [3, 4, 5, 3, 4, 5, 3],
        [0, 2, 1, 0, 2, 1, 0],
        [6, 0, 7, 6, 0, 7, 6],
        [0, 8, 2, 3, 1, 6, 4],
        [6, 8, 1, 6, 0, 8, 6],
        [5, 0, 7, 8, 6, 5, 0]
    ];
    const PLANT_X = [70, 318, 128, 255, 36, 190, 356];
    const PLANT_H = [120, 140, 72, 96, 82, 56, 92];

    // Synergy tags the theme's own plants already provide (see FishDatabase.SYN).
    const TAGS = [[1, 4], [2], [3], [2, 4], [6], [1, 3]];

    // [main, dark, light] for plant slot i.
    function plantColors(theme, i) {
        var p = PAL[theme];
        var c = p[6 + (i % 3)];
        if (KINDS[theme][i % 7] == 8) {
            c = PixelKit.shade(p[5], 0.3);
        }
        return [c, PixelKit.shade(c, 0.4), PixelKit.tint(c, 0.35)];
    }
}
