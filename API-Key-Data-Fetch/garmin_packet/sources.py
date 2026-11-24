"""Data source clients.

Three sources, three trust levels:
- Garmin Personal API: official, API key, read-only.
- Intervals.icu: API key, read-only.
- Garmin Connect: unofficial `garminconnect`, token with full account access,
  wrapped by ReadOnlyGarminClient so only allowlisted GET methods are reachable.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from datetime import date as date_cls, timedelta
from pathlib import Path
from typing import Any

import requests
from requests.auth import HTTPBasicAuth

from . import config
from .util import load_json, now_wib, save_json


class SourceError(RuntimeError):
    """A source failed in a way the caller should show to the user."""


@dataclass
class EndpointStatus:
    name: str
    status: str
    http: int | None = None
    bytes: int | None = None
    error: str | None = None
    path: str | None = None


@dataclass
class SourceStatus:
    source: str
    status: str = "ok"
    endpoints: list[EndpointStatus] = field(default_factory=list)
    fetched_at: str = field(default_factory=now_wib)
    error: str | None = None

    def add(self, item: EndpointStatus) -> None:
        self.endpoints.append(item)
        if item.status not in ("ok", "skipped"):
            self.status = "partial" if self.status == "ok" else self.status

    def as_dict(self) -> dict[str, Any]:
        return {
            "source": self.source,
            "status": self.status,
            "fetched_at": self.fetched_at,
            "error": self.error,
            "endpoints": [e.__dict__ for e in self.endpoints],
        }


# ---------------------------------------------------------------------------
# Garmin Personal API
# ---------------------------------------------------------------------------


PERSONAL_ENDPOINTS: list[tuple[str, str]] = [
    ("user-settings", "/userprofile-service/userprofile/settings"),
    ("hr-zones", "/biometric-service/heartRateZones/v2?generateDefaults=true"),
    ("daily-v2", "/usersummary-service/v2/dailysummaries?startDate={date}&endDate={date}"),
    ("daily-legacy", "/usersummary-service/usersummary/daily?calendarDate={date}"),
    ("heart-rate", "/wellness-service/wellness/dailyHeartRate?date={date}"),
    ("sleep", "/sleep-service/sleep/dailySleepSummariesByDate?startDate={date}&endDate={date}"),
    ("sleep-data", "/wellness-service/wellness/dailySleepData?date={date}"),
    ("body-battery", "/wellness-service/wellness/bodyBattery/reports/daily?startDate={date}&endDate={date}&chunks=4"),
    ("hrv", "/hrv-service/hrv/daily/{date}/{date}"),
    ("spo2", "/wellness-service/wellness/daily/spo2acclimation/{date}"),
    ("respiration", "/wellness-service/wellness/daily/respiration/{date}"),
    ("stress", "/usersummary-service/stats/stress/daily/{date}/{date}"),
    ("steps", "/usersummary-service/stats/steps/daily/{date}/{date}"),
    ("hydration", "/usersummary-service/stats/hydration/daily/{date}/{date}"),
    ("weight", "/weight-service/weight/range/{date}/{date}?includeAll=true"),
    ("fitness-age", "/fitnessage-service/fitnessage/v2/{date}?fullHistoryScan=true"),
    ("training-readiness", "/metrics-service/metrics/trainingreadiness/{date}"),
    ("training-status", "/metrics-service/metrics/trainingstatus/aggregated/{date}"),
    ("activities", "/activitylist-service/activities/search/activities?startDate={date}&endDate={date}&start=0&limit=50"),
]


class GarminPersonalClient:
    """Official Garmin Personal API, API-key authenticated, GET only."""

    def __init__(self, api_key: str | None = None, base_url: str = config.GARMIN_PERSONAL_BASE):
        self._api_key = (api_key or config.get_garmin_api_key()).strip()
        self._base = base_url.rstrip("/")
        self._bearer: str | None = None
        self._session = requests.Session()

    def _token(self, refresh: bool = False) -> str:
        if self._bearer and not refresh:
            return self._bearer
        response = self._session.post(
            f"{self._base}/personalapitoken-service/personal-api/personal-api-key/token",
            headers={"Authorization": f"ApiKey {self._api_key}"},
            timeout=30,
        )
        response.raise_for_status()
        try:
            payload = response.json()
        except ValueError:
            payload = response.text.strip().strip('"')
        if isinstance(payload, dict):
            token = (
                payload.get("access_token")
                or payload.get("token")
                or payload.get("personalApiToken")
                or payload.get("data")
            )
        else:
            token = payload
        if not token:
            raise SourceError("Garmin Personal API token exchange returned no token.")
        self._bearer = str(token).strip().strip('"')
        return self._bearer

    def get(self, path: str) -> Any:
        for attempt in (0, 1):
            token = self._token(refresh=attempt == 1)
            response = self._session.get(
                f"{self._base}{path}",
                headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
                timeout=60,
            )
            if response.status_code == 401 and attempt == 0:
                continue
            response.raise_for_status()
            if not response.content:
                return None
            return response.json()
        raise SourceError("Garmin Personal API rejected the token after refresh.")

    def fetch_date(self, day: str, out_dir: Path, refresh: bool = False) -> SourceStatus:
        status = SourceStatus("garmin_personal")
        out_dir.mkdir(parents=True, exist_ok=True)
        for name, template in PERSONAL_ENDPOINTS:
            path = template.format(date=day)
            target = out_dir / f"{name}.json"
            if target.exists() and not refresh:
                status.add(EndpointStatus(name, "skipped", path=str(target)))
                continue
            try:
                payload = self.get(path)
                if payload is None:
                    status.add(EndpointStatus(name, "empty", http=204, path=str(target)))
                    continue
                save_json(target, payload)
                size = target.stat().st_size
                status.add(EndpointStatus(name, "ok", http=200, bytes=size, path=str(target)))
            except requests.HTTPError as exc:
                code = exc.response.status_code if exc.response is not None else None
                status.add(EndpointStatus(name, "unavailable" if code in (400, 404) else "error",
                                          http=code, error=str(exc)[:300]))
            except Exception as exc:  # noqa: BLE001 - surface per endpoint
                status.add(EndpointStatus(name, "error", error=f"{type(exc).__name__}: {exc}"[:300]))
            time.sleep(0.15)
        if status.endpoints and all(e.status in ("unavailable", "error", "empty") for e in status.endpoints):
            status.status = "unavailable"
        return status


# ---------------------------------------------------------------------------
# Intervals.icu
# ---------------------------------------------------------------------------


class IntervalsClient:
    """Intervals.icu API, Basic auth (username API_KEY, password API key)."""

    def __init__(self, api_key: str | None = None, athlete_id: str | None = None,
                 base_url: str = config.INTERVALS_BASE):
        env_athlete, env_key = ("", "")
        if api_key is None or athlete_id is None:
            env_athlete, env_key = config.get_intervals_credentials()
        self._api_key = (api_key or env_key).strip()
        self._athlete_id = (athlete_id or env_athlete or "0").strip()
        self._base = base_url.rstrip("/")
        self._session = requests.Session()
        self._auth = HTTPBasicAuth("API_KEY", self._api_key)

    def get(self, path: str, params: dict[str, Any] | None = None) -> Any:
        response = self._session.get(
            f"{self._base}{path}",
            params=params,
            auth=self._auth,
            headers={"Accept": "application/json"},
            timeout=60,
        )
        response.raise_for_status()
        return response.json() if response.content else None

    def fetch_date(self, day: str, out_dir: Path, refresh: bool = False) -> SourceStatus:
        status = SourceStatus("intervals")
        out_dir.mkdir(parents=True, exist_ok=True)
        start = date_cls.fromisoformat(day) - timedelta(days=6)
        jobs: list[tuple[str, str, dict[str, Any]]] = [
            ("intervals-wellness", f"/athlete/{self._athlete_id}/wellness",
             {"oldest": day, "newest": day}),
            ("intervals-wellness-7d", f"/athlete/{self._athlete_id}/wellness",
             {"oldest": start.isoformat(), "newest": day}),
            ("intervals-activities", f"/athlete/{self._athlete_id}/activities",
             {"oldest": day, "newest": day}),
        ]
        for name, path, params in jobs:
            target = out_dir / f"{name}.json"
            if target.exists() and not refresh:
                status.add(EndpointStatus(name, "skipped", path=str(target)))
                continue
            try:
                payload = self.get(path, params=params)
                if payload is None:
                    status.add(EndpointStatus(name, "empty", http=204))
                    continue
                save_json(target, payload)
                status.add(EndpointStatus(name, "ok", http=200, bytes=target.stat().st_size,
                                          path=str(target)))
            except requests.HTTPError as exc:
                code = exc.response.status_code if exc.response is not None else None
                status.add(EndpointStatus(name, "unavailable" if code in (400, 404) else "error",
                                          http=code, error=str(exc)[:300]))
            except Exception as exc:  # noqa: BLE001
                status.add(EndpointStatus(name, "error", error=f"{type(exc).__name__}: {exc}"[:300]))
            time.sleep(0.25)
        if status.endpoints and all(e.status in ("unavailable", "error", "empty") for e in status.endpoints):
            status.status = "unavailable"
        return status


# ---------------------------------------------------------------------------
# Garmin Connect (unofficial) — read-only wrapper
# ---------------------------------------------------------------------------


READ_METHODS: set[str] = {
    "get_body_composition",
    "get_daily_weigh_ins",
    "get_weigh_ins",
    "get_training_readiness",
    "get_morning_training_readiness",
    "get_training_status",
    "get_fitnessage_data",
    "get_respiration_data",
    "get_respiration_summary",
    "get_training_load_trend",
    "get_training_load_balance",
    "get_lactate_threshold",
    "get_cycling_ftp",
    "get_race_predictions",
    "get_personal_record",
    "get_activity_splits",
    "get_activity_typed_splits",
    "get_activity_weather",
    "get_nutrition_daily_food_log",
    "get_nutrition_daily_meals",
    "get_nutrition_summary_between_dates",
    "get_gear",
    "get_activity_gear",
    "get_devices",
    "get_activities_by_date",
    "get_activity",
    "get_user_profile",
    "get_unit_system",
    "get_heart_rate_zones",
    "get_full_name",
    "get_device_last_used",
}


class ReadOnlyGarminClient:
    """Only allowlisted GET methods; the raw client object is never retained.

    Storing bound read methods (instead of the Garmin object) means even
    introspection of the wrapper cannot reach post/put/delete.
    """

    def __init__(self, client: Any):
        methods = {
            name: getattr(client, name)
            for name in READ_METHODS
            if hasattr(client, name)
        }
        object.__setattr__(self, "_methods", methods)

    def __getattr__(self, name: str) -> Any:
        methods = object.__getattribute__(self, "_methods")
        if name in methods:
            return methods[name]
        raise PermissionError(
            f"ReadOnlyGarminClient: '{name}' tidak diizinkan. Hanya method baca yang tersedia."
        )


class GarminConnectSource:
    """Gap-fill via garminconnect. Requires a token directory; never writes."""

    def __init__(self, token_dir: Path | None = None):
        self._token_dir = Path(token_dir or config.TOKEN_DIR)

    def _client(self) -> ReadOnlyGarminClient:
        if not self._token_dir.exists():
            raise SourceError(
                f"Token Garmin Connect tidak ditemukan di {self._token_dir}. "
                "Jalankan auth atau set GARMINTOKENS."
            )
        try:
            from garminconnect import Garmin
        except ImportError as exc:
            raise SourceError("Package garminconnect belum terpasang.") from exc
        client = Garmin()
        client.login(str(self._token_dir))
        return ReadOnlyGarminClient(client)

    def fetch_date(self, day: str, out_dir: Path, refresh: bool = False,
                   activity_ids: list[int] | None = None) -> SourceStatus:
        status = SourceStatus("garmin_connect")
        target_dir = out_dir / "garmin-connect"
        target_dir.mkdir(parents=True, exist_ok=True)
        try:
            client = self._client()
        except Exception as exc:  # noqa: BLE001
            status.status = "unavailable"
            status.error = str(exc)[:400]
            return status

        start = date_cls.fromisoformat(day) - timedelta(days=29)
        jobs: list[tuple[str, str, tuple[Any, ...]]] = [
            ("body-composition", "get_body_composition", (day, day)),
            ("weigh-ins", "get_weigh_ins", (day, day)),
            ("training-readiness", "get_training_readiness", (day,)),
            ("training-status", "get_training_status", (day,)),
            ("fitness-age", "get_fitnessage_data", (day,)),
            ("respiration", "get_respiration_data", (day,)),
            ("training-load-trend", "get_training_load_trend", (start.isoformat(), day)),
            ("lactate-threshold", "get_lactate_threshold", (day,)),
            ("cycling-ftp", "get_cycling_ftp", ()),
            ("race-predictions", "get_race_predictions", ()),
            ("personal-records", "get_personal_record", ()),
            ("gear", "get_gear", ()),
            ("devices", "get_devices", ()),
            ("nutrition-food-log", "get_nutrition_daily_food_log", (day,)),
            ("nutrition-meals", "get_nutrition_daily_meals", (day,)),
        ]
        for name, method_name, args in jobs:
            target = target_dir / f"{name}.json"
            if target.exists() and not refresh:
                status.add(EndpointStatus(name, "skipped", path=str(target)))
                continue
            try:
                method = getattr(client, method_name)
                try:
                    payload = method(*args)
                except TypeError:
                    # Some library versions take no date argument.
                    payload = method()
                if payload is None:
                    status.add(EndpointStatus(name, "empty", http=204))
                    continue
                save_json(target, payload)
                status.add(EndpointStatus(name, "ok", http=200, bytes=target.stat().st_size,
                                          path=str(target)))
            except AttributeError as exc:
                status.add(EndpointStatus(name, "unavailable", error=str(exc)[:300]))
            except Exception as exc:  # noqa: BLE001
                text = f"{type(exc).__name__}: {exc}"
                status.add(EndpointStatus(name, "unavailable" if "404" in text or "not found" in text.lower()
                                          else "error", error=text[:300]))
            time.sleep(0.2)

        for activity_id in (activity_ids or [])[:3]:
            for name, call in (
                (f"activity-splits-{activity_id}", lambda aid=activity_id: client.get_activity_splits(aid)),
                (f"activity-weather-{activity_id}", lambda aid=activity_id: client.get_activity_weather(aid)),
            ):
                target = target_dir / f"{name}.json"
                if target.exists() and not refresh:
                    status.add(EndpointStatus(name, "skipped", path=str(target)))
                    continue
                try:
                    payload = call()
                    if payload is not None:
                        save_json(target, payload)
                        status.add(EndpointStatus(name, "ok", http=200, bytes=target.stat().st_size,
                                                  path=str(target)))
                except Exception as exc:  # noqa: BLE001
                    status.add(EndpointStatus(name, "unavailable", error=f"{type(exc).__name__}: {exc}"[:300]))

        if status.endpoints and all(e.status in ("unavailable", "error", "empty") for e in status.endpoints):
            status.status = "unavailable"
        return status


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------


def fetch_sources(day: str, sources: tuple[str, ...] = ("personal", "intervals", "connect"),
                  refresh: bool = False) -> dict[str, Any]:
    """Fetch each requested source into data/daily-YYYY-MM-DD/ and return status."""
    config.ensure_dirs()
    out_dir = config.DATA_DIR / f"daily-{day}"
    out_dir.mkdir(parents=True, exist_ok=True)
    statuses: list[SourceStatus] = []

    # Read activity IDs first so Garmin Connect can enrich the session.
    activity_ids: list[int] = []
    activities_path = out_dir / "activities.json"
    if activities_path.exists():
        from .util import load_json
        payload = load_json(activities_path, {})
        for item in (payload.get("value") or []) if isinstance(payload, dict) else []:
            try:
                activity_ids.append(int(item.get("activityId")))
            except (TypeError, ValueError):
                pass

    if "personal" in sources:
        try:
            statuses.append(GarminPersonalClient().fetch_date(day, out_dir, refresh=refresh))
        except Exception as exc:  # noqa: BLE001
            statuses.append(SourceStatus("garmin_personal", "unavailable", error=str(exc)[:400]))
    if "intervals" in sources:
        try:
            statuses.append(IntervalsClient().fetch_date(day, out_dir, refresh=refresh))
        except Exception as exc:  # noqa: BLE001
            statuses.append(SourceStatus("intervals", "unavailable", error=str(exc)[:400]))
    if "connect" in sources:
        try:
            statuses.append(GarminConnectSource().fetch_date(day, out_dir, refresh=refresh,
                                                              activity_ids=activity_ids))
        except Exception as exc:  # noqa: BLE001
            statuses.append(SourceStatus("garmin_connect", "unavailable", error=str(exc)[:400]))

    status_path = out_dir / "fetch-status.json"
    previous = load_json(status_path, {}) if status_path.exists() else {}
    merged_sources = dict(previous.get("sources") or {}) if isinstance(previous, dict) else {}
    merged_sources.update({s.source: s.as_dict() for s in statuses})
    result = {
        "date": day,
        "generated_at": now_wib(),
        "sources": merged_sources,
    }
    save_json(status_path, result)
    return result
