# RESTORA

Guided recovery & breathing companion untuk Forerunner 165 / 165 Music. Bukan perangkat medis.

Dokumen lanjutan:
- [RESTORA](docs/RESTORA.md)
- [Handover](HANDOVER.md)
- [Calculation engine](docs/CALCULATION_ENGINE.md), [Motion engine](docs/MOTION_ENGINE.md), [Design system](docs/DESIGN_SYSTEM.md)
- Store: [listing](docs/store/STORE_LISTING.md), [release notes](docs/store/RELEASE_NOTES.md), [privacy](docs/store/PRIVACY.md)

## Galeri

| ![Home](<docs/store/screenshots/01-home.png>) | ![Module](<docs/store/screenshots/02-module.png>) | ![Detail](<docs/store/screenshots/03-detail.png>) | ![Breathing](<docs/store/screenshots/04-breathing.png>) | ![Summary](<docs/store/screenshots/05-summary.png>) |
|---|---|---|---|---|
| ![End session](<docs/store/screenshots/06-end-session.png>) | ![Figure](<docs/store/screenshots/07-figure.png>) | ![Figure hip](<docs/store/screenshots/08-figure-hip.png>) | ![Figure front](<docs/store/screenshots/09-figure-front.png>) | ![Countdown](<docs/store/screenshots/10-countdown.png>) |

## Prasyarat

- Garmin Connect IQ SDK (`monkeyc`, `connectiq`, `monkeydo`)
- Developer key pribadi (`.der`), **tidak disimpan di repo ini**
- Device target: FR165/165 Music atau perangkat lain yang didukung manifest

## Build

Dari folder `Restora/`:

```sh
monkeyc -f monkey.jungle -d fr165 -o bin/Restora.prg -y developer_key.der
monkeydo bin/Restora.prg fr165
```

Unit test:

```sh
monkeyc -f monkey.jungle -d fr165 -o bin/Restora-test.prg -y developer_key.der --unit-test
monkeydo bin/Restora-test.prg fr165 /t
```

`bin/`, `*.prg`, `*.iq`, dan artifact build lainnya sengaja diabaikan oleh git.

## Keamanan

- Jangan commit `developer_key.der`, `developer_key.pem`, token Garmin, API key, atau file `.env`.
- Jika kredensial tidak sengaja ter-commit, cabut/putar kunci tersebut segera dan hapus dari riwayat git.
