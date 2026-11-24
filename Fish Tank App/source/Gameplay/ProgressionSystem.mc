import Toybox.Lang;

// Player level (XP). Fish capacity and plants now come from the aquarium level
// (HabitatSystem); player level unlocks fish rarities, decor and tank upgrades.
module ProgressionSystem {
    const MAX_LV = 10;
    const UNLOCKS = ["", "Uncommon fish, decor shop", "More decorations", "Rare fish", "Bigger decor",
                     "Epic fish", "Tank LV 4 upgrade", "Legendary fish", "Tank LV 5 upgrade", "Master aquarist"];
    const TITLES = ["Puddle Keeper", "Pond Pal", "Reef Rookie", "Tank Tender", "Current Rider",
                    "Wave Runner", "Deep Diver", "Tide Master", "Ocean Sage", "Leviathan Lord"];

    function need(lv) {
        return 60 + 40 * (lv - 1);
    }

    function unlockText(lv) {
        return UNLOCKS[Util.clamp(lv, 1, MAX_LV) - 1];
    }

    function title(lv) {
        return TITLES[Util.clamp(lv, 1, MAX_LV) - 1];
    }

    // Returns [level, xp, levelsGained].
    function apply(lv, xp, add) {
        xp += add;
        var ups = 0;
        while (lv < MAX_LV && xp >= need(lv)) {
            xp -= need(lv);
            lv += 1;
            ups += 1;
        }
        if (lv >= MAX_LV) { xp = 0; }
        return [lv, xp, ups];
    }
}
