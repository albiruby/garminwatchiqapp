"""Command-line interface for the Garmin packet report factory."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import date as date_cls

from . import config
from .report import (
    build_audit_packet,
    build_daily_packet,
    build_session_packet,
    build_weekly_report,
)
from .sources import fetch_sources


def _sources(value: str) -> tuple[str, ...]:
    allowed = {"personal", "intervals", "connect"}
    parsed = tuple(x.strip().lower() for x in value.split(",") if x.strip())
    unknown = set(parsed) - allowed
    if unknown:
        raise argparse.ArgumentTypeError(f"source tidak dikenal: {', '.join(sorted(unknown))}")
    return parsed or ("personal", "intervals")


def _today() -> str:
    return date_cls.today().isoformat()


def cmd_fetch(args: argparse.Namespace) -> int:
    result = fetch_sources(args.date, sources=args.sources, refresh=args.refresh)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def cmd_daily(args: argparse.Namespace) -> int:
    if args.fetch:
        fetch_sources(args.date, sources=args.sources, refresh=args.refresh)
    path, _content, summary = build_daily_packet(args.date, cutoff=args.cutoff, redact=args.redact)
    print(json.dumps({
        "status": "ok",
        "path": str(path),
        "bytes": path.stat().st_size,
        "summary": summary,
    }, ensure_ascii=False, indent=2))
    return 0


def cmd_session(args: argparse.Namespace) -> int:
    path, _content, summary = build_session_packet(args.activity_id, redact=args.redact)
    print(json.dumps({
        "status": "ok",
        "path": str(path),
        "bytes": path.stat().st_size,
        "summary": summary,
    }, ensure_ascii=False, indent=2))
    return 0


def cmd_weekly(args: argparse.Namespace) -> int:
    path, _content, summary = build_weekly_report(args.start, args.end, redact=args.redact)
    print(json.dumps({
        "status": "ok",
        "path": str(path),
        "bytes": path.stat().st_size,
        "summary": summary,
    }, ensure_ascii=False, indent=2))
    return 0


def cmd_audit(args: argparse.Namespace) -> int:
    path, _content, summary = build_audit_packet(args.start, args.end)
    print(json.dumps({
        "status": "ok",
        "path": str(path),
        "bytes": path.stat().st_size,
        "summary": summary,
    }, ensure_ascii=False, indent=2))
    return 0


def cmd_all(args: argparse.Namespace) -> int:
    fetch_result = fetch_sources(args.date, sources=args.sources, refresh=args.refresh)
    path, _content, summary = build_daily_packet(args.date, cutoff=args.cutoff, redact=args.redact)
    print(json.dumps({
        "status": "ok",
        "fetch": fetch_result,
        "daily": {"path": str(path), "bytes": path.stat().st_size, "summary": summary},
    }, ensure_ascii=False, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="garmin-packet",
        description="Garmin + Intervals.icu -> self-contained Markdown analysis packet",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    fetch = sub.add_parser("fetch", help="Tarik data dari source ke data/daily-YYYY-MM-DD/")
    fetch.add_argument("--date", default=_today())
    fetch.add_argument("--sources", type=_sources, default=("personal", "intervals", "connect"))
    fetch.add_argument("--refresh", action="store_true")
    fetch.set_defaults(func=cmd_fetch)

    daily = sub.add_parser("daily", help="Buat daily packet .md")
    daily.add_argument("--date", default=_today())
    daily.add_argument("--cutoff", default=None)
    daily.add_argument("--redact", action="store_true")
    daily.add_argument("--fetch", action="store_true", help="Fetch dulu sebelum generate")
    daily.add_argument("--sources", type=_sources, default=("personal", "intervals", "connect"))
    daily.add_argument("--refresh", action="store_true")
    daily.set_defaults(func=cmd_daily)

    session = sub.add_parser("session", help="Buat session packet .md")
    session.add_argument("--activity-id", type=int, required=True)
    session.add_argument("--redact", action="store_true")
    session.set_defaults(func=cmd_session)

    weekly = sub.add_parser("weekly", help="Buat weekly packet .md")
    weekly.add_argument("--start", required=True)
    weekly.add_argument("--end", required=True)
    weekly.add_argument("--redact", action="store_true")
    weekly.set_defaults(func=cmd_weekly)

    audit = sub.add_parser("audit", help="Buat audit packet .md")
    audit.add_argument("--start", required=True)
    audit.add_argument("--end", required=True)
    audit.set_defaults(func=cmd_audit)

    all_cmd = sub.add_parser("all", help="Fetch + daily packet")
    all_cmd.add_argument("--date", default=_today())
    all_cmd.add_argument("--cutoff", default=None)
    all_cmd.add_argument("--redact", action="store_true")
    all_cmd.add_argument("--sources", type=_sources, default=("personal", "intervals", "connect"))
    all_cmd.add_argument("--refresh", action="store_true")
    all_cmd.set_defaults(func=cmd_all)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    config.ensure_dirs()
    try:
        return int(args.func(args))
    except Exception as exc:  # noqa: BLE001 - CLI boundary
        print(f"ERROR: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
