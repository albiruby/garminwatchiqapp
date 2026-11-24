"""Load raw source files and turn them into a normalized, report-friendly bundle."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date as date_cls, datetime, timedelta
from functools import lru_cache
from pathlib import Path
from typing import Any

from . import config
from .util import (
    WIB,
    dig,
    fmt_date_local,
    fmt_iso_local,
    load_json,
    num,
    safe_pct,
)


def _first(value: Any) -> Any:
    if isinstance(value, dict):
        for key in ("value", "data", "values", "hrvSummaries"):
            nested = value.get(key)
            if isinstance(nested, list) and nested:
                return nested[0]
    if isinstance(value, list) and value:
        return value[0]
    return None


def _pick(*values: Any) -> Any:
    for value in values:
        if value is not None and value != "":
            return value
    return None


@dataclass
class Bundle:
    date: str
    out_dir: Path
    daily_v2: dict[str, Any] | None = None
    legacy: dict[str, Any] | None = None
    sleep: dict[str, Any] | None = None
    heart_rate: dict[str, Any] | None = None
    body_battery: dict[str, Any] | None = None
    hrv: dict[str, Any] | None = None
    spo2: dict[str, Any] | None = None
    stress: dict[str, Any] | None = None
    steps: dict[str, Any] | None = None
    hydration: dict[str, Any] | None = None
    activities_raw: list[dict[str, Any]] = field(default_factory=list)
    hr_zones: dict[str, Any] | None = None
    user_settings: dict[str, Any] | None = None
    respiration: dict[str, Any] | None = None
    weight: dict[str, Any] | None = None
    personal_fitness_age: dict[str, Any] | None = None
    intervals: dict[str, Any] | None = None
    intervals_7d: list[dict[str, Any]] = field(default_factory=list)
    intervals_activities: list[dict[str, Any]] = field(default_factory=list)
    connect: dict[str, Any] = field(default_factory=dict)
    session: dict[str, Any] | None = None
    fetch_status: dict[str, Any] | None = None
    missing_files: list[str] = field(default_factory=list)


def load_bundle(day: str, activity_id: int | None = None) -> Bundle:
    out_dir = config.DATA_DIR / f"daily-{day}"
    bundle = Bundle(date=day, out_dir=out_dir)

    def get(name: str) -> Any:
        path = out_dir / f"{name}.json"
        if not path.exists():
            bundle.missing_files.append(name)
            return None
        return load_json(path)

    bundle.daily_v2 = get("daily-v2")
    bundle.legacy = get("daily-legacy")
    bundle.sleep = get("sleep")
    bundle.heart_rate = get("heart-rate")
    bundle.body_battery = get("body-battery")
    bundle.hrv = get("hrv")
    bundle.spo2 = get("spo2")
    bundle.stress = get("stress")
    bundle.steps = get("steps")
    bundle.hydration = get("hydration")
    bundle.hr_zones = get("hr-zones")
    bundle.user_settings = get("user-settings")
    bundle.respiration = get("respiration")
    bundle.weight = get("weight")
    bundle.personal_fitness_age = get("fitness-age")
    bundle.fetch_status = get("fetch-status")

    activities = get("activities")
    if isinstance(activities, dict):
        bundle.activities_raw = [a for a in (activities.get("value") or []) if isinstance(a, dict)]
    elif isinstance(activities, list):
        bundle.activities_raw = [a for a in activities if isinstance(a, dict)]

    intervals = get("intervals-wellness")
    if isinstance(intervals, list) and intervals:
        bundle.intervals = intervals[0] if isinstance(intervals[0], dict) else None
    elif isinstance(intervals, dict):
        bundle.intervals = intervals
    intervals_7d = get("intervals-wellness-7d")
    if isinstance(intervals_7d, list):
        bundle.intervals_7d = [x for x in intervals_7d if isinstance(x, dict)]
    intervals_activities = get("intervals-activities")
    if isinstance(intervals_activities, list):
        bundle.intervals_activities = [x for x in intervals_activities if isinstance(x, dict)]

    connect_dir = out_dir / "garmin-connect"
    if connect_dir.exists():
        for path in sorted(connect_dir.glob("*.json")):
            bundle.connect[path.stem] = load_json(path)

    if activity_id is None and bundle.activities_raw:
        try:
            activity_id = int(bundle.activities_raw[0].get("activityId"))
        except (TypeError, ValueError):
            activity_id = None
    if activity_id is not None:
        session_path = config.BASE_DIR / "sessions" / str(activity_id) / f"session-{activity_id}.json"
        if session_path.exists():
            bundle.session = load_json(session_path)

    return bundle


def _v2(bundle: Bundle) -> dict[str, Any]:
    if not isinstance(bundle.daily_v2, dict):
        return {}
    data = bundle.daily_v2.get("data")
    if isinstance(data, list) and data and isinstance(data[0], dict):
        return data[0]
    return {}


def _sleep(bundle: Bundle) -> dict[str, Any]:
    return _first(bundle.sleep) or {}


def _stress(bundle: Bundle) -> dict[str, Any]:
    return _first(bundle.stress) or {}


def _steps(bundle: Bundle) -> dict[str, Any]:
    return _first(bundle.steps) or {}


def _bb(bundle: Bundle) -> dict[str, Any]:
    return _first(bundle.body_battery) or {}


def _hrv(bundle: Bundle) -> dict[str, Any]:
    return _first(bundle.hrv) or {}


def _hr_zones(bundle: Bundle) -> dict[str, Any]:
    return _first(bundle.hr_zones) or {}


def _heart_rate(bundle: Bundle) -> dict[str, Any]:
    return bundle.heart_rate if isinstance(bundle.heart_rate, dict) else {}


def _legacy(bundle: Bundle) -> dict[str, Any]:
    return bundle.legacy if isinstance(bundle.legacy, dict) else {}


def _intervals(bundle: Bundle) -> dict[str, Any]:
    return bundle.intervals if isinstance(bundle.intervals, dict) else {}


def _interval_value(bundle: Bundle, key: str) -> Any:
    return _intervals(bundle).get(key)


def _connect(bundle: Bundle, name: str) -> Any:
    return bundle.connect.get(name)


def _connect_value(bundle: Bundle, name: str, *keys: str) -> Any:
    return dig(_connect(bundle, name), *keys)


def _body_composition(bundle: Bundle) -> dict[str, Any]:
    raw = _connect(bundle, "body-composition")
    if isinstance(raw, dict):
        items = raw.get("dateWeightList") or raw.get("bodyCompositionList") or []
        if items and isinstance(items[0], dict):
            item = dict(items[0])
            item["_source"] = "Garmin Connect"
            return item
        if raw.get("weight") is not None:
            item = dict(raw)
            item["_source"] = "Garmin Connect"
            return item
    raw = _connect(bundle, "weigh-ins")
    if isinstance(raw, dict):
        items = raw.get("dateWeightList") or []
        if items and isinstance(items[0], dict):
            item = dict(items[0])
            item["_source"] = "Garmin Connect"
            return item
    # Official Personal API weight endpoint (works on dates with a weigh-in).
    raw = bundle.weight
    if isinstance(raw, dict):
        summaries = raw.get("dailyWeightSummaries") or []
        if summaries and isinstance(summaries[0], dict):
            latest = summaries[0].get("latestWeight") or {}
            if isinstance(latest, dict) and latest:
                item = dict(latest)
                item["_source"] = "Garmin Personal API"
                return item
    return {}


def _readiness(bundle: Bundle) -> dict[str, Any]:
    raw = _connect(bundle, "training-readiness")
    if isinstance(raw, list) and raw:
        return raw[0] if isinstance(raw[0], dict) else {}
    if isinstance(raw, dict):
        return raw
    return {}


def _training_status(bundle: Bundle) -> dict[str, Any]:
    raw = _connect(bundle, "training-status")
    if isinstance(raw, list) and raw:
        return raw[0] if isinstance(raw[0], dict) else {}
    if isinstance(raw, dict):
        return raw
    return {}


def _fitness_age(bundle: Bundle) -> dict[str, Any]:
    raw = _connect(bundle, "fitness-age")
    if isinstance(raw, list) and raw:
        return raw[0] if isinstance(raw[0], dict) else {}
    if isinstance(raw, dict):
        return raw
    raw = bundle.personal_fitness_age
    if isinstance(raw, dict):
        return raw
    return {}


def _respiration_detail(bundle: Bundle) -> dict[str, Any]:
    raw = _connect(bundle, "respiration")
    if isinstance(raw, dict):
        return raw
    if isinstance(raw, list) and raw:
        return raw[0] if isinstance(raw[0], dict) else {}
    return {}


def _hr_bounds(bundle: Bundle) -> tuple[list[int], int | None]:
    zones = _hr_zones(bundle)
    floors = [
        zones.get("zone1Floor"),
        zones.get("zone2Floor"),
        zones.get("zone3Floor"),
        zones.get("zone4Floor"),
        zones.get("zone5Floor"),
    ]
    bounds = [int(x) for x in floors if isinstance(x, (int, float))]
    max_hr = zones.get("maxHeartRateUsed")
    return (bounds if len(bounds) == 5 else [125, 143, 161, 175, 192],
            int(max_hr) if isinstance(max_hr, (int, float)) else None)


def _hr_series(bundle: Bundle) -> list[tuple[int, int]]:
    values = _heart_rate(bundle).get("heartRateValues") or []
    out: list[tuple[int, int]] = []
    for item in values:
        if isinstance(item, list) and len(item) >= 2:
            ts, value = item[0], num(item[1])
            if ts is not None and value is not None and value > 0:
                out.append((int(ts), int(value)))
    return out


def _hourly_hr(samples: list[tuple[int, int]]) -> list[dict[str, Any]]:
    buckets: dict[int, list[int]] = {}
    for ts, value in samples:
        hour = datetime.fromtimestamp(ts / 1000.0, tz=WIB).hour
        buckets.setdefault(hour, []).append(value)
    rows = []
    for hour in sorted(buckets):
        vals = buckets[hour]
        rows.append({
            "hour": f"{hour:02d}:00",
            "samples": len(vals),
            "avg": sum(vals) / len(vals),
            "min": min(vals),
            "max": max(vals),
        })
    return rows


def _zone_times(samples: list[tuple[int, int]], bounds: list[int]) -> list[float]:
    zones = [0.0] * 6  # below, z1..z4, z5+
    for index, (ts, value) in enumerate(samples):
        if index + 1 < len(samples):
            dt = (samples[index + 1][0] - ts) / 1000.0
        else:
            dt = 60.0
        dt = max(0.0, min(dt, 180.0))
        zone = 0
        while zone < 5 and value >= bounds[zone]:
            zone += 1
        zones[zone] += dt
    return zones


def _normalize_sleep(bundle: Bundle) -> dict[str, Any]:
    sleep = _sleep(bundle)
    if not sleep:
        return {}
    sleep_s = num(sleep.get("sleepTimeSeconds")) or 0
    awake_s = num(sleep.get("awakeSleepSeconds")) or 0
    deep_s = num(sleep.get("deepSleepSeconds")) or 0
    light_s = num(sleep.get("lightSleepSeconds")) or 0
    rem_s = num(sleep.get("remSleepSeconds")) or 0
    total_stage = deep_s + light_s + rem_s
    score = dig(sleep, "sleepScores", "overall", "value")
    need = sleep.get("sleepNeed") or {}
    next_need = sleep.get("nextSleepNeed") or {}
    naps = sleep.get("dailyNapDTOS") or []
    nap_s = num(sleep.get("napTimeSeconds")) or 0
    return {
        "start": fmt_date_local(sleep.get("sleepStartTimestampGMT") or sleep.get("sleepStartTimestampLocal")),
        "end": fmt_date_local(sleep.get("sleepEndTimestampGMT") or sleep.get("sleepEndTimestampLocal")),
        "sleep_s": sleep_s,
        "awake_s": awake_s,
        "deep_s": deep_s,
        "light_s": light_s,
        "rem_s": rem_s,
        "total_stage_s": total_stage,
        "efficiency": safe_pct(sleep_s, sleep_s + awake_s),
        "score": score,
        "score_qualifier": dig(sleep, "sleepScores", "overall", "qualifierKey"),
        "feedback": sleep.get("sleepScoreFeedback"),
        "insight": sleep.get("sleepScorePersonalizedInsight") or sleep.get("sleepScoreInsight"),
        "awake_count": sleep.get("awakeCount"),
        "avg_hr": sleep.get("avgHeartRate"),
        "avg_spo2": sleep.get("averageSpO2Value"),
        "lowest_spo2": sleep.get("lowestSpO2Value"),
        "avg_respiration": sleep.get("averageRespirationValue"),
        "lowest_respiration": sleep.get("lowestRespirationValue"),
        "highest_respiration": sleep.get("highestRespirationValue"),
        "avg_stress": sleep.get("avgSleepStress"),
        "breathing_disruption": sleep.get("breathingDisruptionSeverity"),
        "need_baseline_min": need.get("baseline"),
        "need_actual_min": need.get("actual"),
        "need_feedback": need.get("feedback"),
        "next_need_baseline_min": next_need.get("baseline"),
        "next_need_actual_min": next_need.get("actual"),
        "next_need_feedback": next_need.get("feedback"),
        "nap_s": nap_s,
        "naps": [
            {
                "seconds": n.get("napTimeSec"),
                "start_utc": n.get("napStartTimestampGMT"),
                "end_utc": n.get("napEndTimestampGMT"),
                "feedback": n.get("napFeedback"),
            }
            for n in naps if isinstance(n, dict)
        ],
        "deep_pct": safe_pct(deep_s, total_stage),
        "light_pct": safe_pct(light_s, total_stage),
        "rem_pct": safe_pct(rem_s, total_stage),
        "awake_pct": safe_pct(awake_s, total_stage + awake_s),
    }


def _normalize_stress(bundle: Bundle) -> dict[str, Any]:
    v2 = _v2(bundle).get("stress") or {}
    raw = _stress(bundle).get("values") or {}
    # daily-v2 stress durations are milliseconds; stress endpoint is seconds.
    def sec(value: Any, source: str = "v2") -> float | None:
        n = num(value)
        if n is None:
            return None
        return n / 1000.0 if source == "v2" else n

    return {
        "avg": _pick(v2.get("avgLevel"), raw.get("overallStressLevel")),
        "max": _pick(v2.get("maxLevel"), _legacy(bundle).get("maxStressLevel")),
        "qualifier": _pick(v2.get("qualifier"), _legacy(bundle).get("stressQualifier")),
        "rest_s": _pick(sec(v2.get("restDurationInMillis")), sec(raw.get("restStressDuration"), "raw")),
        "activity_s": _pick(sec(v2.get("activityDurationInMillis")), sec(raw.get("activityStressDuration"), "raw")),
        "low_s": _pick(sec(v2.get("lowStressDurationInMillis")), sec(raw.get("lowStressDuration"), "raw")),
        "medium_s": _pick(sec(v2.get("mediumStressDurationInMillis")), sec(raw.get("mediumStressDuration"), "raw")),
        "high_s": _pick(sec(v2.get("highStressDurationInMillis")), sec(raw.get("highStressDuration"), "raw")),
        "uncategorized_s": sec(v2.get("uncategorizedDurationInMillis")),
        "total_s": sec(v2.get("totalDurationInMillis")),
    }


def _normalize_bb(bundle: Bundle) -> dict[str, Any]:
    v2 = _v2(bundle).get("bodyBattery") or {}
    raw = _bb(bundle)
    series = raw.get("bodyBatteryValuesArray") or []
    events = raw.get("bodyBatteryActivityEvent") or v2.get("activityEvents") or []
    return {
        "min": _pick(v2.get("minValue"), _legacy(bundle).get("bodyBatteryLowestValue")),
        "max": _pick(v2.get("maxValue"), _legacy(bundle).get("bodyBatteryHighestValue")),
        "latest": _pick(v2.get("latestValue"), _legacy(bundle).get("bodyBatteryMostRecentValue")),
        "charged": _pick(v2.get("chargedValue"), raw.get("charged")),
        "drained": _pick(v2.get("drainedValue"), raw.get("drained")),
        "during_sleep": _legacy(bundle).get("bodyBatteryDuringSleep"),
        "at_wake": _legacy(bundle).get("bodyBatteryAtWakeTime"),
        "series": series,
        "events": events,
        "dynamic_feedback": v2.get("dynamicFeedbackEvent") or raw.get("bodyBatteryDynamicFeedbackEvent"),
    }


def _normalize_spo2(bundle: Bundle) -> dict[str, Any]:
    v2 = _v2(bundle).get("pulseOx") or {}
    raw = bundle.spo2 if isinstance(bundle.spo2, dict) else {}
    hourly = raw.get("spO2HourlyAverages") or []
    return {
        "avg": _pick(v2.get("avgValue"), raw.get("averageSpO2"), _legacy(bundle).get("averageSpo2")),
        "min": _pick(v2.get("minValue"), raw.get("lowestSpO2"), _legacy(bundle).get("lowestSpo2")),
        "latest": _pick(v2.get("latestValue"), raw.get("latestSpO2"), _legacy(bundle).get("latestSpo2")),
        "latest_time": _pick(v2.get("latestTimestampLocal"), raw.get("latestSpO2TimestampLocal")),
        "sleep_avg": raw.get("avgSleepSpO2"),
        "seven_day_avg": raw.get("lastSevenDaysAvgSpO2"),
        "hourly": hourly,
    }


def _normalize_respiration(bundle: Bundle) -> dict[str, Any]:
    v2 = _v2(bundle).get("respiration") or {}
    sleep = _sleep(bundle)
    detail = _respiration_detail(bundle)
    return {
        "avg": _pick(v2.get("avgValue"), _legacy(bundle).get("avgWakingRespirationValue"), detail.get("avgValue")),
        "min": _pick(v2.get("minValue"), _legacy(bundle).get("lowestRespirationValue"), detail.get("minValue")),
        "max": _pick(v2.get("maxValue"), _legacy(bundle).get("highestRespirationValue"), detail.get("maxValue")),
        "latest": _pick(v2.get("latestValue"), _legacy(bundle).get("latestRespirationValue")),
        "latest_time": v2.get("latestTimestampGmt"),
        "sleep_avg": sleep.get("averageRespirationValue"),
        "sleep_min": sleep.get("lowestRespirationValue"),
        "sleep_max": sleep.get("highestRespirationValue"),
        "detail": detail,
    }


def _normalize_steps(bundle: Bundle) -> dict[str, Any]:
    v2 = _v2(bundle).get("movement") or {}
    raw = _steps(bundle)
    legacy = _legacy(bundle)
    return {
        "total": _pick(raw.get("totalSteps"), dig(v2, "steps", "value"), legacy.get("totalSteps")),
        "distance_m": _pick(raw.get("totalDistance"), dig(v2, "steps", "distanceInMeters"), legacy.get("totalDistanceMeters")),
        "goal": _pick(raw.get("stepGoal"), dig(v2, "steps", "goal"), legacy.get("dailyStepGoal")),
        "floors_up": _pick(dig(v2, "floorsAscended", "value"), legacy.get("floorsAscended")),
        "floors_down": _pick(dig(v2, "floorsDescended", "value"), legacy.get("floorsDescended")),
        "intensity_moderate": dig(v2, "intensityMinutes", "moderate") or legacy.get("moderateIntensityMinutes"),
        "intensity_vigorous": dig(v2, "intensityMinutes", "vigorous") or legacy.get("vigorousIntensityMinutes"),
        "intensity_goal": dig(v2, "intensityMinutes", "goal") or legacy.get("intensityMinutesGoal"),
    }


def _normalize_hydration(bundle: Bundle) -> dict[str, Any]:
    v2 = _v2(bundle).get("hydration") or {}
    raw = bundle.hydration if isinstance(bundle.hydration, dict) else {}
    return {
        "consumed_ml": _pick(v2.get("consumedInMl"), raw.get("value")),
        "goal_ml": _pick(v2.get("goalInMl"), raw.get("goal")),
    }


def _normalize_laps(session: dict[str, Any] | None) -> list[dict[str, Any]]:
    """Normalize the two lap shapes used by the existing session JSON files."""
    out: list[dict[str, Any]] = []
    for index, lap in enumerate((session or {}).get("laps") or [], 1):
        if not isinstance(lap, dict):
            continue
        dist = num(lap.get("dist"))
        timer = num(lap.get("timer"))
        pace = num(lap.get("pace"))
        if pace is None and dist and timer and dist > 50:
            pace = timer / (dist / 1000.0)
        out.append({
            "n": lap.get("n") or lap.get("i") or index,
            "dist": dist,
            "timer": timer,
            "pace": pace,
            "hr": num(lap.get("hr")),
            "hrMax": num(lap.get("hrMax")),
            "power": num(lap.get("power")) if lap.get("power") is not None else num(lap.get("pw")),
            "powerMax": num(lap.get("powerMax")) if lap.get("powerMax") is not None else num(lap.get("pwMax")),
            "cadence": num(lap.get("cadence")) if lap.get("cadence") is not None else num(lap.get("cad")),
            "kind": lap.get("kind") or lap.get("trigger") or "",
            "vo": num(lap.get("vo")),
            "gct": num(lap.get("gct")),
            "step": num(lap.get("step")),
            "vr": num(lap.get("vr")),
        })
    return out


def _lap_avg(laps: list[dict[str, Any]], key: str) -> float | None:
    values = [lap[key] for lap in laps if lap.get(key) is not None]
    return sum(values) / len(values) if values else None


def _normalize_activity(activity: dict[str, Any], bundle: Bundle) -> dict[str, Any]:
    distance = num(activity.get("distance")) or 0.0
    duration = num(activity.get("duration")) or 0.0
    pace = (duration / (distance / 1000.0)) if distance > 0 else None
    session = bundle.session if bundle.session and int(bundle.session.get("activityId", 0) or 0) == int(activity.get("activityId", 0) or 0) else None
    zones_hr = activity.get("hrTimeInZone_1")
    zones_power = activity.get("powerTimeInZone_1")
    if session:
        zones_hr = session.get("zonesHr")
        zones_power = session.get("zonesPower")
    laps = _normalize_laps(session)
    # Some devices write lap cadence in cycles/min (one foot) while the
    # activity summary uses steps/min. Align the lap table to spm.
    activity_cadence = num(activity.get("averageRunningCadenceInStepsPerMinute"))
    if activity_cadence and activity_cadence > 120:
        for lap in laps:
            cadence = num(lap.get("cadence"))
            if cadence is not None and 0 < cadence < 110:
                lap["cadence"] = cadence * 2
    moving = num(activity.get("movingDuration")) or num((session or {}).get("movingSec"))
    avg_speed = num(activity.get("averageSpeed"))
    if avg_speed is None and distance > 0 and duration > 0:
        avg_speed = distance / duration
    max_power = num(activity.get("maxPower"))
    if max_power is None and laps:
        lap_max = [lap["powerMax"] for lap in laps if lap.get("powerMax") is not None]
        max_power = max(lap_max) if lap_max else None
    aerobic_te = num(activity.get("aerobicTrainingEffect"))
    if aerobic_te is None:
        aerobic_te = num((session or {}).get("te"))
    anaerobic_te = num(activity.get("anaerobicTrainingEffect"))
    if anaerobic_te is None:
        anaerobic_te = num((session or {}).get("anaerobicTE"))
    return {
        "activity_id": activity.get("activityId"),
        "name": activity.get("activityName"),
        "type": dig(activity, "activityType", "typeKey"),
        "start_local": activity.get("startTimeLocal"),
        "start_gmt": activity.get("startTimeGMT"),
        "distance_m": distance,
        "duration_s": duration,
        "moving_s": moving,
        "elapsed_s": num(activity.get("elapsedDuration")),
        "pace_s_per_km": pace,
        "avg_speed_mps": avg_speed,
        "max_speed_mps": num(activity.get("maxSpeed")),
        "calories": num(activity.get("calories")),
        "avg_hr": num(activity.get("averageHR")),
        "max_hr": num(activity.get("maxHR")),
        "avg_cadence": num(activity.get("averageRunningCadenceInStepsPerMinute")) or _lap_avg(laps, "cadence"),
        "max_cadence": num(activity.get("maxRunningCadenceInStepsPerMinute")),
        "avg_power": num(activity.get("avgPower")),
        "max_power": max_power,
        "np": num(activity.get("normPower")),
        "aerobic_te": aerobic_te,
        "anaerobic_te": anaerobic_te,
        "te_label": activity.get("trainingEffectLabel"),
        "te_message": activity.get("aerobicTrainingEffectMessage"),
        "stride_cm": num(activity.get("avgStrideLength")) or _lap_avg(laps, "step"),
        "vertical_oscillation_cm": num(activity.get("avgVerticalOscillation")) or _lap_avg(laps, "vo"),
        "ground_contact_ms": num(activity.get("avgGroundContactTime")) or _lap_avg(laps, "gct"),
        "vertical_ratio_pct": num(activity.get("avgVerticalRatio")) or _lap_avg(laps, "vr"),
        "min_temp_c": num(activity.get("minTemperature")),
        "max_temp_c": num(activity.get("maxTemperature")),
        "steps": num(activity.get("steps")),
        "lap_count": activity.get("lapCount") or len(laps),
        "water_estimated_ml": num(activity.get("waterEstimated")),
        "body_battery_delta": num(activity.get("differenceBodyBattery")),
        "moderate_intensity_min": num(activity.get("moderateIntensityMinutes")),
        "vigorous_intensity_min": num(activity.get("vigorousIntensityMinutes")),
        "rpe": num(activity.get("perceivedEffort") or activity.get("rpe")),
        "feel": activity.get("feel") or activity.get("feeling"),
        "zones_hr": zones_hr,
        "zones_power": zones_power,
        "zones_hr_bounds": (session or {}).get("zonesHrBounds"),
        "zones_power_bounds": (session or {}).get("zonesPowerBounds"),
        "laps": laps,
        "session": session or {},
    }


def _normalize_activities(bundle: Bundle) -> list[dict[str, Any]]:
    return [_normalize_activity(a, bundle) for a in bundle.activities_raw]


def _normalize_intervals(bundle: Bundle) -> dict[str, Any]:
    intervals = _intervals(bundle)
    if not intervals:
        return {}
    ctl = num(intervals.get("ctl"))
    atl = num(intervals.get("atl"))
    sport_info = intervals.get("sportInfo") or []
    run = next((s for s in sport_info if isinstance(s, dict) and s.get("type") == "Run"), {})
    ride = next((s for s in sport_info if isinstance(s, dict) and s.get("type") == "Ride"), {})
    return {
        "id": intervals.get("id"),
        "ctl": ctl,
        "atl": atl,
        "tsb": (ctl - atl) if ctl is not None and atl is not None else None,
        "ramp": num(intervals.get("rampRate")),
        "ctl_load": num(intervals.get("ctlLoad")),
        "atl_load": num(intervals.get("atlLoad")),
        "weight_kg": num(intervals.get("weight")),
        "resting_hr": intervals.get("restingHR"),
        "hrv": num(intervals.get("hrv")),
        "sleep_s": num(intervals.get("sleepSecs")),
        "sleep_score": num(intervals.get("sleepScore")),
        "sleep_quality": intervals.get("sleepQuality"),
        "steps": intervals.get("steps"),
        "floors": intervals.get("floorsClimbed"),
        "spo2": num(intervals.get("spO2")),
        "eftp_run": num(run.get("eftp")),
        "eftp_ride": num(ride.get("eftp")),
        "ramp_rate": num(intervals.get("rampRate")),
        "updated": intervals.get("updated"),
    }


def _normalize_connect(bundle: Bundle) -> dict[str, Any]:
    body = _body_composition(bundle)
    readiness = _readiness(bundle)
    training = _training_status(bundle)
    fitness = _fitness_age(bundle)
    respiration = _respiration_detail(bundle)
    return {
        "body_composition": {
            "date": body.get("calendarDate"),
            "weight_kg": (num(body.get("weight")) / 1000.0) if num(body.get("weight")) is not None else None,
            "weight_source": body.get("_source"),
            "fat_pct": num(body.get("bodyFat")),
            "muscle_kg": (num(body.get("muscleMass")) / 1000.0) if num(body.get("muscleMass")) is not None else None,
            "bone_kg": (num(body.get("boneMass")) / 1000.0) if num(body.get("boneMass")) is not None else None,
            "hydration_pct": num(body.get("bodyWater")),
            "visceral": num(body.get("visceralFat")),
            "bmi": num(body.get("bmi")),
            "raw": body,
        },
        "readiness": readiness,
        "training_status": training,
        "fitness_age": fitness,
        "fitness_age_source": (
            "Garmin Connect" if _connect(bundle, "fitness-age")
            else "Garmin Personal API" if bundle.personal_fitness_age
            else "—"
        ),
        "respiration_detail": respiration,
        "training_load_trend": _connect(bundle, "training-load-trend"),
        "lactate_threshold": _connect(bundle, "lactate-threshold"),
        "cycling_ftp": _connect(bundle, "cycling-ftp"),
        "race_predictions": _connect(bundle, "race-predictions"),
        "personal_records": _connect(bundle, "personal-records"),
        "gear": _connect(bundle, "gear"),
        "devices": _connect(bundle, "devices"),
        "nutrition_food_log": _connect(bundle, "nutrition-food-log"),
        "nutrition_meals": _connect(bundle, "nutrition-meals"),
    }


def _conflict(metric: str, a: Any, b: Any, unit: str, threshold: float) -> dict[str, Any] | None:
    na, nb = num(a), num(b)
    if na is None or nb is None:
        return None
    delta = abs(na - nb)
    if delta <= threshold:
        return None
    return {
        "metric": metric,
        "a": na,
        "b": nb,
        "delta": delta,
        "unit": unit,
        "threshold": threshold,
        "severity": "high" if delta > threshold * 2 else "medium",
    }


def _conflicts(bundle: Bundle, sleep: dict[str, Any], hrv: dict[str, Any],
               spo2: dict[str, Any], steps: dict[str, Any], intervals: dict[str, Any]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    checks = [
        ("resting_hr", _legacy(bundle).get("restingHeartRate"), intervals.get("resting_hr"), "bpm", 3),
        ("hrv_ms", hrv.get("lastNightAvg"), intervals.get("hrv"), "ms", 5),
        ("sleep_s", sleep.get("sleep_s"), intervals.get("sleep_s"), "s", 600),
        ("steps", steps.get("total"), intervals.get("steps"), "steps", max(500, (num(steps.get("total")) or 0) * 0.05)),
        ("spo2_pct", spo2.get("avg"), intervals.get("spo2"), "%", 1),
    ]
    for metric, a, b, unit, threshold in checks:
        conflict = _conflict(metric, a, b, unit, threshold)
        if conflict:
            out.append(conflict)
    body = _body_composition(bundle)
    weight_g = num(body.get("weight"))
    weight_kg = weight_g / 1000.0 if weight_g is not None else None
    conflict = _conflict("weight_kg", weight_kg, intervals.get("weight_kg"), "kg", 0.5)
    if conflict:
        out.append(conflict)
    return out


@lru_cache(maxsize=4)
def _history_rows(path_str: str) -> tuple[dict[str, Any], ...]:
    payload = load_json(Path(path_str), [])
    if isinstance(payload, list):
        return tuple(x for x in payload if isinstance(x, dict))
    return ()


def load_history_baseline(target_date: str, windows: tuple[int, ...] = (7, 28, 90)) -> list[dict[str, Any]]:
    """Averages from the 1-year Garmin daily-summary history, excluding the target day."""
    history_dir = config.DATA_DIR / "hr-history"
    rows: list[dict[str, Any]] = []
    for path in sorted(history_dir.glob("daily-summaries-*.json")):
        rows.extend(_history_rows(str(path)))
    if not rows:
        return []
    try:
        target = date_cls.fromisoformat(target_date)
    except ValueError:
        return []
    out: list[dict[str, Any]] = []
    for window in windows:
        start = (target - timedelta(days=window)).isoformat()
        end = (target - timedelta(days=1)).isoformat()
        selected = [r for r in rows if start <= str(r.get("calendarDate", "")) <= end]
        metrics: dict[str, list[float]] = {}

        def add(name: str, value: Any) -> None:
            n = num(value)
            if n is not None:
                metrics.setdefault(name, []).append(n)

        for row in selected:
            add("steps", dig(row, "movement", "steps", "value"))
            add("distance_m", dig(row, "movement", "steps", "distanceInMeters"))
            add("calories_total", dig(row, "calories", "burnedTotal"))
            add("calories_active", dig(row, "calories", "burnedActive"))
            add("resting_hr", dig(row, "heartRate", "restingValue"))
            add("stress_avg", dig(row, "stress", "avgLevel"))
            add("bb_latest", dig(row, "bodyBattery", "latestValue"))
            add("spo2", dig(row, "pulseOx", "avgValue"))
            add("respiration", dig(row, "respiration", "avgValue"))
        out.append({
            "window_days": window,
            "days_available": len(selected),
            "start": start,
            "end": end,
            "metrics": {name: sum(values) / len(values) for name, values in metrics.items()},
        })
    return out


def normalize_bundle(bundle: Bundle) -> dict[str, Any]:
    v2 = _v2(bundle)
    legacy = _legacy(bundle)
    sleep = _normalize_sleep(bundle)
    hrv_raw = _hrv(bundle)
    hrv = {
        "last_night_avg": num(hrv_raw.get("lastNightAvg")),
        "weekly_avg": num(hrv_raw.get("weeklyAvg")),
        "five_min_high": num(hrv_raw.get("lastNight5MinHigh")),
        "status": hrv_raw.get("status"),
        "feedback": hrv_raw.get("feedbackPhrase"),
        "baseline": hrv_raw.get("baseline") or {},
    }
    stress = _normalize_stress(bundle)
    bb = _normalize_bb(bundle)
    spo2 = _normalize_spo2(bundle)
    respiration = _normalize_respiration(bundle)
    steps = _normalize_steps(bundle)
    hydration = _normalize_hydration(bundle)
    activities = _normalize_activities(bundle)
    intervals = _normalize_intervals(bundle)
    connect = _normalize_connect(bundle)
    hr_samples = _hr_series(bundle)
    bounds, max_hr = _hr_bounds(bundle)
    zones = _zone_times(hr_samples, bounds) if hr_samples else []
    hourly = _hourly_hr(hr_samples)
    conflicts = _conflicts(bundle, sleep, hrv, spo2, steps, intervals)

    chronology = v2.get("wellnessChronology") or {}
    data_end = chronology.get("endTimestampLocal") or _heart_rate(bundle).get("endTimestampLocal")
    partial = None
    partial_day = False
    if data_end:
        try:
            end = datetime.fromisoformat(str(data_end).replace("Z", "+00:00"))
            if end.tzinfo is None:
                end = end.replace(tzinfo=WIB)
            end_wib = end.astimezone(WIB)
            partial = end_wib.strftime("%Y-%m-%d %H:%M")
            target = date_cls.fromisoformat(bundle.date)
            # Full-day wellness chronology ends at the next midnight; a partial
            # day ends on the same calendar date before 23:59.
            partial_day = (
                end_wib.date() == target
                and not (end_wib.hour == 23 and end_wib.minute >= 59)
            )
        except (ValueError, TypeError):
            partial = str(data_end)
            partial_day = False

    return {
        "date": bundle.date,
        "out_dir": str(bundle.out_dir),
        "sources": {
            "personal": bool(bundle.daily_v2 or bundle.legacy),
            "intervals": bool(bundle.intervals),
            "garmin_connect": bool(bundle.connect),
            "session": bool(bundle.session),
        },
        "coverage": {
            "data_end": partial,
            "partial_day": partial_day,
            "missing_files": bundle.missing_files,
            "fetch_status": bundle.fetch_status,
        },
        "summary": {
            "calories_total": _pick(dig(v2, "calories", "burnedTotal"), legacy.get("totalKilocalories")),
            "calories_active": _pick(dig(v2, "calories", "burnedActive"), legacy.get("activeKilocalories")),
            "calories_resting": _pick(dig(v2, "calories", "burnedResting"), legacy.get("bmrKilocalories")),
            "steps": steps.get("total"),
            "distance_m": steps.get("distance_m"),
            "resting_hr": _pick(dig(v2, "heartRate", "restingValue"), legacy.get("restingHeartRate")),
            "min_hr": _pick(dig(v2, "heartRate", "minValue"), legacy.get("minHeartRate")),
            "max_hr": _pick(dig(v2, "heartRate", "maxValue"), legacy.get("maxHeartRate")),
            "hrv": hrv.get("last_night_avg"),
            "sleep_score": sleep.get("score"),
            "sleep_s": sleep.get("sleep_s"),
            "stress_avg": stress.get("avg"),
            "stress_max": stress.get("max"),
            "bb_latest": bb.get("latest"),
            "bb_min": bb.get("min"),
            "bb_max": bb.get("max"),
            "spo2_avg": spo2.get("avg"),
            "spo2_min": spo2.get("min"),
            "respiration_avg": respiration.get("avg"),
            "hydration_ml": hydration.get("consumed_ml"),
            "hydration_goal_ml": hydration.get("goal_ml"),
            "weight_kg": _pick(connect["body_composition"].get("weight_kg"), intervals.get("weight_kg")),
            "ctl": intervals.get("ctl"),
            "atl": intervals.get("atl"),
            "tsb": intervals.get("tsb"),
        },
        "sleep": sleep,
        "hrv": hrv,
        "heart_rate": {
            "samples": hr_samples,
            "sample_count": len(hr_samples),
            "min": min((v for _, v in hr_samples), default=None),
            "max": max((v for _, v in hr_samples), default=None),
            "hourly": hourly,
            "bounds": bounds,
            "max_hr_setting": max_hr,
            "zones_s": zones,
        },
        "stress": stress,
        "body_battery": bb,
        "spo2": spo2,
        "respiration": respiration,
        "steps": steps,
        "hydration": hydration,
        "activities": activities,
        "intervals": intervals,
        "intervals_7d": bundle.intervals_7d,
        "history_baseline": load_history_baseline(bundle.date),
        "connect": connect,
        "session": bundle.session,
        "conflicts": conflicts,
        "user_settings": bundle.user_settings or {},
        "legacy": legacy,
        "daily_v2": v2,
    }
