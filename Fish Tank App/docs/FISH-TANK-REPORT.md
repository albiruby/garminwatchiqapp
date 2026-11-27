# FISH TANK: Product and Feature Report

**Document:** `docs/FISH-TANK-REPORT.md`
**Snapshot:** 27 November 2026
**Code basis:** `d05efbb` (Bubble Pop HUD fix), with `5f66ce7` (63-device manifest and UI fit fixes) and `fac9778` (multi-device performance)
**Product version:** 1.1.0
**Status:** Implemented, simulator-audited, real-device acceptance pending

---

## 1. Executive summary

FISH TANK is a Connect IQ device app for round Garmin watches. It is a pixel-art aquarium game built around run-to-earn: runs recorded by the watch's built-in Run app are paid into the aquarium economy once, then used to care for fish, collect species, build the tank, explore regions, complete quests, and join a personal league.

Current snapshot:

| Item | Value |
|---|---|
| App type | Device App / watch app |
| Version | 1.1.0 |
| Manifest target | 63 devices |
| Buildable package now | 59 devices |
| Package size | 9.23 MB |
| Binaries in package | 72 |
| Unit tests | 50/50 PASS |
| Visual audit | 26 screens on FR165 (390 px) |
| 4 legacy devices missing | `enduro2`, `venu2`, `venu2plus`, `venu2s` |
| Real-device test | Pending |

The product is feature-complete for the documented v1.1.0 scope. The remaining release work is validation and packaging, not new gameplay.

---

## 2. Product identity

| Attribute | Value |
|---|---|
| Name | FISH TANK |
| Title EN | FISH TANK - Pocket Aquarium |
| Title ID | FISH TANK - Akuarium Saku |
| Type | Device App (watch app) |
| Store category | Games (Health and Fitness if Games is unavailable) |
| App ID | `f15a7c2e8b4d4e6a9c3d1b0e5a7f2c91` |
| Version | 1.1.0 |
| minApiLevel | 4.2.0 |
| App language | `eng` (UI is currently English) |
| Permission | `UserProfile` (activity history) |
| Storage | On-watch only; no account, phone app, or internet |
| Font | Pixelify Sans, SIL Open Font License 1.1 |

---

## 3. Store copy

### 3.1 Title

**EN:** `FISH TANK - Pocket Aquarium`

**ID:** `FISH TANK - Akuarium Saku`

### 3.2 Description (EN)

```text
A pixel-art aquarium on your wrist that grows every time you run.

RUN TO EARN
Run with your watch's own Run app as usual. Open FISH TANK afterwards and each new run is paid once, even runs from earlier the same week you installed it: 100 m = 1 coin, with bonuses for consistent weeks, long runs, your first run of the week and pace PRs. Daily step milestones (3k / 5k / 8k / 10k) and distance milestones (25 to 500 km) add pearls, keys and eggs.

CARE FOR YOUR FISH
Feed them (each species has a favorite food), clean the glass, pet them. Fish grow from baby to adult, level up and can evolve. Fish never die: if life gets busy they just wait for you.

COLLECT 36 SPECIES
Five habitats: Tropical, Freshwater, Fantasy, Frozen and Deep Sea. Hatch eggs (running hatches them faster), discover rare Shiny, Golden, Ghost and Giant variants, breed pairs and fill your Fishdex.

BUILD & EXPLORE
Place 16 decorations in Build mode, match fish to their favorite habitat for a happiness bonus, expand your tank to 8 fish and earn up to 5 stars. Your total distance unlocks five ocean regions with new fish, decor and themes.

SOMETHING NEW EVERY WEEK
- 15 yearly events (New Year, World Oceans Day, Halloween, Ramadan, Lunar New Year and more) with exclusive edition fish
- A weekly current that changes the rules, a featured fish on sale and a rare visitor
- Daily and weekly quests, 33 trophies and a personal weekly league
- Three mini-games: Bubble Pop, Treasure Dive and Fish Racing
- Race Day: set your race date and get a big reward for racing it

MAKE IT YOURS
3 art styles (Modern Pixel, Minimalist, Pseudo-3D) x 6 themes. Switch any time, your progress is kept.

Works with touch and with buttons. Everything stays on your watch: no phone app, no account, no internet needed.

Permission: FISH TANK reads your activity history (date, sport type, distance and duration of runs) only to pay run rewards. Nothing is sent anywhere.

Font: Pixelify Sans by Stefie Justprince, SIL Open Font License 1.1.
```

### 3.3 Description (ID)

