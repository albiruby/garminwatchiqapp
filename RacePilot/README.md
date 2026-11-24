# RacePilot

Premium race-pacing data field untuk Garmin Connect IQ, target awal **Forerunner 165** (390×390 AMOLED). Menampilkan lap pace, distance/time, projected finish, dan need pace.

## Isi folder

- `sources/` — engine dan logika inti (GPS, track, treadmill, state machine, confidence, prediction, layout, rendering)
- `resources/` — strings, settings, drawables, fit contributions
- `manifest.xml`, `monkey.jungle` — konfigurasi project Connect IQ
- `ARCHITECTURE.md` — peta modul dan alur data
- `ROADMAP.md`, `HARDWARE_TEST_CHECKLIST.md` — status dan rencana pengujian
- `STORE_METADATA_DRAFT.md`, `STORE_UPLOAD_v2.2.0.md` — material publikasi store
- `Asset Developer Portal/` — aset Developer Portal (cover, hero, screen images)
- `SS Multi Device - CIQ Simulator/` — screenshot simulator lintas perangkat
- `SS Redesign UI/` — HUD/redesign terbaru (hero, store shots v2.2.0, multi-device)
- `LogoRacePilot.png` — aset branding
- `buildandsim.bat`, `RunSimulator.bat`, `start.bat` — helper build/simulator Windows

## Galeri

![RacePilot v2.2.0](<SS Redesign UI/Hero v2.2.0/HeroImage_v2.2.0.jpg>)

| ![Projected finish](<SS Redesign UI/Store v2.2.0/01_projected_finish.jpg>) | ![Ahead / behind](<SS Redesign UI/Store v2.2.0/02_ahead_behind.jpg>) | ![Grid](<SS Redesign UI/Store v2.2.0/03_grid.jpg>) |
|---|---|---|
| ![AMOLED](<SS Redesign UI/Store v2.2.0/04_amoled.jpg>) | ![Edge](<SS Redesign UI/Store v2.2.0/05_edge.jpg>) | ![Forerunner 165](<SS Multi Device - CIQ Simulator/RacePilot_fr165_390x390.png>) |

## Build

```sh
monkeyc -f monkey.jungle -d fr165 -o bin/racepilot.prg -y developer_key.der
monkeydo bin/racepilot.prg fr165
```

Unit test ada di `sources/UnitTestRunner.mc`.

## Status

Versi v2.2.0 memiliki perbaikan projection lock, AUTO GPS-loss flip, FIT charts, dan alert throttle. Store assets sudah disiapkan.
