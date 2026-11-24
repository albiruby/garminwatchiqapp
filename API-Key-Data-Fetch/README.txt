GARMIN PERSONAL API KEY
=======================

Dibuat: 2026-10-25

ISI FOLDER
----------
garmin-api-key.txt                  Key API (jangan dibagikan)
load-key.ps1                        Load key ke $env:GARMIN_API_KEY
Garmin-Weekly-Report-2026-10-19_25.md   Laporan mingguan ringkas 19-25 Okt 2026
Garmin-Weekly-Report-2026-10-19_25-DETAIL.md  Laporan detail per hari + per sesi
Garmin-Highest-Heart-Rate-2025-10-27_2026-10-27.md  Laporan highest HR 3/6/12 bulan
Garmin-Session-2026-10-31-Bogor-20x400.md  Analisis sesi 20x400 (FIT+TCX)
Garmin-Session-2026-11-03-Treadmill-3x9.md  Analisis sesi treadmill 3x9' (FIT+API)
Garmin-Session-2026-11-10-Treadmill-5x5.md  Analisis sesi treadmill 5x5' (FIT+API)
Garmin-Session-2026-11-12-Treadmill-Over-Under-Fartlek-35.md  Rekap lengkap Over Under Fartlek 35' (FIT+API)
Garmin-Session-2026-11-14-Bogor-16x600.md  Full audit + laporan Bogor 16x600 (FIT+API)
Garmin-Session-2026-11-17-Treadmill-3x10.md  Analisis treadmill 3x10' (FIT+API)
Garmin-Session-2026-11-19-Treadmill-CutDown-Blocks-32.md  Full audit Cut-Down Threshold Blocks 32'
Garmin-Session-2026-11-21-Bogor-Hills-10x-4x12-Sprint.md  Full audit Hills 10x + 4x12 Sprint
Garmin-Session-2026-11-22-Treadmill-Steady-20km.md  Laporan super lengkap treadmill steady 20 km
Garmin-Daily-2026-11-22-1811.md      Laporan harian lengkap cutoff 18:11 (sleep, HR, stress, BB, SpO2, kalori)
Garmin-Calories-1-Year-2025-11-22_2026-11-22.md  Audit kalori 1 tahun (322 hari data)
Garmin-Calories-Audit-2026-05-20_2026-11-20.md  Audit kalori harian 6 bulan
Garmin-MCP-Repo-Audit-2026-11-22.md  Audit read-only repo Taxuspt/garmin_mcp (keamanan, CI, rilis)
PACKET-README.md                    Dokumentasi report factory (fetch -> .md untuk LLM eksternal)
Garmin-Packet-2026-11-22.md          Daily analysis packet 22 Nov 2026
Garmin-Weekly-Report-2026-11-16_2026-11-22.md  Laporan mingguan lengkap 16-22 Nov 2026
garmin_packet\                       Package Python report factory
pyproject.toml / uv.lock             Project & lockfile
.venv\                               Virtual environment (uv)
data\                               (kosong; raw JSON dihapus 22 Nov 2026, .md tetap ada)
sessions\24910882666\               FIT + TCX + ringkasan JSON sesi 31 Okt 2026
sessions\24946233617\               FIT + detail API + ringkasan JSON sesi 3 Nov 2026
sessions\25026059313\               FIT + detail API + ringkasan JSON sesi 10 Nov 2026
sessions\25049716533\               FIT + detail API + ringkasan JSON sesi 12 Nov 2026
sessions\25070193425\               FIT + detail API + ringkasan JSON sesi 14 Nov 2026
sessions\25146532544\               FIT + detail API + ringkasan JSON sesi 21 Nov 2026
sessions\25157631151\               FIT + detail API + ringkasan JSON sesi 22 Nov 2026
fit\                                8 ZIP + 8 .FIT + fit-laps.json (128 lap, 19 metrik/lap)
scripts\fetch-garmin-week.ps1       Script tarik data 7 hari
scripts\fetch-hr-history.ps1        Script tarik riwayat HR 1 tahun
scripts\build-hr-report.js          Generator laporan highest heart rate
scripts\download-fit.ps1            Download file .FIT per aktivitas
scripts\parse-fit.js                Parse lap dari .FIT -> fit-laps.json
scripts\aggregate.js                Script agregasi metrik harian
scripts\generate-detail-report.js   Generator laporan detail dari data JSON + FIT
scripts\find-activity-20261103.ps1  Cari aktivitas per tanggal (daftar + simpan JSON)
scripts\fetch-session.ps1           Tarik detail aktivitas + unduh .FIT -> pakai: -Id <activityId>
scripts\fetch-session-24946233617.ps1  Tarik detail + .FIT sesi 3 Nov 2026 (contoh per-id)
scripts\build-session-report-24946233617.js  Generator laporan sesi treadmill 3x9'
scripts\build-session-report-25026059313.js  Generator laporan sesi treadmill 5x5'
scripts\build-session-report-25049716533.js  Generator rekap Over Under Fartlek 35'
scripts\build-session-report-25070193425.js  Generator full audit Bogor 16x600
scripts\fetch-calories-6m.ps1       Tarik daily summaries kalori 6 bulan
scripts\fetch-calories-1y.ps1       Tarik daily summaries + aktivitas kalori 1 tahun
scripts\build-calories-1y.js        Generator audit kalori 1 tahun
scripts\analyze-calories.js         Analisis eksplorasi kalori
scripts\build-calorie-audit.js      Generator laporan audit kalori
scripts\extract-spec.js             Ekstrak OpenAPI spec Garmin
scripts\dump-ops.js                 Dump daftar endpoint + parameter
scripts\node_modules\               Dependency fit-file-parser

