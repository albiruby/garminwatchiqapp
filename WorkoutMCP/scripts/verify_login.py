"""Verifikasi login + akses workout library (read-only, ringan)."""
import sys

sys.path.insert(0, "src")

from workout_mcp.auth import init_api

client = init_api()
if client is None:
    raise SystemExit("LOGIN GAGAL")

page = client.get_workouts(1, 5)
print(f"LOGIN OK. Workout di library (5 pertama):")
for w in page or []:
    sport = (w.get("sportType") or {}).get("sportTypeKey")
    print(f"  - {w.get('workoutId')} | {w.get('workoutName')} [{sport}]")
