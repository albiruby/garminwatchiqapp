"""Builder workout lari (pure function, tanpa network) -> dict siap upload."""
from .validation import SPORT_TYPE_IDS, pace_to_ms

garmin_client = None


def configure(client):
    global garmin_client
    garmin_client = client


def _step(order, step_key, end_key, end_id, end_value, target_id=None,
          target_key=None, zone=None, v1=None, v2=None, desc=None):
    s = {
        "type": "ExecutableStepDTO",
        "stepOrder": order,
        "stepType": {"stepTypeKey": step_key},
        "endCondition": {"conditionTypeId": end_id, "conditionTypeKey": end_key},
    }
    if end_value is not None:
        s["endConditionValue"] = float(end_value)
    if target_id is not None:
        s["targetType"] = {"workoutTargetTypeId": target_id,
                           "workoutTargetTypeKey": target_key}
    if zone is not None:
        s["zoneNumber"] = zone
    if v1 is not None:
        s["targetValueOne"] = v1
    if v2 is not None:
        s["targetValueTwo"] = v2
    if desc:
        s["description"] = desc
    return s


def _target_kwargs(target, pace_min_per_km=None, hr_zone=None):
    """target 'pace' | 'hr' | 'none' -> kwargs untuk _step."""
    if target == "hr":
        if not (1 <= int(hr_zone) <= 5):
            raise ValueError("hr_zone harus 1-5")
        return {"target_id": 4, "target_key": "heart.rate.zone", "zone": int(hr_zone)}
    if target == "pace":
        fast = pace_to_ms(pace_min_per_km)
        slow = pace_to_ms(_add_seconds(pace_min_per_km, 15))
        return {"target_id": 6, "target_key": "pace.zone", "v1": slow, "v2": fast}
    return {"target_id": 1, "target_key": "no.target"}


def _add_seconds(pace, sec):
    m, s = pace.split(":")
    total = int(m) * 60 + float(s) + sec
    return f"{int(total // 60)}:{total % 60:04.1f}"


def build_run_interval(name, repeats, rep_len, rep_unit="time",
                       recovery_min=2, warmup_min=10, cooldown_min=10,
                       target="none", pace_min_per_km=None, hr_zone=None,
                       sport="running"):
    """Interval lari: warmup + repeats x [rep + recovery] + cooldown.

    rep_len: menit (rep_unit='time') atau meter (rep_unit='distance').
    Contoh pola kamu: 3x9' -> repeats=3, rep_len=9; 5x5' -> repeats=5,
    rep_len=5; over-under -> dua blok repeat terpisah via dua kali builder.
    """
    if rep_unit not in ("time", "distance"):
        raise ValueError("rep_unit harus 'time' atau 'distance'")
    sid = SPORT_TYPE_IDS.get(sport, 1)
    tk = _target_kwargs(target, pace_min_per_km, hr_zone)
    order, steps_body = 1, []
    steps_body.append(_step(order, "warmup", "time", 2, warmup_min * 60,
                            target_id=1, target_key="no.target",
                            desc=f"Warmup {warmup_min} min"))
    order += 1
    if rep_unit == "time":
        rep_end, rep_val = ("time", 2), rep_len * 60
    else:
        rep_end, rep_val = ("distance", 3), rep_len
    rep = _step(order + 1, "interval", rep_end[0], rep_end[1], rep_val, **tk)
    rec = _step(order + 2, "recover", "time", 2, recovery_min * 60,
                target_id=1, target_key="no.target")
    group = {
        "type": "RepeatGroupDTO",
        "stepOrder": order,
        "stepType": {"stepTypeId": 6, "stepTypeKey": "repeat"},
        "endCondition": {"conditionTypeId": 7, "conditionTypeKey": "iterations"},
        "endConditionValue": repeats,
        "numberOfIterations": repeats,
        "workoutSteps": [rep, rec],
    }
    steps_body.append(group)
    order += 3
    steps_body.append(_step(order, "cooldown", "time", 2, cooldown_min * 60,
                            target_id=1, target_key="no.target",
                            desc=f"Cooldown {cooldown_min} min"))
    return {
        "workoutName": name,
        "sportType": {"sportTypeId": sid, "sportTypeKey": sport},
        "workoutSegments": [{
            "segmentOrder": 1,
            "sportType": {"sportTypeId": sid, "sportTypeKey": sport},
            "workoutSteps": steps_body,
        }],
    }


def build_walk_run(name, run_min, walk_min, repeats,
                   warmup_min=10, cooldown_min=8, hr_zone=None):
    """Walk/run alternating dengan target HR zone opsional."""
    sid = SPORT_TYPE_IDS["running"]
    tk = _target_kwargs("hr" if hr_zone else "none", hr_zone=hr_zone)
    tk_none = {"target_id": 1, "target_key": "no.target"}
    run = _step(3, "interval", "time", 2, run_min * 60, **tk)
    walk = _step(4, "recover", "time", 2, walk_min * 60, **tk_none)
    group = {
        "type": "RepeatGroupDTO",
        "stepOrder": 2,
        "stepType": {"stepTypeId": 6, "stepTypeKey": "repeat"},
        "endCondition": {"conditionTypeId": 7, "conditionTypeKey": "iterations"},
        "endConditionValue": repeats,
        "numberOfIterations": repeats,
        "workoutSteps": [run, walk],
    }
    return {
        "workoutName": name,
        "sportType": {"sportTypeId": sid, "sportTypeKey": "running"},
        "workoutSegments": [{
            "segmentOrder": 1,
            "sportType": {"sportTypeId": sid, "sportTypeKey": "running"},
            "workoutSteps": [
                _step(1, "warmup", "time", 2, warmup_min * 60, **tk_none),
                group,
                _step(5, "cooldown", "time", 2, cooldown_min * 60, **tk_none),
            ],
        }],
    }


