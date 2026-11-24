import Toybox.Lang;

// Species table (36). Parallel arrays keep every field a single type for the compiler.
// Sprites are generated from SHAPE/TAIL/COLORS/MARKS by SpriteData, not stored as bitmaps.
module FishDatabase {
    const COUNT = 36;

    const SH_OVAL = 0;
    const SH_DISC = 1;
    const SH_LONG = 2;
    const SH_LION = 3;
    const SH_JELLY = 4;
    const SH_RAY = 5;
    const SH_SMALL = 6;
    const SH_ROUND = 7;
    const SH_EEL = 8;
    const SH_ANGLER = 9;

    const T_FAN = 0;
    const T_FORK = 1;
    const T_FLOW = 2;
    const T_NONE = 3;

    // Habitats: 0 Tropical, 1 Freshwater, 2 Fantasy, 3 Frozen, 4 Deep Sea
    const HABITAT = ["Tropical", "Freshwater", "Fantasy", "Frozen", "Deep Sea"];

    const NAME = ["Clownfish", "Blue Tang", "Butterflyfish", "Lionfish",
                  "Goldfish", "Guppy", "Betta", "Koi",
                  "Glowfish", "Spirit Ray", "Crystal Jelly", "Starfin",
                  "Yellow Tang", "Moorish Idol", "Pufferfish", "Mandarinfish", "Royal Gramma",
                  "Neon Tetra", "Angelfish", "Discus", "Arowana", "Pleco",
                  "Moonfin", "Ember Koi", "Prism Puffer", "Void Eel", "Aurora Betta",
                  "Ice Cod", "Snow Jelly", "Frost Eel", "Glacier Ray", "Aurora Char",
                  "Lanternfish", "Anglerfish", "Gulper Eel", "Abyss Leviathan"];
    const HAB = [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
                 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2,
                 3, 3, 3, 3, 3, 4, 4, 4, 4];
    const RARITY = [0, 0, 1, 2, 0, 0, 1, 2, 0, 2, 3, 4,
                    0, 1, 1, 3, 0, 0, 1, 2, 3, 0, 0, 1, 1, 2, 3,
                    0, 1, 2, 3, 1, 0, 2, 1, 4];
    const SHAPE = [0, 1, 1, 3, 0, 6, 0, 2, 0, 5, 4, 0,
                   1, 1, 7, 0, 6, 6, 1, 1, 2, 2, 0, 2, 7, 8, 0,
                   0, 4, 8, 5, 2, 6, 9, 8, 2];
    const TAIL = [0, 1, 0, 0, 2, 0, 2, 1, 1, 3, 3, 2,
                  1, 2, 0, 0, 0, 1, 2, 0, 0, 0, 1, 1, 0, 3, 2,
                  1, 3, 3, 3, 1, 1, 0, 3, 2];
    const SPEED = [34, 40, 30, 22, 26, 44, 24, 28, 38, 30, 12, 32,
                   38, 26, 18, 20, 40, 46, 24, 20, 30, 16, 34, 30, 18, 26, 24,
                   30, 12, 26, 28, 32, 40, 16, 24, 26];