```text
Akuarium pixel-art di pergelangan tangan yang tumbuh setiap kali kamu lari.

LARI JADI KOIN
Lari seperti biasa dengan app Run bawaan jam. Setelah itu buka FISH TANK dan setiap lari baru dibayar satu kali, termasuk lari di minggu yang sama sebelum app dipasang: 100 m = 1 koin, dengan bonus untuk minggu yang konsisten, lari jauh, lari pertama minggu ini dan rekor pace. Target langkah harian (3rb / 5rb / 8rb / 10rb) dan milestone jarak (25 sampai 500 km) memberi pearl, kunci dan telur.

RAWAT IKANMU
Beri makan (tiap spesies punya makanan favorit), bersihkan kaca, elus ikanmu. Ikan tumbuh dari bayi sampai dewasa, naik level dan bisa berevolusi. Ikan tidak pernah mati: kalau kamu sibuk, mereka menunggu.

KOLEKSI 36 SPESIES
Lima habitat: Tropis, Air Tawar, Fantasi, Beku dan Laut Dalam. Tetaskan telur (lari membuatnya lebih cepat menetas), temukan varian langka Shiny, Golden, Ghost dan Giant, kembangbiakkan pasangan dan lengkapi Fishdex.

BANGUN & JELAJAHI
Pasang 16 dekorasi di mode Build, cocokkan ikan dengan habitat favoritnya untuk bonus kebahagiaan, perbesar akuarium sampai 8 ikan dan raih 5 bintang. Total jarak lari membuka lima wilayah laut dengan ikan, dekor dan tema baru.

SELALU ADA YANG BARU
- 15 event tahunan (Tahun Baru, Hari Laut Sedunia, HUT RI, Hari Batik, Ramadan, Imlek dan lainnya) dengan ikan edisi khusus
- Arus mingguan yang mengubah aturan main, ikan unggulan diskon dan pengunjung langka
- Quest harian dan mingguan, 33 trophy dan liga mingguan pribadi
- Tiga mini-game: Bubble Pop, Treasure Dive dan Fish Racing
- Race Day: atur tanggal lombamu dan dapatkan hadiah besar saat berlomba

SESUAIKAN GAYAMU
3 gaya visual (Modern Pixel, Minimalist, Pseudo-3D) x 6 tema. Ganti kapan saja, progres tetap aman.

Bisa dengan layar sentuh maupun tombol. Semua tersimpan di jam: tanpa app HP, tanpa akun, tanpa internet.

Izin: FISH TANK membaca riwayat aktivitas (tanggal, jenis olahraga, jarak dan durasi lari) hanya untuk membayar hadiah lari. Tidak ada data yang dikirim ke mana pun.

Huruf: Pixelify Sans oleh Stefie Justprince, SIL Open Font License 1.1.
```

---

## 4. Features and functions

### 4.1 Move: run-to-earn and activity

| Feature | Function |
|---|---|
| Run-to-Earn | Each new run from the watch's Run app is paid once. 100 m = 1 coin, capped at 300 coins per day. Bonuses for consistent weeks, long runs, first run of the week, and pace PRs. |
| Runs before install | Runs from the same week before the app was installed count. A 5 km morning run followed by an evening install can finish the 2 km, 3 km, and "1 run" daily quests immediately, with a RUN FOUND card. |
| Step Hunter | Daily step milestones at 3k, 5k, 8k, and 10k steps. |
| Consistency streak | Active days per week build a streak and a weekly bonus. |
| Distance milestones | Total distance from 25 to 500 km grants pearls, keys, and eggs. |
| Activity Journal | Shows this week's distance, today's distance, number of runs, duration, and pace. |
| Fallback mode | If run history is unavailable, daily distance can drive progress after several days. |

### 4.2 Collect: species, eggs, variants, breeding

| Feature | Function |
|---|---|
| 36 species, 5 habitats | Tropical, Freshwater, Fantasy, Frozen, and Deep Sea. |
| Fishdex | Collection screen for every species, including undiscovered silhouettes. |
| Eggs | Eggs hatch over time; running makes them hatch faster. |
| Rare variants | Shiny, Golden, Ghost, and Giant. |
| Personality, level, evolution | Each fish has a personality, gains levels, and can evolve. |
| Breeding | Compatible adult pairs can breed. |

### 4.3 Care and Build

| Feature | Function |
|---|---|
| Feed | Feed fish; each species has a favorite food. |
| Clean | Clean the glass; dirt builds up over time. |
| Pet | Interact with fish. |
| Fish never die | If the player is busy, fish wait and do not die. |
| 16 decorations | Place decorations in Build mode. |
| Habitat synergy | Fish matched to their favorite habitat receive a happiness bonus. |
| Aquarium level 1-5 | Expands capacity up to 8 fish. |
| Star rating | Fish, decorations, and habitat determine a rating up to 5 stars. |

### 4.4 Explore and mini-games

| Feature | Function |
|---|---|
| 5 expedition regions | Regions unlock with total distance; 2 regions unlock new themes. |
| Bubble Pop | 20-second mini-game: pop bubbles matching the target color. Wrong color costs a point. Tap or select a lane with UP/DOWN and press START. |
| Treasure Dive | 5 depths, 3 caves per depth, one eel, 3 lives. |
| Fish Racing | Choose a fish, race with boost, earn rewards and a best score. |

