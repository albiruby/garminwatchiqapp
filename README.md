# Garmin

Koleksi project Garmin Connect IQ + tooling data aktivitas. Satu folder per project.

| Folder | Project | Keterangan |
|---|---|---|
| [`Goals Watchface/`](Goals%20Watchface/) | **PULSEFORM** | Activity-goal watch face, Forerunner 165 (390×390 AMOLED) |
| [`RacePilot/`](RacePilot/) | **RacePilot** | Race-pacing data field: lap pace, projected finish, need pace |
| [`Restora/`](Restora/) | **RESTORA** | Guided recovery sessions di jam |
| [`WatchCraft/`](WatchCraft/) | **WatchCraft** | Studio watch face + data field (web + Connect IQ) |
| [`Batik Watchface/`](Batik%20Watchface/) | **NUSANTARA** | Batik watch faces: Kawung, Megamendung, Parang |
| [`API-Key-Data-Fetch/`](API-Key-Data-Fetch/) | Tooling | Fetch aktivitas via Garmin Personal API + laporan sesi `.md` |
| [`WorkoutMCP/`](WorkoutMCP/) | Tooling | Workout MCP server (Python) |

## Aturan

- **API key tidak pernah di-commit.** `API-Key-Data-Fetch/garmin-api-key.txt`, `*.der`, `*.pem`, dan `.env` di-ignore di root `.gitignore`.
- Build output (`bin/`, `build/`, `node_modules/`, `.venv/`, `.next/`) tidak ikut repo.
- Tiap project Connect IQ di-build dari foldernya sendiri, misal:

```powershell
cd "Goals Watchface"
$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg").Trim()
& "$sdk\bin\monkeyc.bat" -d fr165 -f monkey.jungle -o bin\PulseForm.prg -y <developer_key>.der
```
