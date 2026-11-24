"""Read-only MCP server exposing the report factory.

No write tools. No Garmin token is used by the MCP process when reading existing
packets. Fetch tools use the local credential files described in config.py.
"""

from __future__ import annotations

import json
from pathlib import Path

from . import config
from .report import (
    build_audit_packet,
    build_daily_packet,
    build_session_packet,
    build_weekly_report,
)
from .sources import fetch_sources
from .util import load_json


def _json(value) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2)


def _safe_packet(path: str) -> Path:
    candidate = Path(path).resolve()
    root = config.REPORT_DIR.resolve()
    if root not in candidate.parents and candidate != root:
        raise ValueError("Path harus berada di folder report.")
    if candidate.suffix.lower() != ".md":
        raise ValueError("Hanya file .md yang boleh dibaca.")
    if not candidate.exists():
        raise FileNotFoundError(candidate)
    return candidate


def create_server():
    try:
        from mcp.server.fastmcp import FastMCP
    except ImportError as exc:  # pragma: no cover
        raise RuntimeError("Package 'mcp' belum terpasang. Jalankan: uv sync") from exc

    mcp = FastMCP("Garmin Packet (read-only)")

    @mcp.tool()
    async def fetch_data(date: str, sources: str = "personal,intervals,connect",
                         refresh: bool = False) -> str:
        """Tarik data ke data/daily-YYYY-MM-DD/. Read-only terhadap akun Garmin."""
        parsed = tuple(x.strip().lower() for x in sources.split(",") if x.strip())
        return _json(fetch_sources(date, sources=parsed, refresh=refresh))

    @mcp.tool()
    async def generate_daily_packet(date: str, cutoff: str | None = None,
                                    redact: bool = False) -> str:
        """Buat daily analysis packet .md dan kembalikan path + ringkasan."""
        path, _content, summary = build_daily_packet(date, cutoff=cutoff, redact=redact)
        return _json({"status": "ok", "path": str(path), "bytes": path.stat().st_size, "summary": summary})

    @mcp.tool()
    async def generate_session_packet(activity_id: int, redact: bool = False) -> str:
        """Buat session analysis packet .md dari activity_id."""
        path, _content, summary = build_session_packet(activity_id, redact=redact)
        return _json({"status": "ok", "path": str(path), "bytes": path.stat().st_size, "summary": summary})

    @mcp.tool()
    async def generate_weekly_report(start: str, end: str, redact: bool = False) -> str:
        """Buat laporan mingguan lengkap .md untuk rentang tanggal."""
        path, _content, summary = build_weekly_report(start, end, redact=redact)
        return _json({"status": "ok", "path": str(path), "bytes": path.stat().st_size, "summary": summary})

    @mcp.tool()
    async def generate_audit_packet(start: str, end: str) -> str:
        """Buat audit packet .md: coverage, missing files, konflik."""
        path, _content, summary = build_audit_packet(start, end)
        return _json({"status": "ok", "path": str(path), "bytes": path.stat().st_size, "summary": summary})

    @mcp.tool()
    async def list_packets() -> str:
        """Daftar file .md di folder report."""
        items = []
        patterns = ("Garmin-Packet-*.md", "Garmin-Weekly-Report-*.md")
        seen: set[Path] = set()
        for pattern in patterns:
            for path in sorted(config.REPORT_DIR.glob(pattern)):
                if path in seen:
                    continue
                seen.add(path)
                items.append({"name": path.name, "path": str(path), "bytes": path.stat().st_size})
        return _json({"count": len(items), "packets": items})

    @mcp.tool()
    async def read_packet(path: str) -> str:
        """Baca isi packet .md. Path harus di dalam folder report."""
        safe = _safe_packet(path)
        return safe.read_text(encoding="utf-8")

    @mcp.tool()
    async def get_source_status(date: str) -> str:
        """Status fetch terakhir untuk tanggal tertentu."""
        path = config.DATA_DIR / f"daily-{date}" / "fetch-status.json"
        if not path.exists():
            return _json({"date": date, "status": "not_fetched"})
        return _json(load_json(path, {}))

    return mcp


def main() -> None:
    config.ensure_dirs()
    server = create_server()
    server.run(transport="stdio")


if __name__ == "__main__":
    main()