    // [body, belly shade, top highlight, fins, outline]
    const COLORS = [
        [0xFF7A1A, 0xD9520B, 0xFFB066, 0xFF8C2E, 0x1A0E08],
        [0x2457E6, 0x1838A8, 0x5A86FF, 0xFFD21F, 0x0A0F2E],
        [0xFFE14D, 0xE0B020, 0xFFF3A8, 0xFFE14D, 0x2B1A05],
        [0xF4E4CC, 0xCFA884, 0xFFF6E6, 0xC23A2E, 0x2A0E0A],
        [0xFF9F1C, 0xE0700A, 0xFFD27A, 0xFFB347, 0x3A1C05],
        [0xB8CAD9, 0x8497AA, 0xE6F0F7, 0xFF4FA0, 0x18202E],
        [0x1F9DB5, 0x15707F, 0x6FD8E8, 0xE8283C, 0x1A0A10],
        [0xF6F4EE, 0xCFCCC2, 0xFFFFFF, 0xF6F4EE, 0x2A1410],
        [0x3AF7E0, 0x18B8A6, 0xC0FFF8, 0xFF4FD8, 0x0A2A40],
        [0x4B6BFF, 0x2E3FB0, 0x9EB4FF, 0xA0FFF5, 0x0B1030],
        [0xC9A8FF, 0x9C7BEA, 0xF2EAFF, 0x7FD4FF, 0x3A2A6A],
        [0xFFD84A, 0xE0A814, 0xFFF6C2, 0xFF6B3D, 0x3A2500],
        [0xFFD21F, 0xE0A800, 0xFFF08A, 0xFFE14D, 0x2B1A05],
        [0xF2F2EA, 0xC9C9C0, 0xFFFFFF, 0xFFE14D, 0x141414],
        [0xE8D27A, 0xC4A850, 0xFFF2B0, 0xD9B860, 0x2A2010],
        [0x2A6BFF, 0x1A44B0, 0x6FA0FF, 0xFF8C2E, 0x0A1030],
        [0xB44CFF, 0x8A2ED0, 0xD99BFF, 0xFFD21F, 0x22082E],
        [0x9FB4C8, 0x6E8296, 0xD8E4EE, 0xB8C8D8, 0x101820],
        [0xD8DCE0, 0xA8AEB5, 0xF4F6F8, 0xD8DCE0, 0x1A1C20],
        [0xE0442E, 0xB0301E, 0xFF7A5A, 0xE06A2E, 0x2A0A06],
        [0xE8B83A, 0xB88A1A, 0xFFE08A, 0xE8A23A, 0x2A1A04],
        [0x6E5A44, 0x4A3C2C, 0x8F7A60, 0x5A4A38, 0x1A140C],
        [0xC8D6FF, 0x96A8E0, 0xF0F4FF, 0x9FB4FF, 0x1A2040],
        [0xFF5A1F, 0xC83A10, 0xFFA060, 0xFFD21F, 0x2A0A04],
        [0xFF8BEF, 0xD05EC0, 0xFFD0F8, 0x7FE7FF, 0x2A0A28],
        [0x3A2A5A, 0x241A3A, 0x6A50A0, 0x9A7BFF, 0x0A0614],
        [0x7FE7FF, 0x4FB0C8, 0xD0FAFF, 0xFF8BEF, 0x0A2030],
        [0xB8D8EE, 0x88AECA, 0xE6F4FF, 0xA0C4E0, 0x1A2A3A],
        [0xF0F8FF, 0xC8DCF0, 0xFFFFFF, 0x9FE8FF, 0x3A4A6A],
        [0x9FE8FF, 0x6FB8D8, 0xE0FAFF, 0xFFFFFF, 0x1A3A4A],
        [0xDDEBFF, 0xA8BCD8, 0xFFFFFF, 0x9FE8FF, 0x1A2A40],
        [0x7FA8C0, 0x557A90, 0xA8D0E0, 0xFF8BA8, 0x102030],
        [0x3A4A6A, 0x24304A, 0x5A6A8A, 0x3A4A6A, 0x0A0E18],
        [0x4A3A3A, 0x2E2424, 0x6A5555, 0x4A3A3A, 0x0A0606],
        [0x2A2A3A, 0x1A1A26, 0x4A4A60, 0xFF6B9A, 0x06060C],
        [0x1A1A3A, 0x0E0E22, 0x3A3A6A, 0x7FE7FF, 0x02020A]
    ];

