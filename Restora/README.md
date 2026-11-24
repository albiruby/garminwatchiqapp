# Garmin Connect IQ Apps

Monorepo untuk project Garmin Connect IQ pribadi: watch app, data field, dan工具 pendukung. Root repository adalah **RESTORA**; project lain berada di bawah `projects/`.

## Daftar project

| Project | Lokasi | Jenis | Ringkasan |
|---|---|---|---|
| **RESTORA** | `.` (root) | Watch app | Guided recovery & breathing companion untuk FR165/165 Music. Bukan perangkat medis. |
| **RacePilot** | `projects/racepilot/` | Data field | Race-pacing data field: lap pace, projected finish, need pace; GPS/track/treadmill engine. |
| **Nusantara Batik** | `projects/batik-watchface/` | Watch face | Tiga varian watch face: Kawung, Megamendung, Parang. |

Dokumen lanjutan:
- [RESTORA README](docs/RESTORA.md)
- [RESTORA handover](HANDOVER.md)
- [RacePilot architecture](projects/racepilot/ARCHITECTURE.md)
- [RacePilot roadmap](projects/racepilot/ROADMAP.md)
- [Batik watchfaces](projects/batik-watchface/README.md)

<!-- GALLERY:START -->

## Galeri

5 gambar terpenting per project.

### RESTORA

| ![RESTORA 1](<docs/store/screenshots/01-home.png>) | ![RESTORA 2](<docs/store/screenshots/07-figure.png>) | ![RESTORA 3](<docs/store/screenshots/09-figure-front.png>) | ![RESTORA 4](<docs/store/screenshots/04-breathing.png>) | ![RESTORA 5](<docs/store/screenshots/05-summary.png>) |
|---|---|---|---|---|

### RacePilot

| ![RacePilot 1](<projects/racepilot/docs/screenshots/v2.2.0/HeroImage_v2.2.0.jpg>) | ![RacePilot 2](<projects/racepilot/docs/screenshots/v2.2.0/fr165_standard_hud.png>) | ![RacePilot 3](<projects/racepilot/docs/screenshots/v2.2.0/fr165_delta_coros.png>) | ![RacePilot 4](<projects/racepilot/docs/screenshots/v2.2.0/fr165_grid_fr170.png>) | ![RacePilot 5](<projects/racepilot/docs/screenshots/multi-device/RacePilot_fr965_454x454.png>) |
|---|---|---|---|---|

### Nusantara Batik

| ![Nusantara Batik 1](<projects/batik-watchface/nusantara-kawung/docs/mockups/01-main-fr165.png>) | ![Nusantara Batik 2](<projects/batik-watchface/nusantara-megamendung/docs/mockups/01-main-fr165.png>) | ![Nusantara Batik 3](<projects/batik-watchface/nusantara-parang/docs/mockups/01-main-fr165.png>) | ![Nusantara Batik 4](<projects/batik-watchface/nusantara-kawung/docs/mockups/live-trio/live-pattern-3-devices.png>) | ![Nusantara Batik 5](<projects/batik-watchface/nusantara-kawung/docs/mockups/live-trio/1-fr165-25.png>) |
|---|---|---|---|---|

<!-- GALLERY:END -->

## Prasyarat

- Garmin Connect IQ SDK (`monkeyc`, `connectiq`, `monkeydo`)
- Developer key pribadi (`.der`), **tidak disimpan di repo ini**
- Device target: FR165/165 Music atau perangkat lain yang didukung manifest

## Build umum

Dari folder project yang ingin dibangun:

```sh
monkeyc -f monkey.jungle -d fr165 -o bin/<nama>.prg -y developer_key.der
monkeydo bin/<nama>.prg fr165
```

Untuk unit test (mis. RESTORA / Nusantara Kawung):

```sh
monkeyc -f monkey.jungle -d fr165 -o bin/<nama>-test.prg -y developer_key.der --unit-test
monkeydo bin/<nama>-test.prg fr165 /t
```

`bin/`, `*.prg`, `*.iq`, dan artifact build lainnya sengaja diabaikan oleh git.

## Struktur repo

```
.
├── source/, resources/, manifest.xml, monkey.jungle   # RESTORA (root)
├── docs/                                             # dokumentasi tambahan
├── projects/
│   ├── racepilot/
│   └── batik-watchface/
├── HANDOVER.md
└── .gitignore
```

## Keamanan

- Jangan commit `developer_key.der`, `developer_key.pem`, token Garmin, API key, atau file `.env`.
- Semua pola tersebut sudah ditambahkan ke `.gitignore`.
- Jika kredensial tidak sengaja ter-commit, cabut/putar kunci tersebut segera dan hapus dari riwayat git.

## Catatan

- Beberapa project masih dalam pengembangan; status tiap project ada di README masing-masing.
- Project dengan repo sendiri (mis. WatchCraft) tidak digabungkan ke sini.
