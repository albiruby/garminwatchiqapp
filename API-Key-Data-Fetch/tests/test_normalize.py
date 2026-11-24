from pathlib import Path

from garmin_packet.normalize import load_bundle, normalize_bundle


def test_daily_bundle_normalizes_existing_fixture():
    bundle = load_bundle("2026-11-22")
    n = normalize_bundle(bundle)

    assert n["date"] == "2026-11-22"
    assert n["summary"]["sleep_s"] == 28740
    assert n["summary"]["resting_hr"] == 45
    assert n["summary"]["steps"] == 20416
    assert n["summary"]["max_hr"] == 143
    assert n["summary"]["weight_kg"] == 55.7
    assert round(n["summary"]["ctl"], 2) == 43.34
    assert round(n["summary"]["atl"], 2) == 59.20
    assert round(n["summary"]["tsb"], 2) == -15.86
    assert n["sleep"]["score"] == 85
    assert n["sleep"]["start"] == "2026-11-21 21:14"
    assert n["sleep"]["end"] == "2026-11-22 05:30"
    assert n["hrv"]["last_night_avg"] == 85
    assert n["hrv"]["status"] == "BALANCED"
    assert len(n["history_baseline"]) >= 2


def test_activity_and_session_are_joined():
    bundle = load_bundle("2026-11-22", activity_id=25157631151)
    n = normalize_bundle(bundle)
    assert len(n["activities"]) == 1
    activity = n["activities"][0]
    assert activity["activity_id"] == 25157631151
    assert round(activity["distance_m"], 1) == 20182.3
    assert activity["avg_hr"] == 135
    assert activity["max_hr"] == 146
    assert len(activity["laps"]) == 21
    assert activity["zones_hr_bounds"] == [125, 143, 161, 175, 192, 208]


def test_partial_day_is_flagged():
    n = normalize_bundle(load_bundle("2026-11-22"))
    assert n["coverage"]["partial_day"] is True
    assert n["coverage"]["data_end"].startswith("2026-11-22 17:13")