    // Body markings on the 18x12 sprite grid: [x0, y0, x1, y1, color]. Painted on body cells only.
    const MARKS = [
        [[10, 0, 10, 11, 0x1A1008], [11, 0, 12, 11, 0xFFFFFF], [6, 0, 6, 11, 0x1A1008], [7, 0, 8, 11, 0xFFFFFF], [9, 0, 9, 11, 0x1A1008]],
        [[7, 4, 12, 4, 0x0B1236], [6, 5, 8, 6, 0x0B1236], [9, 5, 13, 5, 0x0B1236]],
        [[9, 0, 10, 11, 0xFFFFFF], [12, 0, 12, 11, 0x2B1A0A], [7, 5, 7, 6, 0x2B1A0A]],
        [[6, 0, 6, 11, 0xA2302A], [8, 0, 8, 11, 0xA2302A], [10, 0, 10, 11, 0xA2302A], [12, 0, 12, 11, 0xA2302A]],
        [],
        [[9, 5, 10, 6, 0x2E8BFF]],
        [],
        [[7, 3, 9, 4, 0xE5481E], [11, 3, 13, 5, 0xE5481E], [5, 4, 5, 5, 0x1A1A1A]],
        [[6, 6, 14, 6, 0xFF4FD8]],
        [[8, 4, 8, 4, 0xA0FFF5], [11, 7, 11, 7, 0xA0FFF5], [12, 4, 12, 4, 0xA0FFF5]],
        [[7, 2, 7, 2, 0xFFFFFF], [11, 2, 12, 2, 0xFFFFFF]],
        [[8, 4, 8, 4, 0xFFFFFF], [11, 6, 11, 6, 0xFFFFFF]],
        [[6, 6, 6, 6, 0xFFFFFF]],
        [[7, 0, 8, 11, 0x1A1A1A], [11, 0, 12, 11, 0x1A1A1A], [9, 0, 10, 11, 0xFFE14D]],
        [[8, 4, 8, 4, 0x6B5A2A], [11, 6, 11, 6, 0x6B5A2A], [9, 7, 9, 7, 0x6B5A2A], [12, 3, 12, 3, 0x6B5A2A]],
        [[6, 4, 8, 4, 0xFF8C2E], [10, 6, 12, 6, 0xFF8C2E], [9, 3, 9, 3, 0xFF8C2E], [13, 5, 13, 5, 0xFF8C2E], [7, 7, 8, 7, 0xFF8C2E]],
        [[7, 0, 9, 11, 0xFFD21F]],
        [[8, 4, 14, 4, 0x2EE6FF], [8, 6, 12, 6, 0xFF2E4F], [8, 5, 14, 5, 0x2EB8FF]],
        [[8, 0, 8, 11, 0x2A2A2A], [11, 0, 11, 11, 0x2A2A2A]],
        [[7, 3, 13, 3, 0x2E9BFF], [7, 6, 13, 6, 0x2E9BFF], [8, 8, 12, 8, 0x2E9BFF]],
        [[6, 4, 6, 4, 0xFFF2B0], [9, 4, 9, 4, 0xFFF2B0], [12, 4, 12, 4, 0xFFF2B0], [8, 6, 8, 6, 0xFFF2B0], [11, 6, 11, 6, 0xFFF2B0]],
        [[6, 4, 6, 4, 0x2A2018], [9, 5, 9, 5, 0x2A2018], [12, 4, 12, 4, 0x2A2018], [14, 6, 14, 6, 0x2A2018]],
        [[12, 3, 12, 3, 0xFFFFFF]],
        [[8, 3, 10, 4, 0xFFD21F], [12, 5, 13, 6, 0xFFD21F]],
        [[7, 3, 8, 4, 0x7FE7FF], [10, 5, 11, 6, 0xFFE14D], [12, 3, 13, 4, 0x9BF08A]],
        [[5, 6, 5, 6, 0x9A7BFF], [8, 6, 8, 6, 0x9A7BFF], [11, 6, 11, 6, 0x9A7BFF], [14, 6, 14, 6, 0x9A7BFF]],
        [[8, 5, 12, 5, 0xFFFFFF]],
        [[6, 6, 14, 6, 0xFFFFFF]],
        [[8, 3, 8, 3, 0x9FE8FF], [11, 2, 11, 2, 0x9FE8FF]],
        [[6, 5, 6, 5, 0xFFFFFF], [10, 5, 10, 5, 0xFFFFFF], [14, 5, 14, 5, 0xFFFFFF]],
        [[8, 4, 8, 4, 0x9FE8FF], [12, 6, 12, 6, 0x9FE8FF]],
        [[6, 6, 14, 6, 0xFF8BA8], [7, 4, 7, 4, 0x9BF08A], [11, 4, 11, 4, 0x9BF08A]],
        [[9, 6, 9, 6, 0x7FE7FF], [11, 6, 11, 6, 0x7FE7FF], [13, 6, 13, 6, 0x7FE7FF]],
        [[14, 6, 15, 6, 0xFFFFFF]],
        [[15, 6, 15, 6, 0xFF6B9A]],
        [[5, 4, 7, 4, 0x7FE7FF], [9, 4, 11, 4, 0x7FE7FF], [13, 4, 14, 4, 0x7FE7FF]]
    ];

