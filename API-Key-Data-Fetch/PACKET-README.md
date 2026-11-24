# Garmin Packet — Report Factory

Folder ini sekarang punya **report factory** untuk membuat paket analisis `.md` yang self-contained, siap diberikan ke ChatGPT/Gemini/LLM lain.

## Flow

```text
Garmin Personal API ─┐
Intervals.icu ───────┼→ fetch → data/daily-YYYY-MM-DD/*.json
Garmin Connect ──────┘              ↓
                              normalize + merge
                                    ↓
                        Garmin-Packet-YYYY-MM-DD.md
                                    ↓
                         ChatGPT / Gemini / LLM lain
```

Tidak ada database, tidak ada cache TTL, tidak ada analisis otomatis di sini. Analisis dilakukan LLM eksternal.

## Instalasi

```powershell
cd D:\Garmin\API-Key-Data-Fetch
uv sync
```

## Kredensial

### Garmin Personal API
Sudah ada di `garmin-api-key.txt`. Bisa juga lewat env:

```powershell
$env:GARMIN_API_KEY = "..."
```

### Intervals.icu
Buat file `.env` di folder ini (jangan commit):

```env
INTERVALS_API_KEY=...
INTERVALS_ATHLETE_ID=0
```

Atau set env langsung. Kode **tidak** membaca `D:\Garmin\WorkoutMCP\.env`; semua tetap di folder ini.

### Garmin Connect gap-fill (opsional)
Diperlukan untuk weight/body composition, training readiness/status, fitness age, respiration detail, FTP/lactate, race predictions, PR, nutrition, gear.

Default token dir: `D:\Garmin\API-Key-Data-Fetch\.garmin-tokens`.

```powershell
$env:GARMINTOKENS = "D:\Garmin\API-Key-Data-Fetch\.garmin-tokens"
```

Kalau belum ada token, jalankan auth dari WorkoutMCP atau salin token yang sudah ada **ke folder ini**. Tanpa token, bagian gap-fill akan ditandai `unavailable`, bukan gagal total.

## Perintah

```powershell
# Tarik data (Personal API + Intervals)
uv run garmin-packet fetch --date 2026-11-22 --sources personal,intervals

# Tarik + gap-fill Garmin Connect
uv run garmin-packet fetch --date 2026-11-22 --sources personal,intervals,connect

# Daily packet
uv run garmin-packet daily --date 2026-11-22 --cutoff "18:11 WIB"

# Session packet
uv run garmin-packet session --activity-id 25157631151

# Weekly packet
uv run garmin-packet weekly --start 2026-11-16 --end 2026-11-22

# Audit data
uv run garmin-packet audit --start 2026-11-01 --end 2026-11-22

# Fetch + daily sekaligus
uv run garmin-packet all --date 2026-11-22 --sources personal,intervals
```

Output:

- `Garmin-Packet-YYYY-MM-DD.md`
- `Garmin-Packet-Session-{activity_id}.md`
- `Garmin-Packet-Weekly-{start}_{end}.md`
- `Garmin-Packet-Audit-{start}_{end}.md`

## MCP read-only

```powershell
uv run garmin-packet-mcp
```

Tool yang tersedia:

- `fetch_data`
- `generate_daily_packet`
- `generate_session_packet`
- `generate_weekly_report`
- `generate_audit_packet`
- `list_packets`
- `read_packet`
- `get_source_status`

Tidak ada tool write. Workout write tetap di WorkoutMCP.

Contoh konfigurasi opencode:

```json
{
  "mcp": {
    "servers": {
      "garmin-packet": {
        "type": "local",
        "command": ["uv", "--directory", "D:\\Garmin\\API-Key-Data-Fetch", "run", "garmin-packet-mcp"],
        "enabled": true,
        "timeout": 120000
      }
    }
  }
}
```

## Isi daily packet

1. Ringkasan data
2. Tidur (stages, score, need, nap)
3. Heart rate & HRV (hourly, zones, baseline)
4. Stres & Body Battery (events + series)
5. SpO₂ & pernapasan (hourly)
6. Training load & recovery (Intervals + Garmin Connect)
7. Aktivitas + laps + zones + decoupling + cross-check vs daily summary + environment
8. Body composition & berat (Garmin Connect / Personal API / Intervals)
9. Nutrisi & hidrasi
10. Baseline 7 hari (Intervals) + 28/90 hari (Garmin history)
11. Data quality & conflicts
12. Definitions
13. Analysis request untuk LLM
14. Lampiran file

## Test

```powershell
uv run pytest -q
```

## Redaksi

`--redact` menghapus nama atlet dan nama aktivitas (menggantinya dengan tipe aktivitas). Ini bukan jaminan anonim penuh; cek manual sebelum dibagikan.

## Keamanan & privasi

- Laporan **tidak** memuat API key/token.
- `garmin-api-key.txt`, `.env`, dan `.garmin-tokens/` tidak boleh dibagikan.
- Data kesehatan tetap sensitif; gunakan temporary chat / matikan training data saat upload ke LLM eksternal.
- `--redact` menghapus nama atlet dari header, tapi tidak menghapus semua metadata. Cek manual sebelum dibagikan.
- `garminconnect` adalah API tidak resmi dan memakai token akun penuh; wrapper read-only hanya mengizinkan method GET yang di-allowlist.

## Batasan

- Garmin Personal API tidak menyediakan weight, training readiness/status, fitness age, respiration detail (404 pada akun ini). Gap-fill butuh token Garmin Connect.
- Intervals.icu adalah data turunan; bukan ground truth.
- Kalori, sleep staging, SpO₂, dan Body Battery adalah estimasi perangkat.
- Daily packet bisa parsial jika sync terakhir belum mencapai cutoff.
