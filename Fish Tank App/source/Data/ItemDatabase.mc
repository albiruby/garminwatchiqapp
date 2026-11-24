import Toybox.Lang;

module ItemDatabase {
    const FOOD_NAME = ["Flakes", "Pellets", "Bloodworms"];
    const FOOD_PACK_PRICE = [0, 20, 30];
    const FOOD_PACK_QTY = [0, 5, 3];
    // Effect per food particle (each feed drops three).
    const FOOD_SAT = [10.0, 16.0, 25.0];
    const FOOD_HAPPY = [1.0, 3.0, 8.0];
    const FOOD_GROW = [0.5, 1.5, 3.0];
    const FOOD_COLOR = [0xFFC04D, 0xB5651D, 0xE0303F];

    // ---- Decorations ----------------------------------------------------------
    // Kind 0 = pixel grid (SpriteData.DECOR[arg]), kind 1 = PlantKit plant (arg = plant kind).
    const DECOR_COUNT = 16;
    const DECOR_NAME = ["Rock Arch", "Treasure Chest", "Diver Helmet", "Castle",
                        "Anemone", "Dense Plants", "Glow Crystals", "Glow Mushrooms",
                        "Kelp Bed", "Brain Coral", "Tube Coral", "Branch Coral",
                        "Ice Spires", "Shipwreck", "Giant Clam", "Sea Lantern"];
    const DECOR_PRICE = [40, 80, 120, 200, 60, 50, 90, 70, 50, 80, 70, 90, 120, 250, 150, 180];
    const DECOR_LV = [2, 2, 3, 5, 2, 2, 3, 3, 2, 3, 3, 4, 4, 5, 4, 6];
    const DECOR_REGION = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 3];
    // Synergy tag provided (FishDatabase.SYN)
    const DECOR_TAG = [5, 0, 0, 5, 1, 2, 3, 3, 2, 4, 4, 4, 6, 5, 0, 3];
    const DECOR_KIND = [0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0];
    const DECOR_ARG = [0, 1, 2, 3, 5, 2, 6, 7, 0, 8, 4, 3, 6, 4, 5, 6];
    // Plant decor colors [main, dark, light]
    const DECOR_COLS = [
        null, null, null, null,
        [0xFF6F91, 0xB03A5A, 0xFFB0C4],
        [0x48B04E, 0x2E6A32, 0x9BE07A],
        [0x3AF7E0, 0x1A9A8A, 0xC0FFF8],
        [0xFF4FD8, 0x9A2A88, 0xFFB0F0],
        [0x2FA85A, 0x1A6A38, 0x7FE09A],
        [0xFF8BA8, 0xB05A70, 0xFFC4D4],
        [0xFF9F43, 0xB06020, 0xFFD0A0],
        [0xB667F1, 0x7A3AB0, 0xDDB0FF],
        [0x9FE8FF, 0x5FA8C8, 0xF0FCFF],
        null, null, null
    ];

    // Substrate x positions for decoration slots; the slot count grows with aquarium level.
    const SLOT_X = [100, 290, 62, 328, 150, 240];
}
