# ReadyRun

Watch app Garmin Connect IQ untuk ringkasan **readiness, training status, form, dan rekomendasi latihan**.

## Isi folder

- `source/AppState.mc`, `MainDelegate.mc`, `MainView.mc`, `NavModel.mc`, `ReadyRunApp.mc` — entry point dan navigasi
- `source/Data/` — availability, health, history, mock/real provider, training data
- `source/Engine/` — readiness, recommendation, training status, form engine
- `source/Model/` — model hasil
- `source/UI/` — layar home, today, training form, training status, body readiness
- `resources/` — strings, drawables, ikon
- `docs/reference-ui.jpg` — referensi visual UI

## Build

```sh
monkeyc -f monkey.jungle -d fr165 -o bin/readyrun.prg -y developer_key.der
monkeydo bin/readyrun.prg fr165
```

## Catatan

`reload_and_capture.ps1` adalah helper lokal untuk memuat ulang dan menangkap tampilan simulator.
