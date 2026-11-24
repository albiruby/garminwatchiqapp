"""Tools workout: baca, upload, hapus, jadwal, kirim ke device."""
import datetime
import json
import re
import sys

garmin_client = None


def configure(client):
    global garmin_client
    garmin_client = client


_DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")


def _validate_date(value, field="date"):
    if isinstance(value, str) and _DATE_RE.fullmatch(value):
        try:
            datetime.date.fromisoformat(value)
            return value
        except ValueError:
            pass
    raise ValueError(f"Invalid {field} {value!r}: expected YYYY-MM-DD")


def _curate_summary(w):
    sport = w.get("sportType") or {}
    out = {
        "id": w.get("workoutId"),
        "name": w.get("workoutName"),
        "sport": sport.get("sportTypeKey"),
        "updated": w.get("updatedDate"),
    }
    if w.get("estimatedDurationInSecs") is not None:
        out["est_duration_s"] = w.get("estimatedDurationInSecs")
    if w.get("estimatedDistanceInMeters") is not None:
        out["est_distance_m"] = w.get("estimatedDistanceInMeters")
    return {k: v for k, v in out.items() if v is not None}


def _is_already_scheduled(workout_id, date):
    try:
        q = {"query": f'query{{workoutScheduleSummariesScalar(startDate:"{date}", endDate:"{date}")}}'}
        res = garmin_client.query_garmin_graphql(q) or {}
        for e in ((res.get("data") or {}).get("workoutScheduleSummariesScalar") or []):
            if e.get("workoutId") == int(workout_id) and e.get("scheduleDate") == date:
                return True
    except Exception:
        pass
    return False


