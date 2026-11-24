"""Validasi dan normalisasi payload workout Garmin (adaptasi pola Taxuspt/garmin_mcp)."""

END_CONDITION_TYPE_IDS = {
    "lap.button": 1, "time": 2, "distance": 3, "calories": 4,
    "power": 5, "heart.rate": 6, "iterations": 7, "fixed.rest": 8,
    "fixed.repetition": 9, "reps": 10, "training.peaks.tss": 11,
}
END_CONDITION_TYPE_KEYS = {v: k for k, v in END_CONDITION_TYPE_IDS.items()}

KNOWN_TARGET_TYPE_IDS = {
    1: frozenset(["no.target"]),
    2: frozenset(["power.zone"]),
    4: frozenset(["heart.rate.zone"]),
    6: frozenset(["pace.zone", "power.between"]),
}
KNOWN_TARGET_TYPE_KEYS = {k: i for i, ks in KNOWN_TARGET_TYPE_IDS.items() for k in ks}

SPORT_TYPE_IDS = {"running": 1, "cycling": 2, "strength_training": 5,
                  "cardio_training": 6, "walking": 12}


def _iter_steps(workout_data):
    for si, seg in enumerate(workout_data.get("workoutSegments", [])):
        for ni, step in enumerate(seg.get("workoutSteps", [])):
            path = f"workoutSegments[{si}].workoutSteps[{ni}]"
            yield step, path
            stack = [(s, f"{path}.workoutSteps[{j}]")
                     for j, s in enumerate(step.get("workoutSteps", []))]
            while stack:
                s, p = stack.pop()
                yield s, p
                stack.extend((n, f"{p}.workoutSteps[{j}]")
                             for j, n in enumerate(s.get("workoutSteps", [])))


def normalize_workout_steps(workout_data):
    """Perbaiki kesalahan umum sebelum validasi/upload."""
    for step, _ in _iter_steps(workout_data):
        for field, bounds in (("targetType", ("targetValueOne", "targetValueTwo", "zoneNumber")),
                               ("secondaryTargetType", ("secondaryTargetValueOne", "secondaryTargetValueTwo", "secondaryZoneNumber"))):
            tt = step.get(field)
            if isinstance(tt, dict):
                for f in bounds:
                    if f in tt and step.get(f) is None:
                        step[f] = tt.pop(f)
        # HR zone 1-5 yang salah taruh di targetValueOne -> zoneNumber
        tt = step.get("targetType") or {}
        if tt.get("workoutTargetTypeKey") == "heart.rate.zone" and step.get("zoneNumber") is None:
            try:
                z = float(step.get("targetValueOne"))
            except (TypeError, ValueError):
                z = None
            if z is not None and z.is_integer() and 1 <= z <= 5:
                step["zoneNumber"] = int(z)
                step.pop("targetValueOne", None)
                step.pop("targetValueTwo", None)
        # RepeatGroup tanpa conditionTypeId/numberOfIterations
        if step.get("type") == "RepeatGroupDTO":
            ec = step.get("endCondition")
            if isinstance(ec, dict) and ec.get("conditionTypeKey") == "iterations" \
                    and "conditionTypeId" not in ec:
                ec["conditionTypeId"] = 7
            if step.get("numberOfIterations") is None and step.get("endConditionValue") is not None:
                step["numberOfIterations"] = int(step["endConditionValue"])
    return workout_data


def validate_workout(workout_data):
    """Tolak pasangan id/key yang akan disalahartikan Garmin. Raise ValueError."""
    for step, path in _iter_steps(workout_data):
        ec = step.get("endCondition")
        if isinstance(ec, dict):
            key, cid = ec.get("conditionTypeKey"), ec.get("conditionTypeId")
            if isinstance(cid, str):
                cid = ec["conditionTypeId"] = int(cid)
            exp = END_CONDITION_TYPE_IDS.get(key)
            if exp is not None and cid is not None and cid != exp:
                raise ValueError(f"{path}.endCondition: key {key!r} butuh id {exp}, dapat {cid}")
        for field in ("targetType", "secondaryTargetType"):
            tt = step.get(field)
            if isinstance(tt, dict):
                key, tid = tt.get("workoutTargetTypeKey"), tt.get("workoutTargetTypeId")
                if isinstance(tid, str):
                    tid = tt["workoutTargetTypeId"] = int(tid)
                if tid is not None and key is not None:
                    valid = KNOWN_TARGET_TYPE_IDS.get(tid)
                    if valid is not None and key not in valid:
                        raise ValueError(f"{path}.{field}: id {tid} bukan {key!r}")
                    exp = KNOWN_TARGET_TYPE_KEYS.get(key)
                    if exp is not None and tid != exp:
                        raise ValueError(f"{path}.{field}: key {key!r} butuh id {exp}, dapat {tid}")
    return True


def pace_to_ms(pace_min_per_km):
    """'4:38' -> m/s."""
    m, s = pace_min_per_km.split(":")
    return 1000.0 / (int(m) * 60 + float(s))