### 4.5 Compete

| Feature | Function |
|---|---|
| Daily and weekly quests | Running, step, decoration, event, and other targets. |
| 33 trophies | Long-term achievements. |
| Aquarium League | A personal weekly league with a target that adapts to performance. |

### 4.6 Events

| Feature | Function |
|---|---|
| 15 yearly events | New Year, World Oceans Day, Indonesian Independence Day, Batik Day, Halloween, and others. Repeats yearly without an app update. |
| Ramadan, Eid, Lunar New Year | Dates computed automatically, including Hijri date correction. |
| Personal events | Race Day, birthday, and tank anniversary. |
| Weekly current | Rotating rules, a discounted featured fish, a rare visitor, and a spotlight mini-game. |
| Edition fish | Each event has a quest and an exclusive edition fish. |

### 4.7 Display and input

| Feature | Function |
|---|---|
| 3 art styles | Modern Pixel, Minimalist, Pseudo-3D. |
| 6 themes | Different palettes and moods. |
| Pixelify Sans | Per-resolution pixel font, kept sharp on small screens. |
| Touch and buttons | Playable with touch and with physical buttons. |
| Local-only | No account, phone app, or internet connection. |
| UserProfile permission | Reads activity history only to pay run rewards. Nothing is sent anywhere. |

### 4.8 Performance and multi-device

| Feature | Function |
|---|---|
| Adaptive frame rate | 15, 12, 10, or 7.5 fps depending on watch capability and scene cost. |
| Time-based motion | Motion advances by real elapsed time, so a late frame does not make fish jump. |
| Staged work | Per-minute work and autosave are spread across frames. |
| Scene cache | Static scenery is cached; fish and overlays are drawn per frame. |
| Multi-device layout | A 390 x 390 canvas is mapped to 218-454 px screens. |
| Per-resolution fonts | Font sets for 218, 240, 260, 280, 360, 416, and 454 px. |
| MIP color handling | Very dark water tones are lifted on 64-color MIP screens so they do not turn black. |

---

## 5. User flow

1. First open: onboarding, tutorial, daily gift, then the tank.
2. Tank: coin/level/XP HUD, tank condition, and the Feed, Clean, Menu dock.
3. Run: run with the built-in Run app, open FISH TANK, receive a RUN REWARD or RUN FOUND card, coins and quest progress are paid once.
4. Care: feed, clean, pet; fish grow, level up, and evolve.
5. Menu: Shop (fish, eggs, food, decorations), Inventory, Quests, Activity, Expedition, Games, Fishdex, Trophies, League, Profile, Events, Settings.
6. Build: select a slot, place or remove decorations, check rating and synergy.
7. Explore: unlock regions and play the three mini-games.
8. Compete: finish quests, claim trophies, follow the league.
9. Events: yearly events, personal events, and the weekly current.
10. Settings: art style, aquarium theme, and other preferences.
11. Save: local autosave; no cloud.

---

## 6. Device compatibility

| Category | Detail |
|---|---|
| Manifest target | 63 devices |
| Buildable package now | 59 devices |
| Missing device definitions | `enduro2`, `venu2`, `venu2plus`, `venu2s` |
| Screen sizes | 218, 240, 260, 280, 360, 390, 416, 454 px |
| Display types | AMOLED and 64-color MIP |
| Input | Touch and buttons |
| Families | Forerunner, fenix, epix, Enduro, Venu, vivoactive, MARQ, Instinct, D2 Mach, Approach S70 |

Devices already in the 59-device package include: FR165/170/255/265/570/955/965/970, fenix 7/8/9 and Pro/Solar, epix Gen 2/Pro, Enduro 3/4, Venu 3/4, vivoactive 5/6, MARQ 2/3, Instinct 3 AMOLED/Crossover, D2 Mach, and Approach S70.

The four legacy devices remain in the manifest. Their SDK 9.3 device definitions are not installed on the current machine, so `monkeyc` rejects a full 63-device package. Install them in SDK Manager, then rebuild.

---

## 7. Build, test, and release status

| Item | Status |
|---|---|
| Latest commit | `d05efbb` |
| Manifest products | 63 |
| Final package | `bin/FishTank-v1.1.0-59devices.iq` |
| Package size | 9.23 MB |
| Binaries in package | 72 |
| Mapped device IDs | 59 |
| App ID | `f15a7c2e8b4d4e6a9c3d1b0e5a7f2c91` |
| Version | 1.1.0 |
| Unit tests | 50/50 PASS |
| Device compile | 59/59 OK |
| Sideload bundle | `bin/FishTank-sideload-fr165-fr57047.zip` |
| Build report | `bin/BUILD-REPORT.txt` |
| Signing key | Same `developer_key.der`; keep a backup |
| Git | `main` = `origin/main` |

