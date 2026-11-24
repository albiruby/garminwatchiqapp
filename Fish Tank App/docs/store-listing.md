# FISH TANK: Connect IQ Store listing (v1.1.0)

Upload: `bin/FishTank-v1.1.0.iq` (15 round AMOLED watches: Forerunner 165 / 165 Music / 265 / 265S / 965, fenix 8 43/47 mm, fenix E, epix Gen 2, epix Pro 42/47/51 mm, Venu 3 / 3S, vivoactive 5).
Images: `docs/store/` (HERO, COVER, SCREEN_1 to SCREEN_5), all within portal limits.
Masters: `docs/store/master/`. Regenerate: `tools\capture.ps1 ...`, then `python -I tools\compose-store.py`.

> **Signing key:** built with `%USERPROFILE%\.Garmin\ConnectIQ\developer_key.der`
> (MD5 `606dc14c68e85256773b44df148f49a3`). Every future update **must** be signed with this
> same key, or the store rejects it. Keep a backup of it.

Rebuild the package:
```powershell
$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim()
& "$sdk\bin\monkeyc.bat" -e -r -f monkey.jungle -o bin\FishTank-v1.1.0.iq -y "$env:USERPROFILE\.Garmin\ConnectIQ\developer_key.der"
```

## App type & category
- Type: **Device App** (watch app)
- Category: **Games** (or Health & Fitness if Games is not offered)
- App ID: `f15a7c2e8b4d4e6a9c3d1b0e5a7f2c91`

## Title
- EN: `FISH TANK - Pocket Aquarium`
- ID: `FISH TANK - Akuarium Saku`

## Description (EN)
```
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

## Deskripsi (ID)
```
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

## What's New (v1.1.0)
EN:
```
v1.1.0
- Runs and steps from earlier the same day or week count, also from before you installed the app: quests already met finish right away
- Running quests count each run on the day it was run
- Activity Journal shows this week's and today's distance
- Smoother animation: the frame rate adapts to your watch, no more hitch every minute
- Stability: a long backlog of runs, a wrong watch date or a damaged save no longer cause problems
- Now on 15 round AMOLED watches: Forerunner 265/265S/965, fenix 8, fenix E, epix, Venu 3, vivoactive 5
```
ID:
```
v1.1.0
- Lari dan langkah di hari/minggu yang sama ikut dihitung, termasuk sebelum app dipasang: quest yang sudah terpenuhi langsung selesai
- Quest lari menghitung setiap lari di hari lari itu dilakukan
- Activity Journal menampilkan jarak minggu ini dan hari ini
- Animasi lebih mulus: frame rate menyesuaikan jam, tidak ada lagi tersendat tiap menit
- Stabilitas: banyak lari yang tertunda, tanggal jam yang salah atau data save rusak tidak lagi bermasalah
- Kini di 15 jam bulat AMOLED: Forerunner 265/265S/965, fenix 8, fenix E, epix, Venu 3, vivoactive 5
```

## What's New (v1.0.0)
EN:
```
v1.0.0 - First release
- Run-to-earn from your watch's Run app, step and distance milestones
- 36 fish, eggs, variants, evolution and breeding
- Build mode, habitat synergy, 5 ocean regions
- 15 yearly events, weekly currents, quests, trophies and a personal league
- Bubble Pop, Treasure Dive and Fish Racing
- 3 art styles x 6 themes
```
ID:
```
v1.0.0 - Rilis pertama
- Lari jadi koin dari app Run bawaan, milestone langkah dan jarak
- 36 ikan, telur, varian, evolusi dan breeding
- Mode Build, habitat synergy, 5 wilayah laut
- 15 event tahunan, arus mingguan, quest, trophy dan liga pribadi
- Bubble Pop, Treasure Dive dan Fish Racing
- 3 gaya visual x 6 tema
```

## Images
| Portal field | File | Size |
|---|---|---|
| Hero image | `docs/store/HERO_1440x720.jpg` | 1440x720, 190 KB |
| Cover image | `docs/store/COVER_500x500.jpg` | 500x500, 45 KB |
| Screen image 1 | `docs/store/SCREEN_1_pocket-aquarium.jpg` | 1440x900, < 120 KB |
| Screen image 2 | `docs/store/SCREEN_2_run-to-earn.jpg` | 1440x900, < 120 KB |
| Screen image 3 | `docs/store/SCREEN_3_collect.jpg` | 1440x900, < 120 KB |
| Screen image 4 | `docs/store/SCREEN_4_build-explore.jpg` | 1440x900, < 120 KB |
| Screen image 5 | `docs/store/SCREEN_5_events-games.jpg` | 1440x900, < 120 KB |

## Upload checklist
- [ ] Sideload `bin\FishTank-fr165.prg` on a real FR165 first (copy to `GARMIN\APPS`).
- [ ] Do a 1 km+ run with the built-in Run app, open FISH TANK: a RUN REWARD card appears.
  If it does not, the app switches to daily distance after 3 days (see Activity > footer).
- [ ] Check touch and buttons on the watch: feed, clean, menu, a mini-game, Build mode.
- [ ] v1.1.0: with a 2 km+ run done earlier today, delete the app's data (or install fresh) and
  open FISH TANK: after onboarding a RUN FOUND card appears and "Run 2 km" / "Go for 1 run" are done.
  Activity > "This week" shows the week's runs.
- [ ] v1.1.0: watch the tank for 2 minutes: no stutter at the minute mark, motion stays even.
- [ ] v1.1.0: start a mini-game, press BACK mid-round: Games shows one play fewer.
- [ ] v1.1.0 multi-device: in SDK Manager download the new devices, run `tools\build.ps1`
  (remove any product the SDK rejects), then check one watch per screen size in the simulator:
  fr265s (360), fr165 (390), fr265 (416), fr965 (454). Tank, menu, a card, Build mode, each
  mini-game and the date picker; on venu3 / vivoactive5 (2 buttons) do it all by touch.
- [ ] v1.1.0: Settings > Ramadan / Eid dates, cycle the shift during an event: no second gift.
- [ ] Developer portal > Upload an App > `bin\FishTank-v1.1.0.iq`.
- [ ] Title, descriptions (EN + ID), What's New, category, images from the table above.
- [ ] Permission note is in the description (UserProfile: activity history).
- [ ] Keep `developer_key.der` (MD5 above) backed up for every future update.
