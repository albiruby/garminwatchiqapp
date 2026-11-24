# WorkoutMCP

MCP server khusus **workout Garmin** (buat, lihat, jadwalkan, hapus, kirim ke device).
Baca/tulis via library `python-garminconnect` (unofficial, endpoint privat Garmin).
Laporan sesi `.md` kamu tetap dari Personal API resmi — repo ini hanya untuk workout.

## Tools (12)

Baca: `list_workouts`, `get_workout`, `get_scheduled_workouts`, `get_devices`.
Tulis: `upload_workout`, `delete_workout` (confirm-gate), `schedule_workout`
(idempoten), `unschedule_workout`, `push_workout_to_device`.
Builder: `create_run_interval_workout` (mis 3x9', 5x5', 600m),
`create_walk_run_workout`, `schedule_week`.

## Pasang (Windows)

```powershell
cd D:\Garmin\WorkoutMCP
uv sync
```

## Auth (sekali, dukung MFA)

```powershell
uv run workout-mcp-auth
# token tersimpan di %USERPROFILE%\.workout-mcp-tokens (±6 bulan)
```

## Coba tanpa login (smoke test, offline)

```powershell
uv run python scripts\smoke_test.py
```

## Pakai di OpenCode

`~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "workout": {
      "type": "local",
      "command": ["uv", "--directory", "D:\\Garmin\\WorkoutMCP", "run", "workout-mcp"],
      "enabled": true,
      "timeout": 30000
    }
  }
}
```

Claude Desktop (`%APPDATA%\Claude\claude_desktop_config.json`): sama, tanpa
kredensial di config (server pakai token tersimpan).

## Catatan

- Pace target pakai m/s (5:00/km = 3,333). HR zone pakai `zoneNumber` 1-5.
- Upload divalidasi lokal dulu (ID/key endCondition & targetType); ditolak
  sebelum terkirim kalau tidak cocok dengan mapping Garmin.
- `schedule_workout` idempoten (tidak duplikat). `delete_workout` butuh
  `confirm=true`. Push masuk watch saat sync berikutnya, bukan instan.
- Endpoint unofficial: bisa berubah sewaktu-waktu; jangan untuk akun kritikal
  tanpa cadangan.
