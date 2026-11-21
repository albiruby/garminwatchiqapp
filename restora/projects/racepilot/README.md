# RacePilot

Premium race-pacing data field untuk Garmin Connect IQ, target awal **Forerunner 165** (390×390 AMOLED). Menampilkan lap pace, distance/time, projected finish, dan need pace.

## Isi folder

- `sources/` — engine dan logika inti (GPS, track, treadmill, state machine, confidence, prediction, layout, rendering)
- `resources/` — strings, settings, drawables, fit contributions
- `manifest.xml`, `monkey.jungle` — konfigurasi project Connect IQ
- `ARCHITECTURE.md` — peta modul dan alur data
- `ROADMAP.md`, `HARDWARE_TEST_CHECKLIST.md` — status dan rencana pengujian
- `STORE_METADATA_DRAFT.md`, `STORE_UPLOAD_v2.2.0.md` — material publikasi store
- `docs/store/` — aset Developer Portal (cover, hero, screen images)
- `docs/screenshots/multi-device/` — screenshot simulator lintas perangkat
- `docs/screenshots/v2.2.0/` — HUD/redesign terbaru + store shots
- `LogoRacePilot.png` — aset branding
- `buildandsim.bat`, `RunSimulator.bat`, `start.bat` — helper build/simulator Windows

## Build

```sh
monkeyc -f monkey.jungle -d fr165 -o bin/racepilot.prg -y developer_key.der
monkeydo bin/racepilot.prg fr165
```

Unit test ada di `sources/UnitTestRunner.mc`.

## Status

Versi v2.2.0 memiliki perbaikan projection lock, AUTO GPS-loss flip, FIT charts, dan alert throttle. Store assets sudah disiapkan.