    // One accent color: Minimalist band, anglerfish lure.
    const ACCENT = [0xFFFFFF, 0x0B1236, 0x2B1A0A, 0xA2302A, 0xFFD27A, 0x2E8BFF,
                    0xE8283C, 0xE5481E, 0xFF4FD8, 0xA0FFF5, 0x7FD4FF, 0xFFFFFF,
                    0xFFFFFF, 0x1A1A1A, 0x6B5A2A, 0xFF8C2E, 0xFFD21F, 0x2EE6FF,
                    0x2A2A2A, 0x2E9BFF, 0xFFF2B0, 0x2A2018, 0x9FB4FF, 0xFFD21F,
                    0x7FE7FF, 0x9A7BFF, 0xFF8BEF, 0xFFFFFF, 0x9FE8FF, 0xFFFFFF,
                    0x9FE8FF, 0xFF8BA8, 0x7FE7FF, 0xFFE66B, 0xFF6B9A, 0x7FE7FF];

    // Personality: 0 Playful, 1 Independent, 2 Active, 3 Calm, 4 Territorial
    const PERS_NAME = ["Playful", "Independent", "Active", "Calm", "Territorial"];
    const PERS = [0, 2, 3, 4, 0, 2, 1, 3, 2, 3, 3, 0,
                  2, 1, 0, 1, 4, 2, 3, 3, 4, 3, 3, 2, 0, 1, 1,
                  3, 3, 1, 3, 2, 2, 4, 1, 4];
    // Favorite food: 0 flakes, 1 pellets, 2 bloodworms
    const FAV = [1, 0, 0, 2, 0, 0, 2, 1, 0, 1, 0, 2,
                 0, 1, 2, 2, 0, 0, 1, 2, 2, 1, 0, 2, 1, 2, 2,
                 1, 0, 2, 1, 1, 0, 2, 1, 2];
    // Habitat synergy tag (HabitatSystem): 0 none, 1 anemone, 2 dense plants, 3 glow,
    // 4 coral, 5 rock/cave, 6 ice, 7 space (tank not full)
    const SYN = [1, 4, 4, 7, 2, 2, 2, 5, 3, 3, 3, 3,
                 4, 4, 5, 4, 5, 2, 2, 2, 7, 5, 3, 3, 3, 5, 3,
                 6, 6, 6, 6, 6, 3, 5, 5, 3];
    const SYN_NAME = ["", "Anemone", "Dense plants", "Glowing decor", "Coral", "Rocks & caves", "Ice", "Open space"];
    // Expedition region needed before the species can appear (ExpeditionSystem).
    const REGION = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 2,
                    2, 2, 2, 2, 2, 3, 3, 3, 4];
    // Extra distance gate in km of total running; -1 = a single run of 21.1 km (half marathon).
    const KM_GATE = [0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 100, -1,
                     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                     0, 0, 0, 0, 0, 0, 0, 0, 0];

    const RARITY_NAME = ["Common", "Uncommon", "Rare", "Epic", "Legendary"];
    const RARITY_COLOR = [0xB0BEC5, 0x5EE36A, 0x4FA3FF, 0xC77DFF, 0xFFC93C];
    const PRICE = [20, 60, 150, 300, 600];
    const PEARL_PRICE = [0, 0, 0, 3, 8];
    const UNLOCK_LV = [1, 2, 4, 6, 8];
    const INCOME = [0.5, 1.0, 1.5, 2.5, 4.0];   // passive coins/hour, kept small: running is the main source

    function price(sp) {
        return PRICE[RARITY[sp]];
    }

    function pearlPrice(sp) {
        return PEARL_PRICE[RARITY[sp]];
    }

    function unlockLevel(sp) {
        return UNLOCK_LV[RARITY[sp]];
    }

    // Theme -> habitat; Mixed (3) = every unlocked habitat.
    const THEME_HAB = [0, 1, 2, -1, 3, 4];

    // Species sold or shown for a theme, cheapest rarity first.
    function pool(theme) {
        var hab = THEME_HAB[theme];
        var out = [];
        for (var r = 0; r < 5; r++) {
            for (var i = 0; i < COUNT; i++) {
                if (RARITY[i] == r && (hab < 0 || HAB[i] == hab)) {
                    out.add(i);
                }
            }
        }
        return out;
    }

    function starters(theme) {
        if (theme == 0) { return [0, 1]; }
        if (theme == 1) { return [4, 5]; }
        if (theme == 2) { return [8, 22]; }
        return [0, 4];
    }
}