def register_tools(app):
    import json

    @app.tool()
    async def create_run_interval_workout(
        name: str, repeats: int, rep_len: float, rep_unit: str = "time",
        recovery_min: float = 2, warmup_min: float = 10,
        cooldown_min: float = 10, target: str = "none",
        pace_min_per_km: str = "", hr_zone: int = 0,
    ) -> str:
        """Buat + upload workout interval lari. Contoh pola kamu: 3x9' ->
        repeats=3 rep_len=9; 5x5' -> repeats=5 rep_len=5; 600m ->
        rep_len=600 rep_unit='distance'.

        Args:
            name: nama workout
            repeats: jumlah repetisi
            rep_len: durasi menit (time) atau meter (distance)
            rep_unit: 'time' | 'distance'
            recovery_min: jeda antar rep (menit)
            warmup_min: pemanasan (menit)
            cooldown_min: pendinginan (menit)
            target: 'none' | 'pace' | 'hr'
            pace_min_per_km: mis '4:38' (wajib jika target pace)
            hr_zone: 1-5 (wajib jika target hr)
        """
        try:
            from .validation import normalize_workout_steps, validate_workout
            data = build_run_interval(
                name, int(repeats), float(rep_len), rep_unit,
                float(recovery_min), float(warmup_min), float(cooldown_min),
                target, pace_min_per_km or None, int(hr_zone) or None)
            normalize_workout_steps(data)
            validate_workout(data)
            r = garmin_client.upload_workout(data)
            return json.dumps({"status": "success",
                               "workout_id": (r or {}).get("workoutId"),
                               "name": name}, indent=2)
        except Exception as e:
            return f"Error creating workout: {e}"

    @app.tool()
    async def create_walk_run_workout(
        name: str, run_min: float, walk_min: float, repeats: int,
        warmup_min: float = 10, cooldown_min: float = 8, hr_zone: int = 0,
    ) -> str:
        """Buat + upload workout walk/run alternating (target HR zone opsional).

        Args:
            name: nama workout
            run_min: durasi lari per repetisi (menit)
            walk_min: durasi jalan per repetisi (menit)
            repeats: jumlah repetisi
            warmup_min: pemanasan (menit)
            cooldown_min: pendinginan (menit)
            hr_zone: 0 = tanpa target, 1-5 = zona HR
        """
        try:
            from .validation import normalize_workout_steps, validate_workout
            data = build_walk_run(name, float(run_min), float(walk_min),
                                  int(repeats), float(warmup_min),
                                  float(cooldown_min), int(hr_zone) or None)
            normalize_workout_steps(data)
            validate_workout(data)
            r = garmin_client.upload_workout(data)
            return json.dumps({"status": "success",
                               "workout_id": (r or {}).get("workoutId"),
                               "name": name}, indent=2)
        except Exception as e:
            return f"Error creating workout: {e}"

    @app.tool()
    async def schedule_week(items: list) -> str:
        """Upload (opsional) + jadwalkan banyak workout sekaligus.

        Args:
            items: list {calendar_date: YYYY-MM-DD, workout_id?: int,
                workout_data?: dict}. Isi salah satu workout_id/workout_data.
        """
        from .validation import normalize_workout_steps, validate_workout
        from .workouts import _validate_date, _is_already_scheduled
        results = []
        for it in items or []:
            date, wid, data = it.get("calendar_date"), it.get("workout_id"), it.get("workout_data")
            try:
                _validate_date(date)
                if wid is None and data is None:
                    raise ValueError("butuh workout_id atau workout_data")
                if data is not None:
                    normalize_workout_steps(data)
                    validate_workout(data)
                    up = garmin_client.upload_workout(data)
                    wid = (up or {}).get("workoutId")
                    if wid is None:
                        raise ValueError("upload tanpa workoutId")
                wid = int(wid)
                if _is_already_scheduled(wid, date):
                    results.append({"status": "success", "idempotent": True,
                                    "workout_id": wid, "date": date})
                    continue
                resp = garmin_client.client.post(
                    "connectapi", f"workout-service/schedule/{wid}",
                    json={"date": date})
                results.append({"status": "success" if 200 <= resp.status_code < 300 else "failed",
                                "workout_id": wid, "date": date})
            except Exception as e:
                results.append({"status": "error", "date": date, "message": str(e)})
        ok = sum(1 for r in results if r["status"] == "success")
        return json.dumps({"total": len(results), "succeeded": ok,
                           "failed": len(results) - ok, "results": results}, indent=2)

    return app