JANGAN:
- Commit file ini ke Git / GitHub / cloud sync publik.
- Kirim lewat chat, email, atau screenshot.
- Simpan salinan di folder proyek yang ikut ter-deploy.

CARA PAKAI (PowerShell):
    $env:GARMIN_API_KEY = Get-Content 'D:\Garmin\API-Key-Data-Fetch\garmin-api-key.txt' -Raw
    $env:GARMIN_API_KEY = $env:GARMIN_API_KEY.Trim()

Atau jalankan helper:
    . 'D:\Garmin\API-Key-Data-Fetch\load-key.ps1'

REPORT FACTORY (cara baru, Python):
    cd D:\Garmin\API-Key-Data-Fetch
    uv sync

    # Tarik data harian (Personal API + Intervals; tambah ,connect untuk gap-fill)
    uv run garmin-packet fetch --date 2026-11-22 --sources personal,intervals

    # Buat daily packet .md
    uv run garmin-packet daily --date 2026-11-22 --cutoff "18:11 WIB"

    # Session / weekly / audit
    uv run garmin-packet session --activity-id 25157631151
    uv run garmin-packet weekly --start 2026-11-16 --end 2026-11-22
    uv run garmin-packet audit --start 2026-11-01 --end 2026-11-22

    # MCP read-only (8 tool, tanpa write)
    uv run garmin-packet-mcp

TARIK DATA BARU (cara lama, PowerShell):
    powershell -NoProfile -ExecutionPolicy Bypass -File 'D:\Garmin\API-Key-Data-Fetch\scripts\fetch-garmin-week.ps1'
    # edit $from / $to di script untuk periode lain
    node 'D:\Garmin\API-Key-Data-Fetch\scripts\aggregate.js'

BUAT LAPORAN DETAIL (per hari + per sesi):
    node 'D:\Garmin\API-Key-Data-Fetch\scripts\generate-detail-report.js'

TARIK LAP DARI .FIT:
    powershell -NoProfile -ExecutionPolicy Bypass -File 'D:\Garmin\API-Key-Data-Fetch\scripts\download-fit.ps1'
    node 'D:\Garmin\API-Key-Data-Fetch\scripts\parse-fit.js'
    node 'D:\Garmin\API-Key-Data-Fetch\scripts\generate-detail-report.js'

LAPORAN HIGHEST HEART RATE / KALORI:
    powershell -NoProfile -ExecutionPolicy Bypass -File 'D:\Garmin\API-Key-Data-Fetch\scripts\fetch-hr-history.ps1'
    node 'D:\Garmin\API-Key-Data-Fetch\scripts\build-hr-report.js'
    powershell -NoProfile -ExecutionPolicy Bypass -File 'D:\Garmin\API-Key-Data-Fetch\scripts\fetch-calories-6m.ps1'
    node 'D:\Garmin\API-Key-Data-Fetch\scripts\build-calorie-audit.js'

ANALISIS SESI DARI FILE .FIT/.TCX (manual):
    node 'D:\Garmin\API-Key-Data-Fetch\scripts\build-session-report-24910882666.js'

ANALISIS SESI BARU (tarik via API -> .FIT -> laporan):
    powershell -NoProfile -ExecutionPolicy Bypass -File 'D:\Garmin\API-Key-Data-Fetch\scripts\find-activity-20261103.ps1'   # edit tanggal di dalam script
    powershell -NoProfile -ExecutionPolicy Bypass -File 'D:\Garmin\API-Key-Data-Fetch\scripts\fetch-session.ps1' -Id <activityId>
    node 'D:\Garmin\API-Key-Data-Fetch\scripts\build-session-report-25070193425.js'   # salin & sesuaikan ID untuk sesi baru

Kalau key ini pernah terekspos (chat, repo, log), revoke dan generate
ulang di Garmin Connect Developer Program.
