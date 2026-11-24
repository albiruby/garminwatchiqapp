"""Paths and credential loading.

Everything is local to D:\\Garmin\\API-Key-Data-Fetch. No network call happens at import time.
"""

from __future__ import annotations

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = Path(os.getenv("GARMIN_PACKET_DATA_DIR", str(BASE_DIR / "data")))
REPORT_DIR = Path(os.getenv("GARMIN_PACKET_REPORT_DIR", str(BASE_DIR)))
TOKEN_DIR = Path(os.getenv("GARMINTOKENS", str(BASE_DIR / ".garmin-tokens")))
GARMIN_API_KEY_FILE = Path(
    os.getenv("GARMIN_API_KEY_FILE", str(BASE_DIR / "garmin-api-key.txt"))
)
INTERVALS_ENV_FILE = Path(
    os.getenv("INTERVALS_ENV_FILE", str(BASE_DIR / ".env"))
)
GARMIN_PERSONAL_BASE = "https://personal.connectapi.garmin.com"
INTERVALS_BASE = "https://intervals.icu/api/v1"


def _read_env_file(path: Path) -> dict[str, str]:
    """Read a simple KEY=VALUE file without touching the process environment."""
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def get_garmin_api_key() -> str:
    """Read the official Personal API key from env or the local key file."""
    key = os.getenv("GARMIN_API_KEY", "").strip()
    if key:
        return key
    if GARMIN_API_KEY_FILE.exists():
        return GARMIN_API_KEY_FILE.read_text(encoding="utf-8-sig").strip()
    raise RuntimeError(
        f"Garmin Personal API key tidak ditemukan. Set GARMIN_API_KEY atau isi {GARMIN_API_KEY_FILE}."
    )


def get_intervals_credentials() -> tuple[str, str]:
    """Return (athlete_id, api_key) from env or the local .env file."""
    env = _read_env_file(INTERVALS_ENV_FILE)
    api_key = (
        os.getenv("INTERVALS_API_KEY", "").strip()
        or env.get("INTERVALS_API_KEY", "").strip()
    )
    athlete_id = (
        os.getenv("INTERVALS_ATHLETE_ID", "").strip()
        or env.get("INTERVALS_ATHLETE_ID", "").strip()
        or "0"
    )
    if not api_key:
        raise RuntimeError(
            "Intervals.icu API key tidak ditemukan. Set INTERVALS_API_KEY atau isi "
            f"INTERVALS_API_KEY di {INTERVALS_ENV_FILE}."
        )
    return athlete_id, api_key


def ensure_dirs() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