Build commands:

```powershell
cd "D:\Garmin\Fish Tank App"
.\tools\build.ps1
$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim()
& "$sdk\bin\monkeyc.bat" -e -r -f monkey.jungle -o bin\FishTank-v1.1.0-63devices.iq -y "$env:USERPROFILE\.Garmin\ConnectIQ\developer_key.der"
```

The 63-device command requires the four legacy device definitions. For a 59-device package, temporarily exclude those four products from the manifest during packaging, or use the current package.

---

## 8. Visual audit and recent fixes

Audited on the FR165 simulator (390 x 390), 26 screens:

- Tank, Main, Shop Fish, Inventory, Fish Profile, Quests, Activity, Expedition
- Games, Fishdex, Trophies, League, Profile, Settings, Shop Decor, Events
- Bubble Pop, Treasure Dive, Fish Racing
- Card Gift, Card Run, Card Event, Build, Coach
- Style picker, theme picker, fixed Bubble Pop

Findings and fixes:

| Finding | Fix |
|---|---|
| Bubble Pop target banner "PINK" was covered by rising bubbles | HUD and "POP <color>" banner are drawn after the playfield; the banner has a dark pill behind the text |
| Activity footer was clipped by the round edge | Footer moved to 0.85h; text shortened to "Runs from Run app" |
| Games footer was clipped | Text shortened to "3 plays a day" |
| Expedition description was truncated | Descriptions shortened to fit the 228 px info box |
| Events row "Featured: Royal Gr.." was truncated | Row uses the fish name; sublabel shows "Featured -30%: price" |
| Feed/clean could briefly clear the tank on AMOLED | Scene-rebuild guard is now MIP-only; feed 5x tested on FR570 47 |

No text overlap or container overflow was found on the other audited screens. The style/theme picker intentionally covers the lower tank as a modal preview; this is a design choice, not a text collision.

---

## 9. Known limitations and risks

1. Four legacy devices are not in the 59-device package: `enduro2`, `venu2`, `venu2plus`, `venu2s`.
2. Real-device acceptance on FR165 is still pending. The simulator cannot prove `getUserActivityHistory()` returns a pre-install morning run.
3. Interactive states are not fully audited: buying, hatching, claiming, all Build slots, mini-game intro/result/BACK, save/reload, onboarding.
4. Empty and extreme states are not fully audited: 0 fish, 8 fish, 36 Fishdex, 33 trophies, 10 Settings rows, long names, long text cards.
5. Device matrix is partial: 280, 360, and 416 px, MIP memory, button-only Instinct/D2, and touch-only Venu/vivoactive need coverage.
6. On 218-280 px MIP screens, the scene-rebuild guard remains active for watchdog stability. Feed or clean can briefly hide overlays there.
7. Store screenshots are still from v1.0.0 and should be regenerated from the final build.
8. The app UI is English (`eng`); the store descriptions are available in EN and ID.
9. If v1.1.0 has already been uploaded, this fix set requires version 1.1.1.
10. The v1.1.0 store checklist is not fully checked.

---

## 10. Recommendations

1. Real-device FR165 acceptance: sideload, run 5 km in the morning, install at night, open the app, confirm RUN FOUND; check feed/clean, FPS, touch/buttons, and migration from an older save.
2. Interactive simulator audit: onboarding, economy, hatch, claim, style/theme, Build, cards, all three mini-games, save/reload.
3. Empty and extreme audit: 0/8 fish, 36 Fishdex, 33 trophies, 10 Settings rows, long text.
4. Device matrix: 280/360/416 px, MIP memory, button-only and touch-only devices.
5. Store pack: regenerate store screenshots from the final build, fill the checklist, confirm version and signing key.
6. Documentation and release pack: use `project-docs-skills` for README, store listing, changelog, handoff, and clean screenshots.
7. Full 63-device package: install the four legacy device definitions in SDK Manager and rebuild.

---

## Appendix A: Permission and privacy

- Permission: `UserProfile`.
- Read: activity history (date, sport type, distance, duration) only to pay run rewards.
- Network: none.
- Account: none.
- Phone app: none.
- Data location: on-watch local storage.

## Appendix B: Artifacts

| Artifact | Path |
|---|---|
| Store package | `bin/FishTank-v1.1.0-59devices.iq` |
| Sideload bundle | `bin/FishTank-sideload-fr165-fr57047.zip` |
| Build report | `bin/BUILD-REPORT.txt` |
| Historical package | `bin/_archive/FishTank-v1.0.0.iq` |
| Store listing | `docs/store-listing.md` |
| Screenshots | `docs/screens/` |
| Store images | `docs/store/` |
