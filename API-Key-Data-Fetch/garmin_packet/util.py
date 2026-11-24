"""Small formatting/parsing helpers used by the report builder."""

from __future__ import annotations

import json
import math
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable

WIB = timezone(timedelta(hours=7))


def load_json(path: Path, default: Any = None) -> Any:
    try:
        with path.open("r", encoding="utf-8-sig") as fh:
            return json.load(fh)
    except FileNotFoundError:
        return default
    except (json.JSONDecodeError, OSError):
        return default


def save_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        json.dump(value, fh, ensure_ascii=False, indent=2)


def dig(value: Any, *keys: str, default: Any = None) -> Any:
    """Walk nested dicts/lists; return default when a key is missing."""
    current = value
    for key in keys:
        if isinstance(current, dict):
            current = current.get(key)
        elif isinstance(current, list) and key.isdigit():
            index = int(key)
            current = current[index] if 0 <= index < len(current) else None
        else:
            return default
        if current is None:
            return default
    return current


def num(value: Any) -> float | None:
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        if math.isnan(value) or math.isinf(value):
            return None
        return float(value)
    try:
        parsed = float(str(value).replace(",", "."))
    except (TypeError, ValueError):
        return None
    return None if math.isnan(parsed) or math.isinf(parsed) else parsed


def fmt_int(value: Any, suffix: str = "") -> str:
    number = num(value)
    if number is None:
        return "—"
    return f"{int(round(number)):,}".replace(",", ".") + suffix


def fmt_dec(value: Any, digits: int = 1, suffix: str = "") -> str:
    number = num(value)
    if number is None:
        return "—"
    text = f"{number:,.{digits}f}".replace(",", "X").replace(".", ",").replace("X", ".")
    return text + suffix


def fmt_hm(seconds: Any) -> str:
    number = num(seconds)
    if number is None:
        return "—"
    total = int(round(number))
    hours, minutes = divmod(total // 60, 60)
    if hours:
        return f"{hours}j {minutes:02d}m"
    return f"{minutes}m"


def fmt_hms(seconds: Any) -> str:
    number = num(seconds)
    if number is None:
        return "—"
    total = int(round(number))
    hours, rem = divmod(total, 3600)
    minutes, secs = divmod(rem, 60)
    if hours:
        return f"{hours}:{minutes:02d}:{secs:02d}"
    return f"{minutes}:{secs:02d}"


def fmt_pace(seconds_per_km: Any) -> str:
    number = num(seconds_per_km)
    if number is None or number <= 0:
        return "—"
    minutes, secs = divmod(int(round(number)), 60)
    return f"{minutes}:{secs:02d}/km"


def fmt_ms_to_pace(speed_mps: Any) -> str:
    speed = num(speed_mps)
    if speed is None or speed <= 0:
        return "—"
    return fmt_pace(1000.0 / speed)


def fmt_pct(value: Any, digits: int = 1) -> str:
    number = num(value)
    if number is None:
        return "—"
    return f"{number:.{digits}f}%".replace(".", ",")


def fmt_duration_from_ms(value: Any) -> str:
    number = num(value)
    return fmt_hm(number / 1000.0) if number is not None else "—"


def fmt_date_local(ms: Any) -> str:
    number = num(ms)
    if number is None:
        return "—"
    return datetime.fromtimestamp(number / 1000.0, tz=WIB).strftime("%Y-%m-%d %H:%M")


def fmt_iso_local(value: Any) -> str:
    if not value:
        return "—"
    text = str(value).replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return str(value)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(WIB).strftime("%Y-%m-%d %H:%M")


def now_wib() -> str:
    return datetime.now(WIB).strftime("%Y-%m-%d %H:%M WIB")


def safe_pct(part: Any, whole: Any) -> float | None:
    p, w = num(part), num(whole)
    if p is None or w is None or w == 0:
        return None
    return p / w * 100.0


def table(headers: Iterable[str], rows: Iterable[Iterable[Any]], aligns: str | None = None) -> str:
    headers = list(headers)
    rows = [list(row) for row in rows]
    if aligns is None:
        aligns = "l" + "r" * (len(headers) - 1)
    out = ["| " + " | ".join(str(h) for h in headers) + " |"]
    out.append("|" + "|".join("---:" if a == "r" else "---" for a in aligns) + "|")
    for row in rows:
        out.append("| " + " | ".join(str(cell) for cell in row) + " |")
    return "\n".join(out)


def bullet_list(items: Iterable[str]) -> str:
    return "\n".join(f"- {item}" for item in items)


def md_escape(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")