def register_tools(app):
    from .validation import normalize_workout_steps, validate_workout

    @app.tool()
    async def list_workouts() -> str:
        """Daftar semua workout di library (id, nama, sport, estimasi)."""
        try:
            out, seen, start = [], set(), 1
            while True:
                page = garmin_client.get_workouts(start, 100)
                if not isinstance(page, list):
                    break
                new = [w for w in page if isinstance(w, dict)
                       and w.get("workoutId") not in seen]
                if not new:
                    break
                out.extend(new)
                seen.update(w.get("workoutId") for w in new)
                if len(page) < 100:
                    break
                start += 100
            return json.dumps({"count": len(out),
                               "workouts": [_curate_summary(w) for w in out]}, indent=2)
        except Exception as e:
            return f"Error listing workouts: {e}"

    @app.tool()
    async def get_workout(workout_id: int, raw: bool = False) -> str:
        """Detail workout (segments + steps). raw=true = JSON penuh Garmin.

        Args:
            workout_id: ID dari list_workouts
            raw: kembalikan DTO penuh (untuk edit manual)
        """
        try:
            w = garmin_client.get_workout_by_id(int(workout_id))
            if not w:
                return f"No workout {workout_id}."
            if raw:
                return json.dumps(w, indent=2)
            segs = []
            for sg in w.get("workoutSegments", []):
                steps = []
                for st in sg.get("workoutSteps", []):
                    steps.append({
                        "order": st.get("stepOrder"),
                        "type": (st.get("stepType") or {}).get("stepTypeKey"),
                        "end": (st.get("endCondition") or {}).get("conditionTypeKey"),
                        "end_value": st.get("endConditionValue"),
                        "target": (st.get("targetType") or {}).get("workoutTargetTypeKey"),
                        "zone": st.get("zoneNumber"),
                        "desc": st.get("description"),
                    })
                segs.append({"sport": (sg.get("sportType") or {}).get("sportTypeKey"),
                             "steps": steps})
            return json.dumps({"id": w.get("workoutId"), "name": w.get("workoutName"),
                               "segments": segs}, indent=2)
        except Exception as e:
            return f"Error getting workout: {e}"

    @app.tool()
    async def upload_workout(workout_data: dict) -> str:
        """Upload workout JSON ke library Garmin (muncul di My Workouts).

        Aturan: RepeatGroupDTO wajib endCondition {7, iterations} +
        numberOfIterations; stepOrder depth-first; target pace m/s
        (5:00/km = 3.333); HR zone pakai zoneNumber 1-5; custom HR pakai
        targetValueOne/Two. Validasi lokal dulu, ditolak sebelum terkirim.

        Args:
            workout_data: dict workout Garmin (dari builder atau get_workout raw)
        """
        try:
            normalize_workout_steps(workout_data)
            validate_workout(workout_data)
            r = garmin_client.upload_workout(workout_data)
            if isinstance(r, dict):
                return json.dumps({"status": "success",
                                   "workout_id": r.get("workoutId"),
                                   "name": r.get("workoutName")}, indent=2)
            return json.dumps(r, indent=2)
        except Exception as e:
            return f"Error uploading workout: {e}"

    @app.tool()
    async def delete_workout(workout_id: int, confirm: bool = False) -> str:
        """Hapus workout dari library ( permanen ). confirm=true untuk eksekusi.

        Args:
            workout_id: ID workout
            confirm: wajib true untuk menghapus; false = preview saja
        """
        try:
            wid = int(workout_id)
            w = garmin_client.get_workout_by_id(wid) or {}
            preview = {"workout_id": wid, "name": w.get("workoutName")}
            if not confirm:
                return json.dumps({"status": "needs_confirmation",
                                   "workout": preview,
                                   "message": "Panggil lagi dengan confirm=true."}, indent=2)
            garmin_client.delete_workout(wid)
            print(f"delete_workout: {wid} {preview.get('name')!r}", file=sys.stderr)
            return json.dumps({"status": "success", "workout_id": wid}, indent=2)
        except Exception as e:
            return json.dumps({"status": "failed", "message": str(e)}, indent=2)

    @app.tool()
    async def schedule_workout(workout_id: int, calendar_date: str) -> str:
        """Jadwalkan workout ke tanggal kalender (idempoten, tanpa duplikat).

        Args:
            workout_id: ID workout di library
            calendar_date: YYYY-MM-DD
        """
        try:
            _validate_date(calendar_date)
            wid = int(workout_id)
            if _is_already_scheduled(wid, calendar_date):
                return json.dumps({"status": "success", "idempotent": True,
                                   "message": "Sudah terjadwal, tidak ada duplikat."}, indent=2)
            resp = garmin_client.client.post(
                "connectapi", f"workout-service/schedule/{wid}",
                json={"date": calendar_date})
            if 200 <= resp.status_code < 300:
                return json.dumps({"status": "success", "workout_id": wid,
                                   "scheduled_date": calendar_date}, indent=2)
            return json.dumps({"status": "failed",
                               "http_status": resp.status_code}, indent=2)
        except Exception as e:
            return f"Error scheduling workout: {e}"

    @app.tool()
    async def unschedule_workout(scheduled_workout_id: int) -> str:
        """Hapus entri kalender (workout di library tetap ada).

        Args:
            scheduled_workout_id: id entri kalender (dari get_scheduled_workouts)
        """
        try:
            garmin_client.unschedule_workout(int(scheduled_workout_id))
            return json.dumps({"status": "success",
                               "scheduled_workout_id": int(scheduled_workout_id)}, indent=2)
        except Exception as e:
            return json.dumps({"status": "failed", "message": str(e)}, indent=2)

    @app.tool()
    async def get_scheduled_workouts(start_date: str, end_date: str) -> str:
        """Kalender workout terjadwal antar tanggal (id entri + status selesai).

        Args:
            start_date: YYYY-MM-DD
            end_date: YYYY-MM-DD
        """
        try:
            _validate_date(start_date)
            _validate_date(end_date)
            q = {"query": f'query{{workoutScheduleSummariesScalar(startDate:"{start_date}", endDate:"{end_date}")}}'}
            res = garmin_client.query_garmin_graphql(q) or {}
            items = (res.get("data") or {}).get("workoutScheduleSummariesScalar") or []
            return json.dumps({"count": len(items), "scheduled": [
                {"date": i.get("scheduleDate"),
                 "scheduled_workout_id": i.get("scheduledWorkoutId"),
                 "workout_id": i.get("workoutId"), "name": i.get("workoutName"),
                 "completed": i.get("associatedActivityId") is not None}
                for i in items if isinstance(i, dict)]}, indent=2)
        except Exception as e:
            return f"Error getting scheduled workouts: {e}"

    @app.tool()
    async def push_workout_to_device(workout_id: int, device_id: int = 0) -> str:
        """Antrekan workout ke device (masuk watch saat sync berikutnya).

        Args:
            workout_id: ID workout di library
            device_id: opsional; default = device terakhir dipakai
        """
        try:
            wid = int(workout_id)
            if not device_id:
                last = garmin_client.get_device_last_used() or {}
                device_id = last.get("userDeviceId")
                if not device_id:
                    return "Tidak ada default device; isi device_id eksplisit."
            w = garmin_client.get_workout_by_id(wid) or {}
            payload = [{"deviceId": device_id,
                        "messageUrl": f"workout-service/workout/FIT/{wid}",
                        "messageType": "workouts", "groupName": None,
                        "messageName": w.get("workoutName") or f"Workout {wid}",
                        "priority": 1, "fileType": "FIT", "metaDataId": wid}]
            resp = garmin_client.client.post(
                "connectapi", "device-service/devicemessage/messages", json=payload)
            if resp.status_code in (200, 204):
                return json.dumps({"status": "success", "workout_id": wid,
                                   "device_id": device_id,
                                   "message": "Antre; masuk device saat sync."}, indent=2)
            return json.dumps({"status": "failed",
                               "http_status": resp.status_code}, indent=2)
        except Exception as e:
            return json.dumps({"status": "failed", "message": str(e)}, indent=2)

    @app.tool()
    async def get_devices() -> str:
        """Daftar device (untuk push_workout_to_device)."""
        try:
            devs = garmin_client.get_devices() or []
            return json.dumps([{"device_id": d.get("deviceId"),
                               "name": d.get("displayName"),
                               "primary": d.get("primaryDevice")}
                              for d in devs], indent=2)
        except Exception as e:
            return f"Error listing devices: {e}"

    return app
