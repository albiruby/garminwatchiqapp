import Toybox.Lang;

// Explore pillar: five ocean regions unlocked by total running distance. Each region adds
// species, decorations and (Frozen, Deep) a new aquarium theme.
module ExpeditionSystem {
    const NAME = ["Coral Reef", "Tropical Lagoon", "Frozen Ocean", "Deep Sea", "Mystic Trench"];
    const KM = [0, 10, 30, 75, 150];
    // shown in a 184 px box on the map: keep each under ~22 characters
    const DESC = ["Where every tank begins", "Idols, discus, wrecks", "Ice fish + a new theme",
                  "Anglers + a new theme", "Home of the Leviathan"];
    const COLOR = [0xFF8BA8, 0x2FD6C0, 0x9FE8FF, 0x4F7BFF, 0x9A7BFF];

    function unlocked(eng) {
        var km = eng.stats["km"] / 1000;
        var n = 0;
        for (var i = 0; i < KM.size(); i++) { if (km >= KM[i]) { n = i; } }
        return n;
    }

    function check(eng) {
        var u = unlocked(eng);
        while (eng.expSeen < u) {
            eng.expSeen += 1;
            var r = eng.expSeen;
            RewardSystem.grant(eng, "ex" + r.toString(), 50 * r, r, 1, 40);
            RewardSystem.card(eng, "NEW REGION", NAME[r], [DESC[r], RewardSystem.summary(50 * r, r, 1)],
                RewardSystem.IC_GRID, SpriteData.ICON_MAP, COLOR[r]);
            Util.buzz(eng, 200);
        }
    }

    function themeUnlocked(eng, theme) {
        return ThemeDatabase.REGION[theme] <= unlocked(eng);
    }
}
