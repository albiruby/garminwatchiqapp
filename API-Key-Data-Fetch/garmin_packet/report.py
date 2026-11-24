"""Build self-contained Markdown analysis packets for external LLMs."""

from __future__ import annotations

import json
import math
from datetime import date as date_cls, datetime, timedelta
from pathlib import Path
from typing import Any, Iterable

from . import config
from .normalize import Bundle, _normalize_activity, load_bundle, normalize_bundle
from .util import (
    WIB,
    dig,
    fmt_date_local,
    fmt_dec,
    fmt_duration_from_ms,
    fmt_hm,
    fmt_hms,
    fmt_int,
    fmt_iso_local,
    fmt_ms_to_pace,
    fmt_pace,
    fmt_pct,
    load_json,
    md_escape,
    num,
    safe_pct,
    table,
)

HARI = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]

KEY_FILES = [
    "daily-v2",
    "daily-legacy",
    "sleep",
    "heart-rate",
    "body-battery",
    "hrv",
    "spo2",
    "stress",
    "steps",
    "hydration",
    "activities",
    "hr-zones",
    "intervals-wellness",
    "intervals-wellness-7d",
]

GAP_FILES = [
    "garmin-connect/body-composition",
    "garmin-connect/weigh-ins",
    "garmin-connect/training-readiness",
    "garmin-connect/training-status",
    "garmin-connect/fitness-age",
    "garmin-connect/respiration",
    "garmin-connect/training-load-trend",
    "garmin-connect/lactate-threshold",
    "garmin-connect/cycling-ftp",
    "garmin-connect/race-predictions",
    "garmin-connect/personal-records",
    "garmin-connect/nutrition-food-log",
]


def _source_label(normalized: dict[str, Any]) -> str:
    labels = []
    if normalized["sources"]["personal"]:
        labels.append("Garmin Personal API")
    if normalized["sources"]["intervals"]:
        labels.append("Intervals.icu")
    if normalized["sources"]["garmin_connect"]:
        labels.append("Garmin Connect (gap-fill)")
    if normalized["sources"].get("session"):
        labels.append("Garmin session JSON")
    return ", ".join(labels) if labels else "tidak ada"


def _metric_row(category: str, name: str, value: str, source: str, note: str = "") -> list[str]:
    return [category, name, value, source, note]


def _zone_rows(zones: Iterable[float], bounds: list[Any], prefix: str = "Z") -> list[list[str]]:
    """Label N zones from N-1 threshold bounds; merge overflow zones into the top one."""
    clean_bounds = [int(x) for x in (num(b) for b in bounds) if x is not None]
    if not clean_bounds:
        clean_bounds = [125, 143, 161, 175, 192]
    expected = len(clean_bounds) + 1
    values = [float(x) for x in zones]
    if len(values) > expected:
        values = values[: expected - 1] + [sum(values[expected - 1:])]
    elif len(values) < expected:
        values += [0.0] * (expected - len(values))
    labels = [f"Di bawah {prefix}1 (<{clean_bounds[0]})"]
    for index in range(1, len(clean_bounds)):
        labels.append(f"{prefix}{index} ({clean_bounds[index - 1]}–{clean_bounds[index] - 1})")
    labels.append(f"{prefix}{len(clean_bounds)} (≥{clean_bounds[-1]})")
    total = sum(values) or 1.0
    return [
        [labels[i], fmt_hms(values[i]), fmt_pct(values[i] / total * 100, 1)]
        for i in range(expected)
    ]


def _fmt_value(value: Any, unit: str = "", digits: int = 1) -> str:
    if value is None:
        return "—"
    if isinstance(value, str):
        return value
    return f"{fmt_dec(value, digits)} {unit}".strip()


def _fmt_int_value(value: Any, unit: str = "") -> str:
    if value is None:
        return "—"
    return f"{fmt_int(value)} {unit}".strip()


def _session_decoupling(session: dict[str, Any] | None) -> dict[str, Any] | None:
    if not session:
        return None
    laps = [lap for lap in (session.get("laps") or []) if isinstance(lap, dict)]
    if len(laps) < 4:
        return None
    mid = len(laps) // 2
    first, second = laps[:mid], laps[mid:]

    def avg(items: list[dict[str, Any]], key: str) -> float | None:
        vals = [num(x.get(key)) for x in items if num(x.get(key)) is not None]
        return sum(vals) / len(vals) if vals else None

    hr1, hr2 = avg(first, "hr"), avg(second, "hr")
    pw1, pw2 = avg(first, "power"), avg(second, "power")
    if not all(x is not None for x in (hr1, hr2, pw1, pw2)) or hr1 == 0 or hr2 == 0:
        return None
    ratio1, ratio2 = pw1 / hr1, pw2 / hr2
    drift = (ratio2 - ratio1) / ratio1 * 100.0
    return {
        "first_half_hr": hr1,
        "second_half_hr": hr2,
        "first_half_power": pw1,
        "second_half_power": pw2,
        "ratio_first": ratio1,
        "ratio_second": ratio2,
        "drift_pct": drift,
        "interpretation": (
            "well_coupled" if abs(drift) < 5
            else "moderate_drift" if drift > -10
            else "significant_decoupling"
        ),
    }


def _activity_table(activities: list[dict[str, Any]]) -> str:
    if not activities:
        return "_Tidak ada aktivitas tercatat._"
    return table(
        ["Aktivitas", "Mulai", "Durasi", "Jarak", "Pace", "HR avg/max", "Power avg/NP", "Kalori", "TE"],
        [
            [
                md_escape(f"{a.get('name') or '—'} ({a.get('type') or '—'})"),
                a.get("start_local") or "—",
                fmt_hms(a.get("duration_s")),
                f"{fmt_dec((num(a.get('distance_m')) or 0) / 1000, 2)} km",
                fmt_pace(a.get("pace_s_per_km")),
                f"{fmt_int(a.get('avg_hr'))}/{fmt_int(a.get('max_hr'))}",
                f"{fmt_int(a.get('avg_power'))}/{fmt_int(a.get('np'))} W",
                fmt_int(a.get("calories")),
                f"{fmt_dec(a.get('aerobic_te'), 1)} / {fmt_dec(a.get('anaerobic_te'), 1)}",
            ]
            for a in activities
        ],
    )


def _activity_detail(activity: dict[str, Any], session: dict[str, Any] | None) -> str:
    lines = [
        f"### {activity.get('name') or 'Aktivitas'} — {activity.get('start_local') or '—'}",
        "",
        table(
            ["Metrik", "Nilai", "Catatan"],
            [
                ["Jarak", f"{fmt_dec((num(activity.get('distance_m')) or 0) / 1000, 2)} km", ""],
                ["Durasi timer", fmt_hms(activity.get("duration_s")), ""],
                ["Durasi moving", fmt_hms(activity.get("moving_s")), ""],
                ["Pace rata-rata", fmt_pace(activity.get("pace_s_per_km")), ""],
                ["Kecepatan avg/max", f"{fmt_dec(activity.get('avg_speed_mps'), 2)} / {fmt_dec(activity.get('max_speed_mps'), 2)} m/s", ""],
                ["HR avg/max", f"{fmt_int(activity.get('avg_hr'))} / {fmt_int(activity.get('max_hr'))} bpm", ""],
                ["Power avg/NP/max", f"{fmt_int(activity.get('avg_power'))} / {fmt_int(activity.get('np'))} / {fmt_int(activity.get('max_power'))} W", ""],
                ["Cadence avg/max", f"{fmt_dec(activity.get('avg_cadence'), 1)} / {fmt_dec(activity.get('max_cadence'), 1)} spm", ""],
                ["Stride length", _fmt_value(activity.get("stride_cm"), "cm", 1), ""],
                ["Vertical oscillation", _fmt_value(activity.get("vertical_oscillation_cm"), "cm", 2), ""],
                ["Ground contact time", _fmt_value(activity.get("ground_contact_ms"), "ms", 1), ""],
                ["Vertical ratio", _fmt_value(activity.get("vertical_ratio_pct"), "%", 2), ""],
                ["Kalori", _fmt_int_value(activity.get("calories"), "kcal"), ""],
                ["Training Effect", f"{fmt_dec(activity.get('aerobic_te'), 2)} aerobik / {fmt_dec(activity.get('anaerobic_te'), 2)} anaerobik", activity.get("te_label") or ""],
                ["Recovery time", fmt_hm((session or {}).get("recoveryTimeMin", 0) * 60) if session else "—", ""],
                ["VO2max (first → final)", f"{fmt_dec((session or {}).get('vo2', {}).get('first'), 2)} → {fmt_dec((session or {}).get('vo2', {}).get('final'), 2)}" if session else "—", ""],
                ["FTP", _fmt_int_value((session or {}).get("ftp"), "W") if session else "—", ""],
                ["Body Battery delta", _fmt_int_value(activity.get("body_battery_delta")), ""],
                ["RPE", _fmt_int_value(activity.get("rpe")), ""],
                ["Feel", activity.get("feel") or "—", ""],
                ["Suhu min/max", f"{fmt_dec(activity.get('min_temp_c'), 1)} / {fmt_dec(activity.get('max_temp_c'), 1)} °C", ""],
            ],
        ),
        "",
    ]
    laps = activity.get("laps") or []
    if laps:
        def lap_pace(lap: dict[str, Any]) -> str:
            dist = num(lap.get("dist"))
            if not dist or dist < 50:
                return "—"
            return fmt_pace(lap.get("pace")) if lap.get("pace") else "—"

        lines += [
            "#### Laps",
            "",
            table(
                ["Lap", "Tipe", "Jarak (m)", "Waktu", "Pace", "HR avg/max", "Power", "Cadence"],
                [
                    [
                        lap.get("n"),
                        lap.get("kind") or "—",
                        fmt_int(lap.get("dist")),
                        fmt_hms(lap.get("timer")),
                        lap_pace(lap),
                        f"{fmt_int(lap.get('hr'))}/{fmt_int(lap.get('hrMax'))}",
                        _fmt_int_value(lap.get("power"), "W"),
                        fmt_dec(lap.get("cadence"), 0),
                    ]
                    for lap in laps
                ],
            ),
            "",
        ]
    zones_hr = activity.get("zones_hr")
    if isinstance(zones_hr, list) and zones_hr:
        bounds = activity.get("zones_hr_bounds") or [125, 143, 161, 175, 192]
        lines += [
            "#### HR zones (sesi)",
            "",
            table(["Zona", "Waktu", "%"], _zone_rows(zones_hr, bounds)),
            "",
        ]
    zones_power = activity.get("zones_power")
    if isinstance(zones_power, list) and zones_power:
        bounds = activity.get("zones_power_bounds") or []
        lines += [
            "#### Power zones (sesi)",
            "",
            table(["Zona", "Waktu", "%"], _zone_rows(zones_power, bounds, prefix="P")),
            "",
        ]
    decoupling = _session_decoupling(session)
    if decoupling:
        lines += [
            "#### Cardiac decoupling (dari laps)",
            "",
            table(
                ["Metrik", "Nilai"],
                [
                    ["HR half 1 / half 2", f"{fmt_dec(decoupling['first_half_hr'], 1)} / {fmt_dec(decoupling['second_half_hr'], 1)} bpm"],
                    ["Power half 1 / half 2", f"{fmt_dec(decoupling['first_half_power'], 1)} / {fmt_dec(decoupling['second_half_power'], 1)} W"],
                    ["Power:HR ratio 1 / 2", f"{fmt_dec(decoupling['ratio_first'], 3)} / {fmt_dec(decoupling['ratio_second'], 3)}"],
                    ["Drift", fmt_pct(decoupling["drift_pct"], 2)],
                    ["Interpretasi", decoupling["interpretation"]],
                ],
            ),
            "",
        ]
    return "\n".join(lines)


def _baseline_rows(intervals_7d: list[dict[str, Any]]) -> list[list[str]]:
    rows = []
    for item in intervals_7d:
        if not isinstance(item, dict):
            continue
        ctl, atl = num(item.get("ctl")), num(item.get("atl"))
        rows.append([
            item.get("id") or "—",
            fmt_dec(ctl, 1),
            fmt_dec(atl, 1),
            fmt_dec((ctl - atl) if ctl is not None and atl is not None else None, 1),
            fmt_int(item.get("restingHR")),
            fmt_dec(item.get("hrv"), 1),
            fmt_hm(item.get("sleepSecs")),
            fmt_dec(item.get("weight"), 1),
            fmt_int(item.get("steps")),
        ])
    return rows


def _avg(values: Iterable[Any]) -> float | None:
    nums = [num(v) for v in values if num(v) is not None]
    return sum(nums) / len(nums) if nums else None


def _quality_section(normalized: dict[str, Any], bundle: Bundle) -> str:
    raw_missing = normalized["coverage"].get("missing_files") or []
    missing = [m for m in raw_missing if m in KEY_FILES]
    lines = [
        "## 11. Data quality & conflicts",
        "",
        table(
            ["Cek", "Hasil", "Status"],
            [
                ["Data berakhir", normalized["coverage"].get("data_end") or "—", "⚠ parsial" if normalized["coverage"].get("partial_day") else "✅"],
                ["File wajib hilang", ", ".join(missing) or "tidak ada", "⚠" if missing else "✅"],
                ["Sumber", _source_label(normalized), ""],
                ["Aktivitas", str(len(normalized.get("activities") or [])), ""],
                ["HR samples", fmt_int(normalized["heart_rate"].get("sample_count")), ""],
                ["Konflik antar-source", str(len(normalized.get("conflicts") or [])), "⚠" if normalized.get("conflicts") else "✅"],
            ],
        ),
        "",
    ]
    conflicts = normalized.get("conflicts") or []
    if conflicts:
        lines += [
            "### Cross-source conflicts",
            "",
            table(
                ["Metrik", "Sumber A", "Sumber B", "Delta", "Ambang", "Severity"],
                [
                    [
                        c["metric"],
                        fmt_dec(c["a"], 2),
                        fmt_dec(c["b"], 2),
                        f"{fmt_dec(c['delta'], 2)} {c['unit']}",
                        fmt_dec(c["threshold"], 2),
                        c["severity"],
                    ]
                    for c in conflicts
                ],
            ),
            "",
            "> Nilai di atas adalah perbedaan antar-source. Jangan dirata-ratakan tanpa memahami definisi masing-masing sumber.",
            "",
        ]
    status = normalized["coverage"].get("fetch_status") or {}
    sources = status.get("sources") if isinstance(status, dict) else None
    if sources:
        lines += [
            "### Source fetch status",
            "",
            table(
                ["Source", "Status", "Error"],
                [[name, s.get("status", "—"), s.get("error") or "—"] for name, s in sources.items()],
            ),
            "",
        ]
    gap_present = []
    gap_missing = []
    for name in GAP_FILES:
        path = bundle.out_dir / f"{name}.json"
        (gap_present if path.exists() else gap_missing).append(name)
    lines += [
        "### Gap-fill Garmin Connect",
        "",
        f"- Tersedia: {', '.join(gap_present) if gap_present else '—'}",
        f"- Tidak tersedia: {', '.join(gap_missing) if gap_missing else '—'}",
        "",
    ]
    return "\n".join(lines)


def _definitions_section(number: int = 12) -> str:
    return "\n".join([
        f"## {number}. Definitions",
        "",
        "| Istilah | Definisi |",
        "|---|---|",
        "| RHR | Resting heart rate, rata-rata HR saat istirahat menurut Garmin. |",
        "| HRV | Heart rate variability malam, biasanya RMSSD dalam ms. Baseline Garmin adalah rentang balanced. |",
        "| Body Battery | Estimasi energi 0–100 dari Garmin, bukan ukuran medis. |",
        "| SpO₂ | Saturasi oksigen perifer dari sensor optik; akurasi lebih rendah dari pulse oximeter medis. |",
        "| CTL | Chronic Training Load, beban latihan jangka panjang (biasanya 42 hari). |",
        "| ATL | Acute Training Load, beban latihan jangka pendek (biasanya 7 hari). |",
        "| TSB / Form | CTL − ATL. Negatif berarti beban akut di atas kronis. |",
        "| Ramp rate | Perubahan CTL per minggu; naik terlalu cepat meningkatkan risiko. |",
        "| Training Effect | Estimasi Garmin atas dampak aerobik/anaerobik sesi. |",
        "| Decoupling | Perubahan rasio power:HR (atau pace:HR) antara paruh pertama dan kedua sesi. |",
        "| Sleep efficiency | Waktu tidur / (waktu tidur + awake). |",
        "| Monotony | Rata-rata beban harian / SD beban harian dalam seminggu (Foster). |",
        "| Strain | Beban mingguan × monotony (Foster); unit arbitrer, bukan kalori. |",
        "",
        "> Semua angka adalah estimasi perangkat/algoritma, bukan pengukuran laboratorium.",
    ])


def _analysis_request(number: int = 13) -> str:
    return "\n".join([
        f"## {number}. Analysis request",
        "",
        "Gunakan **hanya data di atas**. Jangan mengarang data yang tidak ada. Jika ada data yang hilang, sebutkan dan jelaskan bagaimana hal itu membatasi kesimpulan.",
        "",
        "Jawab pertanyaan berikut:",
        "",
        "1. Apa 3 temuan paling penting dari hari ini, dan mengapa?",
        "2. Apakah beban latihan (CTL/ATL/TSB) dan recovery (HRV, RHR, sleep, Body Battery) konsisten?",
        "3. Apakah ada tanda overreaching, under-recovery, atau datanya terlalu parsial untuk dinilai?",
        "4. Apa yang perlu dipantau 48–72 jam ke depan?",
        "5. Data tambahan apa yang paling bernilai untuk memperkuat analisis?",
        "",
        "Format jawaban: ringkas, berbasis angka, pisahkan fakta vs interpretasi, dan beri confidence level.",
    ])


def build_daily_packet(day: str, cutoff: str | None = None, redact: bool = False) -> tuple[Path, str, dict[str, Any]]:
    bundle = load_bundle(day)
    n = normalize_bundle(bundle)
    summary = n["summary"]
    sleep = n["sleep"]
    hrv = n["hrv"]
    hr = n["heart_rate"]
    stress = n["stress"]
    bb = n["body_battery"]
    spo2 = n["spo2"]
    resp = n["respiration"]
    steps = n["steps"]
    hydration = n["hydration"]
    intervals = n["intervals"]
    connect = n["connect"]
    activities = n["activities"]
    if redact:
        activities = [
            {**a, "name": f"Aktivitas {a.get('type') or ''}".strip()}
            for a in activities
        ]

    lines: list[str] = []
    lines += [
        f"# Garmin Analysis Packet — {day}",
        "",
        f"**Atlet:** {'—' if redact else 'Albireo'}  ",
        f"**Tanggal:** {day} (WIB)  ",
        f"**Cutoff:** {cutoff or 'tidak ditentukan'}  ",
        f"**Dibuat:** {datetime.now(WIB).strftime('%Y-%m-%d %H:%M WIB')}  ",
        f"**Sumber:** {_source_label(n)}  ",
        f"**Data berakhir:** {n['coverage'].get('data_end') or '—'}  ",
        f"**Status:** {'parsial' if n['coverage'].get('partial_day') else 'lengkap untuk hari yang tersedia'}",
        "",
        "> Paket ini dibuat untuk dianalisis LLM eksternal (ChatGPT/Gemini). Isinya data mentah yang dinormalisasi, bukan kesimpulan otomatis. Semua tabel menyertakan satuan dan sumber bila tersedia.",
        "",
        "## 1. Ringkasan data",
        "",
        table(
            ["Kategori", "Metrik", "Nilai", "Sumber", "Catatan"],
            [
                _metric_row("Tidur", "Durasi", fmt_hm(sleep.get("sleep_s")), "Garmin", f"skor {sleep.get('score') or '—'}"),
                _metric_row("Tidur", "Tahapan", f"Deep {fmt_hm(sleep.get('deep_s'))} · Light {fmt_hm(sleep.get('light_s'))} · REM {fmt_hm(sleep.get('rem_s'))}", "Garmin", f"efisiensi {fmt_pct(sleep.get('efficiency'))}"),
                _metric_row("Tidur", "Nap", fmt_hm(sleep.get("nap_s")), "Garmin", f"{len(sleep.get('naps') or [])} nap"),
                _metric_row("Jantung", "RHR", f"{fmt_int(summary.get('resting_hr'))} bpm", "Garmin/Intervals", f"Intervals {fmt_int(intervals.get('resting_hr'))}"),
                _metric_row("Jantung", "HR min/maks", f"{fmt_int(summary.get('min_hr'))} / {fmt_int(summary.get('max_hr'))} bpm", "Garmin", ""),
                _metric_row("Jantung", "HRV", f"{fmt_int(hrv.get('last_night_avg'))} ms", "Garmin", hrv.get("status") or "—"),
                _metric_row("Aktivitas", "Jumlah", str(len(activities)), "Garmin", ""),
                _metric_row("Kalori", "Total/aktif/istirahat", f"{fmt_int(summary.get('calories_total'))} / {fmt_int(summary.get('calories_active'))} / {fmt_int(summary.get('calories_resting'))} kcal", "Garmin", ""),
                _metric_row("Gerak", "Langkah/jarak", f"{fmt_int(summary.get('steps'))} / {fmt_dec((num(summary.get('distance_m')) or 0) / 1000, 2)} km", "Garmin", f"goal {fmt_int(steps.get('goal'))}"),
                _metric_row("Stres", "Rata-rata/maks", f"{fmt_int(stress.get('avg'))} / {fmt_int(stress.get('max'))}", "Garmin", stress.get("qualifier") or "—"),
                _metric_row("Body Battery", "Terkini/min–maks", f"{fmt_int(bb.get('latest'))} / {fmt_int(bb.get('min'))}–{fmt_int(bb.get('max'))}", "Garmin", f"charged +{fmt_int(bb.get('charged'))} / drained −{fmt_int(bb.get('drained'))}"),
                _metric_row("SpO₂", "Rata-rata/min/tidur", f"{fmt_int(spo2.get('avg'))}% / {fmt_int(spo2.get('min'))}% / {fmt_int(spo2.get('sleep_avg'))}%", "Garmin", ""),
                _metric_row("Napas", "Rata-rata/min–maks", f"{fmt_int(resp.get('avg'))} / {fmt_int(resp.get('min'))}–{fmt_int(resp.get('max'))}", "Garmin", "napas/menit"),
                _metric_row("Hidrasi", "Air", f"{fmt_int(hydration.get('consumed_ml'))} / {fmt_int(hydration.get('goal_ml'))} ml", "Garmin", ""),
                _metric_row("Berat", "Berat", _fmt_value(connect["body_composition"].get("weight_kg") or intervals.get("weight_kg"), "kg", 1), connect["body_composition"].get("weight_source") or "Intervals.icu", ""),
                _metric_row("Load", "CTL/ATL/TSB", f"{fmt_dec(intervals.get('ctl'), 1)} / {fmt_dec(intervals.get('atl'), 1)} / {fmt_dec(intervals.get('tsb'), 1)}", "Intervals.icu", f"ramp {fmt_dec(intervals.get('ramp'), 2)}"),
            ],
        ),
        "",
    ]

    lines += [
        "## 2. Tidur",
        "",
        table(
            ["Metrik", "Nilai", "Catatan"],
            [
                ["Mulai tidur", sleep.get("start") or "—", ""],
                ["Bangun", sleep.get("end") or "—", ""],
                ["Durasi tidur", fmt_hm(sleep.get("sleep_s")), f"{fmt_dec((num(sleep.get('sleep_s')) or 0) / 3600, 2)} jam"],
                ["Di tempat tidur", fmt_hm((num(sleep.get("sleep_s")) or 0) + (num(sleep.get("awake_s")) or 0)), "termasuk awake"],
                ["Efisiensi", fmt_pct(sleep.get("efficiency")), ""],
                ["Deep", f"{fmt_hm(sleep.get('deep_s'))} ({fmt_pct(sleep.get('deep_pct'))})", ""],
                ["Light", f"{fmt_hm(sleep.get('light_s'))} ({fmt_pct(sleep.get('light_pct'))})", ""],
                ["REM", f"{fmt_hm(sleep.get('rem_s'))} ({fmt_pct(sleep.get('rem_pct'))})", ""],
                ["Awake", fmt_hm(sleep.get("awake_s")), f"{fmt_int(sleep.get('awake_count'))} kali bangun"],
                ["Skor tidur", f"{fmt_int(sleep.get('score'))} / 100", sleep.get("score_qualifier") or ""],
                ["Feedback", sleep.get("feedback") or "—", sleep.get("insight") or ""],
                ["Kebutuhan tidur", f"{fmt_hm((num(sleep.get('need_actual_min')) or 0) * 60)}", f"baseline {fmt_hm((num(sleep.get('need_baseline_min')) or 0) * 60)}"],
                ["Kebutuhan besok", f"{fmt_hm((num(sleep.get('next_need_actual_min')) or 0) * 60)}", sleep.get("next_need_feedback") or ""],
                ["HR tidur", f"{fmt_int(sleep.get('avg_hr'))} bpm", f"SpO₂ {fmt_int(sleep.get('avg_spo2'))}%"],
                ["Napas tidur", f"{fmt_dec(sleep.get('avg_respiration'), 1)} /mnt", f"min {fmt_dec(sleep.get('lowest_respiration'), 1)} · maks {fmt_dec(sleep.get('highest_respiration'), 1)}"],
                ["Stress tidur", fmt_int(sleep.get("avg_stress")), ""],
                ["Breathing disruption", sleep.get("breathing_disruption") or "—", ""],
            ],
        ),
        "",
    ]
    if sleep.get("naps"):
        lines += [
            "### Nap",
            "",
            table(
                ["Mulai (WIB)", "Durasi", "Feedback"],
                [
                    [fmt_iso_local(n.get("start_utc")), fmt_hm(n.get("seconds")), n.get("feedback") or "—"]
                    for n in sleep["naps"]
                ],
            ),
            "",
        ]

    lines += [
        "## 3. Heart rate & HRV",
        "",
        table(
            ["Metrik", "Nilai"],
            [
                ["RHR", f"{fmt_int(summary.get('resting_hr'))} bpm"],
                ["HR min/maks harian", f"{fmt_int(hr.get('min'))} / {fmt_int(hr.get('max'))} bpm"],
                ["Sampel HR", f"{fmt_int(hr.get('sample_count'))} titik"],
                ["Zona HR", " · ".join(str(x) for x in hr.get("bounds") or [])],
                ["HRV malam", f"{fmt_int(hrv.get('last_night_avg'))} ms"],
                ["HRV 7-hari", f"{fmt_int(hrv.get('weekly_avg'))} ms"],
                ["HRV 5-min tertinggi", f"{fmt_int(hrv.get('five_min_high'))} ms"],
                ["Status HRV", hrv.get("status") or "—"],
                ["Baseline HRV", f"{fmt_int((hrv.get('baseline') or {}).get('balancedLow'))}–{fmt_int((hrv.get('baseline') or {}).get('balancedUpper'))} ms"],
            ],
        ),
        "",
        "### HR per jam",
        "",
        table(
            ["Jam", "Sampel", "Rata-rata", "Min", "Maks"],
            [[r["hour"], r["samples"], fmt_int(r["avg"]), r["min"], r["max"]] for r in hr.get("hourly") or []],
        ),
        "",
        "### Zona HR harian (dari sampel)",
        "",
        table(["Zona", "Waktu", "%"], _zone_rows(hr.get("zones_s") or [], hr.get("bounds") or [125, 143, 161, 175, 192])),
        "",
    ]

    lines += [
        "## 4. Stres & Body Battery",
        "",
        table(
            ["Metrik", "Nilai"],
            [
                ["Stres rata-rata", fmt_int(stress.get("avg"))],
                ["Stres maksimum", fmt_int(stress.get("max"))],
                ["Qualifier", stress.get("qualifier") or "—"],
                ["Rest / aktivitas", f"{fmt_hm(stress.get('rest_s'))} / {fmt_hm(stress.get('activity_s'))}"],
                ["Low / medium / high", f"{fmt_hm(stress.get('low_s'))} / {fmt_hm(stress.get('medium_s'))} / {fmt_hm(stress.get('high_s'))}"],
                ["Tidak terkategori", fmt_hm(stress.get("uncategorized_s"))],
                ["Body Battery terkini", fmt_int(bb.get("latest"))],
                ["Body Battery min–maks", f"{fmt_int(bb.get('min'))}–{fmt_int(bb.get('max'))}"],
                ["Charged / drained", f"+{fmt_int(bb.get('charged'))} / −{fmt_int(bb.get('drained'))}"],
                ["Saat tidur / bangun", f"{fmt_int(bb.get('during_sleep'))} / {fmt_int(bb.get('at_wake'))}"],
            ],
        ),
        "",
    ]
    events = bb.get("events") or []
    if events:
        lines += [
            "### Event Body Battery",
            "",
            table(
                ["Waktu lokal", "Event", "Dampak", "Feedback"],
                [
                    [
                        fmt_iso_local(e.get("eventStartTimeLocal") or e.get("eventStartTimeGmt")),
                        e.get("eventType") or "—",
                        f"{'+' if (num(e.get('bodyBatteryImpact')) or 0) > 0 else ''}{fmt_int(e.get('bodyBatteryImpact'))}",
                        e.get("shortFeedback") or e.get("feedbackType") or "—",
                    ]
                    for e in events
                ],
            ),
            "",
        ]
    series = bb.get("series") or []
    if series:
        series_rows = []
        for item in series:
            if isinstance(item, list) and len(item) >= 2 and num(item[1]) is not None:
                try:
                    label = datetime.fromtimestamp(item[0] / 1000.0, tz=WIB).strftime("%Y-%m-%d %H:%M")
                except (TypeError, ValueError, OSError):
                    label = str(item[0])
                series_rows.append([label, fmt_int(item[1])])
        if series_rows:
            lines += ["### Body Battery series", "", table(["Waktu", "Body Battery"], series_rows), ""]

    lines += [
        "## 5. SpO₂ & pernapasan",
        "",
        table(
            ["Metrik", "Nilai"],
            [
                ["SpO₂ rata-rata", f"{fmt_int(spo2.get('avg'))}%"],
                ["SpO₂ terendah", f"{fmt_int(spo2.get('min'))}%"],
                ["SpO₂ terkini", f"{fmt_int(spo2.get('latest'))}%"],
                ["SpO₂ tidur", f"{fmt_int(spo2.get('sleep_avg'))}%"],
                ["SpO₂ 7-hari", f"{fmt_dec(spo2.get('seven_day_avg'), 2)}%"],
                ["Respirasi rata-rata", f"{fmt_int(resp.get('avg'))} napas/mnt"],
                ["Respirasi min–maks", f"{fmt_int(resp.get('min'))}–{fmt_int(resp.get('max'))}"],
                ["Respirasi tidur", f"{fmt_int(resp.get('sleep_avg'))} (min {fmt_int(resp.get('sleep_min'))}, maks {fmt_int(resp.get('sleep_max'))})"],
            ],
        ),
        "",
    ]
    hourly_spo2 = spo2.get("hourly") or []
    if hourly_spo2:
        rows = []
        for item in hourly_spo2:
            if isinstance(item, list) and len(item) >= 2:
                ts, value = item[0], item[1]
                if num(value) is None:
                    continue
                try:
                    label = datetime.fromtimestamp(ts / 1000.0, tz=WIB).strftime("%H:%M")
                except (TypeError, ValueError, OSError):
                    label = str(ts)
                rows.append([label, f"{fmt_int(value)}%"])
        if rows:
            lines += ["### SpO₂ per jam", "", table(["Jam", "SpO₂"], rows), ""]

    lines += [
        "## 6. Training load & recovery",
        "",
        table(
            ["Metrik", "Nilai", "Sumber", "Catatan"],
            [
                ["CTL", fmt_dec(intervals.get("ctl"), 2), "Intervals.icu", ""],
                ["ATL", fmt_dec(intervals.get("atl"), 2), "Intervals.icu", ""],
                ["TSB / form", fmt_dec(intervals.get("tsb"), 2), "Intervals.icu", "negatif = beban akut tinggi"],
                ["Ramp rate", fmt_dec(intervals.get("ramp"), 2), "Intervals.icu", ""],
                ["eFTP run", _fmt_int_value(intervals.get("eftp_run"), "W"), "Intervals.icu", ""],
                ["eFTP ride", _fmt_int_value(intervals.get("eftp_ride"), "W"), "Intervals.icu", ""],
                ["Training readiness", _fmt_int_value((connect.get("readiness") or {}).get("score")), "Garmin Connect", (connect.get("readiness") or {}).get("level") or "—"],
                ["Training status", (connect.get("training_status") or {}).get("trainingStatus") or "—", "Garmin Connect", ""],
                ["Fitness age", _fmt_value((connect.get("fitness_age") or {}).get("fitnessAge"), "tahun", 1), connect.get("fitness_age_source") or "Garmin Connect", ""],
                ["Lactate threshold", json.dumps(connect.get("lactate_threshold"), ensure_ascii=False)[:180] if connect.get("lactate_threshold") else "—", "Garmin Connect", ""],
                ["Cycling FTP", _fmt_int_value(connect.get("cycling_ftp")), "Garmin Connect", ""],
            ],
        ),
        "",
    ]

    lines += [
        "## 7. Aktivitas",
        "",
        _activity_table(activities),
        "",
    ]
    if activities:
        cross_rows = []
        for a in activities:
            a_max = num(a.get("max_hr"))
            d_max = num(summary.get("max_hr"))
            a_cal = num(a.get("calories"))
            d_active = num(summary.get("calories_active"))
            cross_rows.append([
                a.get("name") or "—",
                fmt_int(a_max),
                fmt_int(d_max),
                f"{fmt_int((a_max or 0) - (d_max or 0))}" if a_max is not None and d_max is not None else "—",
                fmt_int(a_cal),
                fmt_int(d_active),
                f"{fmt_int((a_cal or 0) - (d_active or 0))}" if a_cal is not None and d_active is not None else "—",
            ])
        lines += [
            "### Cross-check aktivitas vs daily summary",
            "",
            table(
                ["Aktivitas", "Max HR (activity)", "Max HR (daily)", "Delta", "Kalori activity", "Kalori aktif daily", "Delta"],
                cross_rows,
            ),
            "",
            "> Delta max HR dan kalori bukan error: Garmin menghitung activity dan daily summary lewat agregasi berbeda. Gunakan activity untuk analisis sesi dan daily summary untuk total hari.",
            "",
        ]
        lines += [_activity_detail(activities[0], n.get("session")), ""]

    settings = n.get("user_settings") or {}
    activity = activities[0] if activities else {}
    altitude = dig(n.get("daily_v2"), "pulseOx", "avgAltitudeInMeters")
    lines += [
        "### Environment & konteks perangkat",
        "",
        table(
            ["Metrik", "Nilai", "Sumber"],
            [
                ["Suhu aktivitas min/max", f"{fmt_dec(activity.get('min_temp_c'), 1)} / {fmt_dec(activity.get('max_temp_c'), 1)} °C", "Garmin activity"],
                ["Altitude rata-rata", _fmt_int_value(altitude, "m"), "Garmin daily"],
                ["Measurement system", settings.get("measurementSystem") or "—", "Garmin profile"],
                ["Timezone", settings.get("timeZone") or "—", "Garmin profile"],
                ["Kelembapan / heat index / AQI", "tidak tersedia", "butuh sumber eksternal"],
            ],
        ),
        "",
        f"> Suhu berasal dari sensor aktivitas; untuk treadmill bisa bukan suhu ruangan. Timezone profil Garmin: {settings.get('timeZone') or '—'}; laporan memakai WIB (UTC+7), offset sama. Kelembapan, heat index, dan AQI memerlukan sumber eksternal (Open-Meteo/OpenAQ) dan tidak termasuk dalam packet ini.",
        "",
    ]

    body = connect["body_composition"]
    body_weight = body.get("weight_kg") or intervals.get("weight_kg")
    body_weight_source = body.get("weight_source") or ("Intervals.icu" if intervals.get("weight_kg") is not None else "—")
    lines += [
        "## 8. Body composition & berat",
        "",
        table(
            ["Metrik", "Nilai", "Sumber"],
            [
                ["Berat", _fmt_value(body_weight, "kg", 2), body_weight_source],
                ["Body fat", _fmt_value(body.get("fat_pct"), "%", 1), "Garmin Connect"],
                ["Muscle mass", _fmt_value(body.get("muscle_kg"), "kg", 2), "Garmin Connect"],
                ["Bone mass", _fmt_value(body.get("bone_kg"), "kg", 2), "Garmin Connect"],
                ["Hydration", _fmt_value(body.get("hydration_pct"), "%", 1), "Garmin Connect"],
                ["Visceral fat", _fmt_value(body.get("visceral"), "", 1), "Garmin Connect"],
                ["BMI", _fmt_value(body.get("bmi"), "", 1), "Garmin Connect"],
                ["Berat (Intervals)", _fmt_value(intervals.get("weight_kg"), "kg", 2), "Intervals.icu"],
            ],
        ),
        "",
        "> " + (
            "Berat dari endpoint weight Garmin Personal API."
            if body.get("weight_source") == "Garmin Personal API"
            else "Berat dari Garmin Connect."
            if body.get("weight_source") == "Garmin Connect"
            else "Berat dari Intervals.icu; endpoint weight Garmin tidak tersedia untuk tanggal ini."
        ) + " Angka bisa berasal dari waktu sync yang berbeda.",
        "",
    ]

    lines += [
        "## 9. Nutrisi & hidrasi",
        "",
        table(
            ["Metrik", "Nilai", "Sumber"],
            [
                ["Air diminum", f"{fmt_int(hydration.get('consumed_ml'))} / {fmt_int(hydration.get('goal_ml'))} ml", "Garmin"],
                ["Kalori masuk", _fmt_int_value((connect.get("nutrition_food_log") or {}).get("totalCalories") if isinstance(connect.get("nutrition_food_log"), dict) else None, "kcal"), "Garmin Connect"],
                ["Food log", "tersedia" if connect.get("nutrition_food_log") else "tidak tersedia", "Garmin Connect"],
                ["Meals", "tersedia" if connect.get("nutrition_meals") else "tidak tersedia", "Garmin Connect"],
            ],
        ),
        "",
        "> Nutrisi hanya terisi jika food log di Garmin Connect diisi. Kalau tidak, bagian ini tidak bisa dipakai untuk audit energy availability.",
        "",
    ]

    baseline = n.get("intervals_7d") or []
    baseline_prev = [x for x in baseline if str(x.get("id")) != day]
    history = n.get("history_baseline") or []
    lines += [
        "## 10. Baseline",
        "",
        "### 10.1 7 hari (Intervals.icu)",
        "",
        table(
            ["Tanggal", "CTL", "ATL", "TSB", "RHR", "HRV", "Tidur", "Berat", "Langkah"],
            _baseline_rows(baseline),
        ),
        "",
        table(
            ["Rata-rata 6 hari sebelumnya", "Nilai"],
            [
                ["CTL", fmt_dec(_avg([x.get("ctl") for x in baseline_prev]), 2)],
                ["ATL", fmt_dec(_avg([x.get("atl") for x in baseline_prev]), 2)],
                ["TSB", fmt_dec(_avg([(num(x.get("ctl")) or 0) - (num(x.get("atl")) or 0) for x in baseline_prev]), 2)],
                ["RHR", fmt_dec(_avg([x.get("restingHR") for x in baseline_prev]), 1)],
                ["HRV", fmt_dec(_avg([x.get("hrv") for x in baseline_prev]), 1)],
                ["Tidur", fmt_hm(_avg([x.get("sleepSecs") for x in baseline_prev]))],
                ["Berat", fmt_dec(_avg([x.get("weight") for x in baseline_prev]), 2)],
            ],
        ),
        "",
        "### 10.2 28/90 hari (Garmin daily-summary history)",
        "",
    ]
    if history:
        hist_rows = []
        for h in history:
            if h["window_days"] < 28:
                continue
            coverage = h["days_available"] / h["window_days"] if h["window_days"] else 0
            confidence = "tinggi" if coverage >= 0.8 else "sedang" if coverage >= 0.5 else "rendah"
            hist_rows.append([
                f"{h['window_days']} hari",
                h["days_available"],
                confidence,
                fmt_dec(h["metrics"].get("resting_hr"), 1),
                fmt_int(h["metrics"].get("steps")),
                fmt_int(h["metrics"].get("calories_total")),
                fmt_int(h["metrics"].get("calories_active")),
                fmt_dec(h["metrics"].get("stress_avg"), 1),
                fmt_dec(h["metrics"].get("bb_latest"), 1),
                fmt_dec(h["metrics"].get("spo2"), 1),
                fmt_dec(h["metrics"].get("respiration"), 1),
            ])
        lines += [
            table(
                ["Window", "Hari tersedia", "Confidence", "RHR", "Langkah", "Kalori total", "Kalori aktif", "Stres", "BB akhir", "SpO₂", "Napas"],
                hist_rows,
            ),
            "",
            "**Delta hari ini vs baseline:**",
            "",
            table(
                ["Metrik", "Hari ini", "28 hari", "Delta 28d", "90 hari", "Delta 90d"],
                [
                    [
                        "RHR",
                        fmt_int(n["summary"].get("resting_hr")),
                        fmt_dec(history[1]["metrics"].get("resting_hr"), 1) if len(history) > 1 else "—",
                        fmt_dec((num(n["summary"].get("resting_hr")) or 0) - (num(history[1]["metrics"].get("resting_hr")) or 0), 1) if len(history) > 1 and history[1]["metrics"].get("resting_hr") else "—",
                        fmt_dec(history[2]["metrics"].get("resting_hr"), 1) if len(history) > 2 else "—",
                        fmt_dec((num(n["summary"].get("resting_hr")) or 0) - (num(history[2]["metrics"].get("resting_hr")) or 0), 1) if len(history) > 2 and history[2]["metrics"].get("resting_hr") else "—",
                    ],
                    [
                        "Langkah",
                        fmt_int(n["summary"].get("steps")),
                        fmt_int(history[1]["metrics"].get("steps")) if len(history) > 1 else "—",
                        fmt_int((num(n["summary"].get("steps")) or 0) - (num(history[1]["metrics"].get("steps")) or 0)) if len(history) > 1 and history[1]["metrics"].get("steps") else "—",
                        fmt_int(history[2]["metrics"].get("steps")) if len(history) > 2 else "—",
                        fmt_int((num(n["summary"].get("steps")) or 0) - (num(history[2]["metrics"].get("steps")) or 0)) if len(history) > 2 and history[2]["metrics"].get("steps") else "—",
                    ],
                    [
                        "Kalori aktif",
                        fmt_int(n["summary"].get("calories_active")),
                        fmt_int(history[1]["metrics"].get("calories_active")) if len(history) > 1 else "—",
                        fmt_int((num(n["summary"].get("calories_active")) or 0) - (num(history[1]["metrics"].get("calories_active")) or 0)) if len(history) > 1 and history[1]["metrics"].get("calories_active") else "—",
                        fmt_int(history[2]["metrics"].get("calories_active")) if len(history) > 2 else "—",
                        fmt_int((num(n["summary"].get("calories_active")) or 0) - (num(history[2]["metrics"].get("calories_active")) or 0)) if len(history) > 2 and history[2]["metrics"].get("calories_active") else "—",
                    ],
                    [
                        "Stres",
                        fmt_int(n["summary"].get("stress_avg")),
                        fmt_dec(history[1]["metrics"].get("stress_avg"), 1) if len(history) > 1 else "—",
                        fmt_dec((num(n["summary"].get("stress_avg")) or 0) - (num(history[1]["metrics"].get("stress_avg")) or 0), 1) if len(history) > 1 and history[1]["metrics"].get("stress_avg") else "—",
                        fmt_dec(history[2]["metrics"].get("stress_avg"), 1) if len(history) > 2 else "—",
                        fmt_dec((num(n["summary"].get("stress_avg")) or 0) - (num(history[2]["metrics"].get("stress_avg")) or 0), 1) if len(history) > 2 and history[2]["metrics"].get("stress_avg") else "—",
                    ],
                ],
            ),
            "",
            "> Baseline 28/90 hari dihitung dari `data/hr-history/daily-summaries-*.json` dan tidak memasukkan hari ini. Metrik yang tidak ada di history (HRV, tidur, berat) hanya tersedia di baseline 7 hari Intervals.",
            "",
        ]
    else:
        lines += ["_Baseline history tidak tersedia._", ""]

    lines += [_quality_section(n, bundle), ""]
    lines += [_definitions_section(), ""]
    lines += [_analysis_request(), ""]

    lines += [
        "## 14. Lampiran file",
        "",
        f"- Folder data: `{config.DATA_DIR / f'daily-{day}'}`",
        f"- File wajib: {', '.join(KEY_FILES)}",
        f"- File gap-fill: {', '.join(GAP_FILES)}",
        f"- Session: `{config.BASE_DIR / 'sessions' / str((activities[0] or {}).get('activity_id') or '')}`" if activities else "- Session: —",
        "",
        "*Dibuat oleh garmin_packet. Data mentah tetap di folder data; laporan ini tidak memuat API key/token.*",
    ]

    content = "\n".join(lines)
    path = config.REPORT_DIR / f"Garmin-Packet-{day}.md"
    path.write_text(content, encoding="utf-8")
    return path, content, summary


def _find_activity_date(activity_id: int) -> tuple[str | None, dict[str, Any] | None]:
    for out_dir in sorted(config.DATA_DIR.glob("daily-*")):
        day = out_dir.name.replace("daily-", "", 1)
        activities = load_json(out_dir / "activities.json", {})
        items = activities.get("value") if isinstance(activities, dict) else None
        for item in items or []:
            if isinstance(item, dict) and str(item.get("activityId")) == str(activity_id):
                return day, item
    return None, None


def build_session_packet(activity_id: int, redact: bool = False) -> tuple[Path, str, dict[str, Any]]:
    day, activity = _find_activity_date(activity_id)
    if activity is None:
        session_path = config.BASE_DIR / "sessions" / str(activity_id) / f"session-{activity_id}.json"
        if not session_path.exists():
            raise FileNotFoundError(f"Aktivitas {activity_id} tidak ditemukan di data/ maupun sessions/.")
        session = load_json(session_path, {})
        day = str(session.get("startLocal", ""))[:10] or "unknown"
        activity = {
            "activityId": activity_id,
            "activityName": session.get("name"),
            "startTimeLocal": str(session.get("startLocal", "")).replace("T", " ")[:19],
            "distance": session.get("distanceM"),
            "duration": session.get("timerSec"),
            "calories": session.get("calories"),
            "averageHR": session.get("avgHR"),
            "maxHR": session.get("maxHR"),
            "avgPower": session.get("avgPower"),
            "normPower": session.get("np"),
        }
    bundle = load_bundle(day, activity_id=activity_id)
    n = normalize_bundle(bundle)
    normalized_activity = next(
        (a for a in n["activities"] if str(a.get("activity_id")) == str(activity_id)),
        None,
    )
    if normalized_activity is None:
        normalized_activity = _normalize_activity(activity, bundle)
    if redact:
        normalized_activity = {
            **normalized_activity,
            "name": f"Aktivitas {normalized_activity.get('type') or ''}".strip(),
        }
    lines = [
        f"# Garmin Session Analysis Packet — {activity_id}",
        "",
        f"**Atlet:** {'—' if redact else 'Albireo'}  ",
        f"**Tanggal:** {day}  ",
        f"**Dibuat:** {datetime.now(WIB).strftime('%Y-%m-%d %H:%M WIB')}  ",
        f"**Sumber:** {_source_label(n)}  ",
        "",
        "> Paket sesi untuk analisis LLM eksternal. Data faktual, bukan kesimpulan otomatis.",
        "",
        "## 1. Detail sesi",
        "",
        _activity_detail(normalized_activity, bundle.session),
        "",
        "## 2. Konteks harian",
        "",
        table(
            ["Metrik", "Nilai", "Sumber"],
            [
                ["Tidur", f"{fmt_hm(n['sleep'].get('sleep_s'))} · skor {fmt_int(n['sleep'].get('score'))}", "Garmin"],
                ["RHR", f"{fmt_int(n['summary'].get('resting_hr'))} bpm", "Garmin/Intervals"],
                ["HRV", f"{fmt_int(n['hrv'].get('last_night_avg'))} ms · {n['hrv'].get('status') or '—'}", "Garmin"],
                ["Stres", f"{fmt_int(n['stress'].get('avg'))} · maks {fmt_int(n['stress'].get('max'))}", "Garmin"],
                ["Body Battery", f"{fmt_int(n['body_battery'].get('latest'))} (min {fmt_int(n['body_battery'].get('min'))} / maks {fmt_int(n['body_battery'].get('max'))})", "Garmin"],
                ["CTL/ATL/TSB", f"{fmt_dec(n['intervals'].get('ctl'), 1)} / {fmt_dec(n['intervals'].get('atl'), 1)} / {fmt_dec(n['intervals'].get('tsb'), 1)}", "Intervals.icu"],
                ["Berat", _fmt_value(n['summary'].get('weight_kg'), "kg", 2), "Intervals.icu"],
            ],
        ),
        "",
        "## 3. Data quality",
        "",
        table(
            ["Cek", "Hasil"],
            [
                ["Session JSON", "tersedia" if bundle.session else "tidak tersedia"],
                ["Laps", str(len(normalized_activity.get("laps") or []))],
                ["Sumber", _source_label(n)],
                ["Data harian", day],
            ],
        ),
        "",
        _definitions_section(4),
        "",
        _analysis_request(5),
        "",
    ]
    content = "\n".join(lines)
    path = config.REPORT_DIR / f"Garmin-Packet-Session-{activity_id}.md"
    path.write_text(content, encoding="utf-8")
    return path, content, {"activity_id": activity_id, "date": day}


def _date_range(start: str, end: str) -> list[str]:
    start_d = date_cls.fromisoformat(start)
    end_d = date_cls.fromisoformat(end)
    if end_d < start_d:
        raise ValueError("end harus >= start")
    days = []
    current = start_d
    while current <= end_d:
        days.append(current.isoformat())
        current += timedelta(days=1)
    return days


def build_weekly_packet(start: str, end: str, redact: bool = False) -> tuple[Path, str, dict[str, Any]]:
    days = _date_range(start, end)
    rows = []
    normalized_days: list[tuple[str, dict[str, Any]]] = []
    present = 0
    for day in days:
        bundle = load_bundle(day)
        if not bundle.daily_v2 and not bundle.legacy:
            rows.append([day, "—", "—", "—", "—", "—", "—", "—", "—", "—"])
            continue
        present += 1
        n = normalize_bundle(bundle)
        normalized_days.append((day, n))
        s = n["summary"]
        rows.append([
            day,
            fmt_hm(s.get("sleep_s")),
            fmt_int(s.get("resting_hr")),
            fmt_int(n["hrv"].get("last_night_avg")),
            fmt_int(s.get("stress_avg")),
            fmt_int(s.get("bb_latest")),
            fmt_int(s.get("steps")),
            fmt_int(s.get("calories_total")),
            f"{fmt_dec(n['intervals'].get('ctl'), 1)}/{fmt_dec(n['intervals'].get('atl'), 1)}/{fmt_dec(n['intervals'].get('tsb'), 1)}",
            str(len(n["activities"])),
        ])

    activity_rows = []
    for day, n in normalized_days:
        for a in n["activities"]:
            label = f"Aktivitas {a.get('type') or ''}".strip() if redact else (a.get("name") or "—")
            activity_rows.append([
                day,
                f"{label} ({a.get('type') or '—'})",
                f"{fmt_dec((num(a.get('distance_m')) or 0) / 1000, 2)} km",
                fmt_hms(a.get("duration_s")),
                fmt_pace(a.get("pace_s_per_km")),
                f"{fmt_int(a.get('avg_hr'))}/{fmt_int(a.get('max_hr'))}",
                f"{fmt_int(a.get('avg_power'))}/{fmt_int(a.get('np'))} W",
                f"{fmt_dec(a.get('aerobic_te'), 1)}/{fmt_dec(a.get('anaerobic_te'), 1)}",
            ])
    total_sleep_s = sum((num(n["summary"].get("sleep_s")) or 0) for _, n in normalized_days)
    total_steps = sum((num(n["summary"].get("steps")) or 0) for _, n in normalized_days)
    total_cal = sum((num(n["summary"].get("calories_total")) or 0) for _, n in normalized_days)
    total_active = sum((num(n["summary"].get("calories_active")) or 0) for _, n in normalized_days)
    total_distance = sum(
        sum((num(a.get("distance_m")) or 0) for a in n["activities"])
        for _, n in normalized_days
    )
    total_duration = sum(
        sum((num(a.get("duration_s")) or 0) for a in n["activities"])
        for _, n in normalized_days
    )
    last = normalized_days[-1][1] if normalized_days else {}
    lines = [
        f"# Garmin Weekly Analysis Packet — {start} s/d {end}",
        "",
        f"**Atlet:** {'—' if redact else 'Albireo'}  ",
        f"**Dibuat:** {datetime.now(WIB).strftime('%Y-%m-%d %H:%M WIB')}  ",
        f"**Hari dengan data:** {present}/{len(days)}  ",
        "",
        "## 1. Ringkasan harian",
        "",
        table(
            ["Tanggal", "Tidur", "RHR", "HRV", "Stres", "BB", "Langkah", "Kalori", "CTL/ATL/TSB", "Aktivitas"],
            rows,
        ),
        "",
        "## 2. Total & aktivitas",
        "",
        table(
            ["Metrik", "Nilai"],
            [
                ["Hari dengan data", f"{present}/{len(days)}"],
                ["Total tidur", fmt_hm(total_sleep_s)],
                ["Rata-rata tidur/hari", fmt_hm(total_sleep_s / present) if present else "—"],
                ["Rata-rata HRV", fmt_dec(_avg([n["hrv"].get("last_night_avg") for _, n in normalized_days]), 1)],
                ["Rata-rata RHR", fmt_dec(_avg([n["summary"].get("resting_hr") for _, n in normalized_days]), 1)],
                ["Rata-rata stres", fmt_dec(_avg([n["summary"].get("stress_avg") for _, n in normalized_days]), 1)],
                ["Total langkah", fmt_int(total_steps)],
                ["Rata-rata langkah/hari", fmt_int(total_steps / present) if present else "—"],
                ["Total kalori", fmt_int(total_cal)],
                ["Total kalori aktif", fmt_int(total_active)],
                ["Total jarak lari", f"{fmt_dec(total_distance / 1000, 2)} km"],
                ["Total durasi aktivitas", fmt_hms(total_duration)],
                ["Jumlah aktivitas", str(len(activity_rows))],
                ["CTL/ATL/TSB terakhir", f"{fmt_dec(last.get('intervals', {}).get('ctl'), 1)} / {fmt_dec(last.get('intervals', {}).get('atl'), 1)} / {fmt_dec(last.get('intervals', {}).get('tsb'), 1)}"],
            ],
        ),
        "",
        "### Aktivitas",
        "",
        table(
            ["Tanggal", "Aktivitas", "Jarak", "Durasi", "Pace", "HR avg/max", "Power avg/NP", "TE"],
            activity_rows or [["—", "tidak ada aktivitas", "—", "—", "—", "—", "—", "—"]],
        ),
        "",
        "## 3. Data quality",
        "",
        table(
            ["Cek", "Hasil"],
            [
                ["Hari diminta", str(len(days))],
                ["Hari dengan data", str(present)],
                ["Hari tanpa data", str(len(days) - present)],
            ],
        ),
        "",
        _definitions_section(4),
        "",
        _analysis_request(5),
        "",
    ]
    content = "\n".join(lines)
    path = config.REPORT_DIR / f"Garmin-Packet-Weekly-{start}_{end}.md"
    path.write_text(content, encoding="utf-8")
    return path, content, {"start": start, "end": end, "days": len(days), "present": present}


def _intervals_map(end: str, days: list[str]) -> dict[str, dict[str, Any]]:
    candidates = [end] + [d for d in reversed(days) if d != end]
    for candidate in candidates:
        payload = load_json(config.DATA_DIR / f"daily-{candidate}" / "intervals-wellness-7d.json", None)
        if isinstance(payload, list) and payload:
            return {str(x.get("id")): x for x in payload if isinstance(x, dict)}
    return {}


def _weekly_analysis_request(number: int = 11) -> str:
    return "\n".join([
        f"## {number}. Analysis request",
        "",
        "Gunakan **hanya data di atas**. Jangan mengarang data yang tidak ada. Jika ada data yang hilang, sebutkan dan jelaskan bagaimana hal itu membatasi kesimpulan.",
        "",
        "Jawab pertanyaan berikut:",
        "",
        "1. Bagaimana progres beban minggu ini (CTL/ATL/TSB, ramp) dan apakah wajar?",
        "2. Apakah distribusi intensitas (easy vs hard) sesuai tujuan minggu ini? Gunakan HR/power zones.",
        "3. Sesi mana yang paling mahal secara fisiologis, dan apakah penempatannya tepat?",
        "4. Apakah recovery (tidur, HRV, RHR, Body Battery) konsisten dengan beban?",
        "5. Apakah ada tanda overreaching atau under-recovery? Sebutkan bukti angkanya.",
        "6. Apa yang perlu diubah minggu depan: volume, intensitas, recovery, atau komposisi sesi?",
        "7. Data apa yang hilang dan bagaimana batasannya?",
        "",
        "Format: ringkas, berbasis angka, pisahkan fakta vs interpretasi, beri confidence level.",
    ])


def _weekday(day: str) -> str:
    try:
        return HARI[date_cls.fromisoformat(day).weekday()]
    except ValueError:
        return "—"


def _load_str(iv: dict[str, Any]) -> str:
    if not iv:
        return "—"
    ctl, atl = num(iv.get("ctl")), num(iv.get("atl"))
    tsb = (ctl - atl) if ctl is not None and atl is not None else None
    return f"{fmt_dec(ctl, 1)}/{fmt_dec(atl, 1)}/{fmt_dec(tsb, 1)}"


def build_weekly_report(start: str, end: str, redact: bool = False) -> tuple[Path, str, dict[str, Any]]:
    """Full weekly report: daily metrics, load, sessions, recovery, quality, analysis prompt."""
    days = _date_range(start, end)
    imap = _intervals_map(end, days)
    day_data: list[tuple[str, Bundle, dict[str, Any]]] = []
    for day in days:
        bundle = load_bundle(day)
        day_data.append((day, bundle, normalize_bundle(bundle)))

    present = sum(1 for _, b, _ in day_data if b.daily_v2 or b.legacy)
    iv_rows = [imap[d] for d in days if d in imap]
    ctl_vals = [num(x.get("ctl")) for x in iv_rows if num(x.get("ctl")) is not None]
    atl_vals = [num(x.get("atl")) for x in iv_rows if num(x.get("atl")) is not None]
    tsb_vals = [
        (num(x.get("ctl")) - num(x.get("atl")))
        for x in iv_rows
        if num(x.get("ctl")) is not None and num(x.get("atl")) is not None
    ]
    loads = [num(x.get("atlLoad")) for x in iv_rows if num(x.get("atlLoad")) is not None]
    mean_load = sum(loads) / len(loads) if loads else None
    sd_load = (
        math.sqrt(sum((x - mean_load) ** 2 for x in loads) / len(loads))
        if loads and mean_load is not None else None
    )
    monotony = (mean_load / sd_load) if mean_load and sd_load else None
    strain = (sum(loads) * monotony) if loads and monotony else None

    daily_rows = []
    for day, bundle, n in day_data:
        s = n["summary"]
        daily_rows.append([
            day,
            _weekday(day),
            fmt_hm(s.get("sleep_s")),
            fmt_int(n["sleep"].get("score")),
            fmt_int(s.get("resting_hr")),
            fmt_int(n["hrv"].get("last_night_avg")),
            fmt_int(s.get("stress_avg")),
            fmt_int(s.get("bb_latest")),
            fmt_int(s.get("steps")),
            fmt_int(s.get("calories_total")),
            fmt_int(s.get("calories_active")),
            _load_str(imap.get(day, {})),
            str(len(n["activities"])),
        ])

    total_sleep = sum(num(n["summary"].get("sleep_s")) or 0 for _, _, n in day_data)
    avg_sleep = total_sleep / present if present else None
    avg_score = _avg([n["sleep"].get("score") for _, _, n in day_data])
    avg_rhr = _avg([n["summary"].get("resting_hr") for _, _, n in day_data])
    avg_hrv = _avg([n["hrv"].get("last_night_avg") for _, _, n in day_data])
    avg_stress = _avg([n["summary"].get("stress_avg") for _, _, n in day_data])
    avg_bb = _avg([n["summary"].get("bb_latest") for _, _, n in day_data])
    total_steps = sum(num(n["summary"].get("steps")) or 0 for _, _, n in day_data)
    total_cal = sum(num(n["summary"].get("calories_total")) or 0 for _, _, n in day_data)
    total_active = sum(num(n["summary"].get("calories_active")) or 0 for _, _, n in day_data)
    total_distance = sum(sum(num(a.get("distance_m")) or 0 for a in n["activities"]) for _, _, n in day_data)
    total_duration = sum(sum(num(a.get("duration_s")) or 0 for a in n["activities"]) for _, _, n in day_data)
    total_activity_cal = sum(sum(num(a.get("calories")) or 0 for a in n["activities"]) for _, _, n in day_data)
    total_activities = sum(len(n["activities"]) for _, _, n in day_data)
    total_intensity = sum(
        (num(n["steps"].get("intensity_moderate")) or 0)
        + 2 * (num(n["steps"].get("intensity_vigorous")) or 0)
        for _, _, n in day_data
    )

    start_ctl = ctl_vals[0] if ctl_vals else None
    end_ctl = ctl_vals[-1] if ctl_vals else None
    start_atl = atl_vals[0] if atl_vals else None
    end_atl = atl_vals[-1] if atl_vals else None
    end_ramp = num(iv_rows[-1].get("rampRate")) if iv_rows else None
    min_tsb = min(tsb_vals) if tsb_vals else None
    max_tsb = max(tsb_vals) if tsb_vals else None
    end_tsb = tsb_vals[-1] if tsb_vals else None

    weight_rows = []
    for day, bundle, n in day_data:
        body = n["connect"]["body_composition"]
        weight = body.get("weight_kg") or n["intervals"].get("weight_kg")
        source = body.get("weight_source") or ("Intervals.icu" if weight is not None else "—")
        weight_rows.append([day, fmt_dec(weight, 2), source])
    weight_values = [num(n["summary"].get("weight_kg")) for _, _, n in day_data if num(n["summary"].get("weight_kg")) is not None]

    session_list = [(day, a) for day, _, n in day_data for a in n["activities"]]
    longest_session = max(
        session_list,
        key=lambda item: num(item[1].get("distance_m")) or 0,
        default=(None, {}),
    )
    max_hr_session = max(
        session_list,
        key=lambda item: num(item[1].get("max_hr")) or 0,
        default=(None, {}),
    )
    load_items = [
        (day, num(imap.get(day, {}).get("atlLoad")))
        for day, _, _ in day_data
        if imap.get(day) and num(imap.get(day, {}).get("atlLoad")) is not None
    ]
    max_load = max(load_items, key=lambda item: item[1], default=(None, None))
    min_load = min(load_items, key=lambda item: item[1], default=(None, None))
    sleep_items = [
        (day, num(n["sleep"].get("sleep_s")))
        for day, _, n in day_data
        if num(n["sleep"].get("sleep_s")) is not None
    ]
    min_sleep = min(sleep_items, key=lambda item: item[1], default=(None, None))
    max_sleep = max(sleep_items, key=lambda item: item[1], default=(None, None))
    hrv_items = [
        (day, num(n["hrv"].get("last_night_avg")))
        for day, _, n in day_data
        if num(n["hrv"].get("last_night_avg")) is not None
    ]
    min_hrv = min(hrv_items, key=lambda item: item[1], default=(None, None))
    max_hrv = max(hrv_items, key=lambda item: item[1], default=(None, None))

    session_rows = []
    for day, bundle, n in day_data:
        for a in n["activities"]:
            label = f"Aktivitas {a.get('type') or ''}".strip() if redact else (a.get("name") or "—")
            session_rows.append([
                day,
                _weekday(day),
                md_escape(label),
                a.get("type") or "—",
                f"{fmt_dec((num(a.get('distance_m')) or 0) / 1000, 2)} km",
                fmt_hms(a.get("duration_s")),
                fmt_pace(a.get("pace_s_per_km")),
                f"{fmt_int(a.get('avg_hr'))}/{fmt_int(a.get('max_hr'))}",
                f"{fmt_int(a.get('avg_power'))}/{fmt_int(a.get('np'))} W",
                f"{fmt_dec(a.get('aerobic_te'), 1)}/{fmt_dec(a.get('anaerobic_te'), 1)}",
                fmt_int(a.get("calories")),
                _fmt_int_value(a.get("rpe")),
            ])

    hr_zones = [0.0] * 5
    power_zones = [0.0] * 5
    for _, bundle, _ in day_data:
        for raw in bundle.activities_raw:
            for i in range(1, 6):
                hr_zones[i - 1] += num(raw.get(f"hrTimeInZone_{i}")) or 0
                power_zones[i - 1] += num(raw.get(f"powerTimeInZone_{i}")) or 0

    lines: list[str] = [
        f"# Garmin Weekly Report — {start} s/d {end}",
        "",
        f"**Atlet:** {'—' if redact else 'Albireo'}  ",
        f"**Periode:** {start} ({_weekday(start)}) s/d {end} ({_weekday(end)})  ",
        f"**Dibuat:** {datetime.now(WIB).strftime('%Y-%m-%d %H:%M WIB')}  ",
        f"**Hari dengan data:** {present}/{len(days)}  ",
        f"**Sumber:** Garmin Personal API, Intervals.icu (7d wellness), Garmin session JSON  ",
        "",
        "> Laporan mingguan lengkap untuk analisis eksternal. Data faktual, bukan kesimpulan otomatis. Sesi tanpa session JSON tetap diringkas dari activity list; detail lap hanya tersedia untuk sesi yang punya session JSON.",
        "",
        "## 1. Ringkasan eksekutif",
        "",
        table(
            ["Metrik", "Nilai", "Catatan"],
            [
                ["Hari dengan data", f"{present}/{len(days)}", "hari tanpa data dihitung —"],
                ["Jumlah sesi", fmt_int(total_activities), f"{fmt_dec(total_distance / 1000, 2)} km total"],
                ["Total durasi sesi", fmt_hms(total_duration), ""],
                ["Total kalori sesi", fmt_int(total_activity_cal), "kcal dari activity list"],
                ["Total kalori harian", f"{fmt_int(total_cal)} ({fmt_int(total_active)} aktif)", "kcal"],
                ["Total langkah", fmt_int(total_steps), f"rata-rata {fmt_int(total_steps / present) if present else '—'}/hari"],
                ["Rata-rata tidur", fmt_hm(avg_sleep), f"skor rata-rata {fmt_int(avg_score)}"],
                ["Rata-rata RHR", f"{fmt_int(avg_rhr)} bpm", ""],
                ["Rata-rata HRV", f"{fmt_int(avg_hrv)} ms", ""],
                ["Rata-rata stres", fmt_int(avg_stress), ""],
                ["Rata-rata Body Battery akhir", fmt_int(avg_bb), ""],
                ["CTL", f"{fmt_dec(start_ctl, 1)} → {fmt_dec(end_ctl, 1)}", f"delta {fmt_dec((end_ctl - start_ctl) if start_ctl is not None and end_ctl is not None else None, 1)}"],
                ["ATL", f"{fmt_dec(start_atl, 1)} → {fmt_dec(end_atl, 1)}", ""],
                ["TSB min / maks / akhir", f"{fmt_dec(min_tsb, 1)} / {fmt_dec(max_tsb, 1)} / {fmt_dec(end_tsb, 1)}", ""],
                ["Weekly load (sum atlLoad)", fmt_dec(sum(loads) if loads else None, 1), "Intervals.icu"],
                ["Monotony / strain", f"{fmt_dec(monotony, 2)} / {fmt_dec(strain, 1)}", "Foster; hanya jika load harian tersedia"],
                ["Intensity minutes", fmt_int(total_intensity), "moderate + 2×vigorous"],
                ["Berat awal → akhir", f"{fmt_dec(weight_values[0] if weight_values else None, 2)} → {fmt_dec(weight_values[-1] if weight_values else None, 2)}", "kg; sumber campuran"],
            ],
        ),
        "",
        "> Total kalori sesi dan kalori aktif harian bisa berbeda karena agregasi watch vs activity list. Gunakan activity untuk biaya sesi dan daily summary untuk total hari.",
        "",
        "**Highlight faktual:**",
        "",
        f"- Beban harian tertinggi: {max_load[0] or '—'} ({fmt_dec(max_load[1], 1)}); terendah: {min_load[0] or '—'} ({fmt_dec(min_load[1], 1)}).",
        f"- Sesi terpanjang: {longest_session[1].get('name') or '—'} pada {longest_session[0] or '—'} — {fmt_dec((num(longest_session[1].get('distance_m')) or 0) / 1000, 2)} km / {fmt_hms(longest_session[1].get('duration_s'))}.",
        f"- Max HR tertinggi: {fmt_int(max_hr_session[1].get('max_hr'))} bpm pada {max_hr_session[0] or '—'} ({max_hr_session[1].get('name') or '—'}).",
        f"- Tidur terpendek: {min_sleep[0] or '—'} ({fmt_hm(min_sleep[1])}); terpanjang: {max_sleep[0] or '—'} ({fmt_hm(max_sleep[1])}).",
        f"- HRV range: {fmt_int(min_hrv[1])}–{fmt_int(max_hrv[1])} ms; semua status {', '.join(sorted({n['hrv'].get('status') or '—' for _, _, n in day_data}))}.",
        f"- TSB paling negatif: {fmt_dec(min_tsb, 1)}; TSB akhir: {fmt_dec(end_tsb, 1)}.",
        "",
        "## 2. Ringkasan harian",
        "",
        table(
            ["Tanggal", "Hari", "Tidur", "Skor", "RHR", "HRV", "Stres", "BB", "Langkah", "Kalori", "Aktif", "CTL/ATL/TSB", "Sesi"],
            daily_rows,
        ),
        "",
        "## 3. Training load",
        "",
        table(
            ["Tanggal", "CTL", "ATL", "TSB", "Ramp", "Load harian", "Catatan"],
            [
                [
                    day,
                    fmt_dec(imap.get(day, {}).get("ctl"), 2),
                    fmt_dec(imap.get(day, {}).get("atl"), 2),
                    fmt_dec((num(imap.get(day, {}).get("ctl")) or 0) - (num(imap.get(day, {}).get("atl")) or 0), 2) if imap.get(day) else "—",
                    fmt_dec(imap.get(day, {}).get("rampRate"), 2),
                    fmt_dec(imap.get(day, {}).get("atlLoad"), 1),
                    "rest" if not n["activities"] else f"{len(n['activities'])} sesi",
                ]
                for day, _, n in day_data
            ],
        ),
        "",
        table(
            ["Statistik", "Nilai"],
            [
                ["CTL awal → akhir", f"{fmt_dec(start_ctl, 2)} → {fmt_dec(end_ctl, 2)}"],
                ["Delta CTL", fmt_dec((end_ctl - start_ctl) if start_ctl is not None and end_ctl is not None else None, 2)],
                ["Ramp rate akhir", fmt_dec(end_ramp, 2)],
                ["TSB min / maks / akhir", f"{fmt_dec(min_tsb, 2)} / {fmt_dec(max_tsb, 2)} / {fmt_dec(end_tsb, 2)}"],
                ["Total load mingguan", fmt_dec(sum(loads) if loads else None, 1)],
                ["Monotony", fmt_dec(monotony, 2)],
                ["Strain", fmt_dec(strain, 1)],
            ],
        ),
        "",
        "## 4. Sesi",
        "",
        table(
            ["Tanggal", "Hari", "Sesi", "Tipe", "Jarak", "Durasi", "Pace", "HR avg/max", "Power avg/NP", "TE", "Kalori", "RPE"],
            session_rows,
        ),
        "",
    ]
    if session_rows:
        for day, bundle, n in day_data:
            for a in n["activities"]:
                lines += [_activity_detail(a, a.get("session") or None), ""]
    else:
        lines += ["_Tidak ada sesi pada periode ini._", ""]

    sleep_rows = []
    for day, _, n in day_data:
        sl = n["sleep"]
        sleep_rows.append([
            day,
            fmt_hm(sl.get("sleep_s")),
            fmt_int(sl.get("score")),
            fmt_pct(sl.get("deep_pct")),
            fmt_pct(sl.get("light_pct")),
            fmt_pct(sl.get("rem_pct")),
            fmt_pct(sl.get("efficiency")),
            fmt_hm(sl.get("awake_s")),
            fmt_hm(sl.get("nap_s")),
            fmt_hm((num(sl.get("need_actual_min")) or 0) * 60),
            fmt_int(sl.get("avg_hr")),
            fmt_int(sl.get("avg_spo2")),
            fmt_dec(sl.get("avg_respiration"), 1),
        ])
    lines += [
        "## 5. Tidur & recovery",
        "",
        table(
            ["Tanggal", "Tidur", "Skor", "Deep", "Light", "REM", "Efisiensi", "Awake", "Nap", "Need", "HR tidur", "SpO₂", "Napas"],
            sleep_rows,
        ),
        "",
        table(
            ["Rata-rata", "Nilai"],
            [
                ["Durasi tidur", fmt_hm(avg_sleep)],
                ["Skor", fmt_int(avg_score)],
                ["Deep", fmt_pct(_avg([n["sleep"].get("deep_pct") for _, _, n in day_data]))],
                ["REM", fmt_pct(_avg([n["sleep"].get("rem_pct") for _, _, n in day_data]))],
                ["Efisiensi", fmt_pct(_avg([n["sleep"].get("efficiency") for _, _, n in day_data]))],
                ["Nap total", fmt_hm(sum(num(n["sleep"].get("nap_s")) or 0 for _, _, n in day_data))],
                ["HRV", f"{fmt_int(avg_hrv)} ms"],
                ["RHR", f"{fmt_int(avg_rhr)} bpm"],
            ],
        ),
        "",
    ]

    recovery_rows = []
    for day, _, n in day_data:
        recovery_rows.append([
            day,
            fmt_int(n["summary"].get("resting_hr")),
            fmt_int(n["hrv"].get("last_night_avg")),
            n["hrv"].get("status") or "—",
            fmt_int(n["stress"].get("avg")),
            fmt_int(n["stress"].get("max")),
            fmt_int(n["body_battery"].get("latest")),
            fmt_int(n["body_battery"].get("min")),
            fmt_int(n["body_battery"].get("max")),
            fmt_int(n["spo2"].get("avg")),
            fmt_int(n["respiration"].get("avg")),
        ])
    lines += [
        "## 6. HR, stress & Body Battery",
        "",
        table(
            ["Tanggal", "RHR", "HRV", "Status HRV", "Stres avg", "Stres maks", "BB akhir", "BB min", "BB maks", "SpO₂", "Napas"],
            recovery_rows,
        ),
        "",
    ]
    if sum(hr_zones) > 0:
        lines += [
            "### Distribusi HR zones (semua sesi)",
            "",
            table(
                ["Zona", "Waktu", "%"],
                [
                    [f"Z{i}", fmt_hms(z), fmt_pct(z / (sum(hr_zones) or 1) * 100, 1)]
                    for i, z in enumerate(hr_zones, 1)
                ],
            ),
            "",
        ]
    if sum(power_zones) > 0:
        lines += [
            "### Distribusi power zones (semua sesi)",
            "",
            table(
                ["Zona", "Waktu", "%"],
                [
                    [f"P{i}", fmt_hms(z), fmt_pct(z / (sum(power_zones) or 1) * 100, 1)]
                    for i, z in enumerate(power_zones, 1)
                ],
            ),
            "",
        ]

    lines += [
        "## 7. Berat & body composition",
        "",
        table(["Tanggal", "Berat (kg)", "Sumber"], weight_rows),
        "",
        table(
            ["Statistik", "Nilai"],
            [
                ["Awal", fmt_dec(weight_values[0] if weight_values else None, 2)],
                ["Akhir", fmt_dec(weight_values[-1] if weight_values else None, 2)],
                ["Delta", fmt_dec((weight_values[-1] - weight_values[0]) if len(weight_values) >= 2 else None, 2)],
                ["Min / maks", f"{fmt_dec(min(weight_values) if weight_values else None, 2)} / {fmt_dec(max(weight_values) if weight_values else None, 2)}"],
            ],
        ),
        "",
        "> Perubahan berat mingguan bisa dipengaruhi hidrasi, waktu timbang, dan isi lambung; bukan hanya perubahan lemak.",
        "",
        "## 8. Hidrasi & nutrisi",
        "",
        table(
            ["Tanggal", "Air (ml)", "Goal (ml)", "% goal"],
            [
                [
                    day,
                    fmt_int(n["hydration"].get("consumed_ml")),
                    fmt_int(n["hydration"].get("goal_ml")),
                    fmt_pct(safe_pct(n["hydration"].get("consumed_ml"), n["hydration"].get("goal_ml"))),
                ]
                for day, _, n in day_data
            ],
        ),
        "",
        "> Nutrition/food log hanya terisi jika dicatat di Garmin Connect. Tanpa itu, energy availability tidak bisa dihitung. Air 0 ml berarti tidak ada log minum, bukan berarti tidak minum.",
        "",
    ]

    missing_days = [day for day, b, _ in day_data if not (b.daily_v2 or b.legacy)]
    partial_days = [
        (day, n["coverage"].get("data_end"))
        for day, _, n in day_data
        if n["coverage"].get("partial_day")
    ]
    missing_key = []
    for day, bundle, _ in day_data:
        missing = [name for name in KEY_FILES if not (bundle.out_dir / f"{name}.json").exists()]
        # The 7-day Intervals file is shared from the last day and covers the
        # whole week, so per-day copies are not required for this report.
        if imap:
            missing = [m for m in missing if m not in ("intervals-wellness", "intervals-wellness-7d")]
        if missing:
            missing_key.append((day, missing))
    conflict_rows = []
    for day, _, n in day_data:
        for c in n.get("conflicts") or []:
            conflict_rows.append([day, c["metric"], f"{fmt_dec(c['a'], 2)} vs {fmt_dec(c['b'], 2)}", c["severity"]])
    hr_delta_rows = []
    for day, _, n in day_data:
        daily_max = num(n["summary"].get("max_hr"))
        for a in n["activities"]:
            act_max = num(a.get("max_hr"))
            if act_max is not None and daily_max is not None and abs(act_max - daily_max) > 5:
                hr_delta_rows.append([day, md_escape(a.get("name") or "—"), fmt_int(act_max), fmt_int(daily_max), fmt_int(act_max - daily_max)])

    lines += [
        "## 9. Data quality & conflicts",
        "",
        table(
            ["Cek", "Hasil", "Status"],
            [
                ["Hari diminta / dengan data", f"{len(days)} / {present}", "✅" if present == len(days) else "⚠"],
                ["Hari tanpa data", ", ".join(missing_days) or "tidak ada", "⚠" if missing_days else "✅"],
                ["Hari parsial", ", ".join(f"{d} ({end})" for d, end in partial_days) or "tidak ada", "⚠" if partial_days else "✅"],
                ["File wajib hilang", "; ".join(f"{d}: {', '.join(m)}" for d, m in missing_key) or "tidak ada", "⚠" if missing_key else "✅"],
                ["Intervals 7d", f"{len(imap)} hari tersedia" if imap else "tidak tersedia", "✅" if imap else "⚠"],
                ["Konflik source", str(len(conflict_rows)), "⚠" if conflict_rows else "✅"],
                ["Session JSON", "tersedia untuk 21–22 Nov; sesi lain hanya activity list", "ℹ"],
            ],
        ),
        "",
    ]
    if conflict_rows:
        lines += [table(["Tanggal", "Metrik", "Nilai", "Severity"], conflict_rows), ""]
    if hr_delta_rows:
        lines += [
            "### Activity max HR vs daily max HR",
            "",
            table(["Tanggal", "Sesi", "Max HR activity", "Max HR daily", "Delta"], hr_delta_rows),
            "",
            "> Perbedaan bukan error; agregasi watch dan activity bisa berbeda. Gunakan activity untuk analisis sesi.",
            "",
        ]
    lines += [_definitions_section(10), ""]
    lines += [_weekly_analysis_request(11), ""]
    lines += [
        "## 12. Lampiran",
        "",
        f"- Folder data: `{config.DATA_DIR}`",
        f"- File harian: {', '.join(f'daily-{d}' for d in days)}",
        f"- Intervals 7d: `{config.DATA_DIR / f'daily-{end}' / 'intervals-wellness-7d.json'}`",
        f"- Session JSON: `sessions\\<activity_id>\\`",
        "",
        "*Dibuat oleh garmin_packet. Tidak memuat API key/token.*",
    ]
    content = "\n".join(lines)
    path = config.REPORT_DIR / f"Garmin-Weekly-Report-{start}_{end}.md"
    path.write_text(content, encoding="utf-8")
    return path, content, {
        "start": start,
        "end": end,
        "days": len(days),
        "present": present,
        "activities": total_activities,
        "distance_km": round(total_distance / 1000, 2),
    }


def build_audit_packet(start: str, end: str) -> tuple[Path, str, dict[str, Any]]:
    days = _date_range(start, end)
    rows = []
    for day in days:
        out_dir = config.DATA_DIR / f"daily-{day}"
        if not out_dir.exists():
            rows.append([day, "tidak ada folder", "—", "—", "—", "—"])
            continue
        missing = [name for name in KEY_FILES if not (out_dir / f"{name}.json").exists()]
        gap_missing = [name for name in GAP_FILES if not (out_dir / f"{name}.json").exists()]
        bundle = load_bundle(day)
        n = normalize_bundle(bundle)
        rows.append([
            day,
            "ada" if bundle.daily_v2 or bundle.legacy else "tanpa daily",
            str(len(missing)),
            ", ".join(missing[:5]) + ("…" if len(missing) > 5 else "") if missing else "—",
            str(len(n.get("conflicts") or [])),
            n["coverage"].get("data_end") or "—",
        ])
    lines = [
        f"# Garmin Data Audit Packet — {start} s/d {end}",
        "",
        f"**Dibuat:** {datetime.now(WIB).strftime('%Y-%m-%d %H:%M WIB')}  ",
        "",
        "## 1. Coverage & missing files",
        "",
        table(
            ["Tanggal", "Folder", "File wajib hilang", "Detail", "Konflik", "Data berakhir"],
            rows,
        ),
        "",
        "## 2. Gap-fill Garmin Connect",
        "",
        "File gap-fill yang diharapkan:",
        "",
        "\n".join(f"- `{name}`" for name in GAP_FILES),
        "",
    ]
    history_files = sorted((config.DATA_DIR / "hr-history").glob("daily-summaries-*.json"))
    history_rows: list[dict[str, Any]] = []
    for path in history_files:
        payload = load_json(path, [])
        if isinstance(payload, list):
            history_rows.extend(x for x in payload if isinstance(x, dict))
    history_dates = [str(r.get("calendarDate")) for r in history_rows if r.get("calendarDate")]
    duplicate_dates = len(history_dates) - len(set(history_dates))
    lines += [
        "## 3. Historical daily summaries",
        "",
        table(
            ["Cek", "Hasil"],
            [
                ["File history", ", ".join(p.name for p in history_files) or "—"],
                ["Jumlah hari", str(len(history_dates))],
                ["Rentang", f"{min(history_dates) if history_dates else '—'} s/d {max(history_dates) if history_dates else '—'}"],
                ["Duplikat tanggal", str(duplicate_dates)],
                ["Hari hilang di rentang", str(
                    (date_cls.fromisoformat(max(history_dates)) - date_cls.fromisoformat(min(history_dates))).days + 1 - len(set(history_dates))
                ) if history_dates else "—"],
            ],
        ),
        "",
        "## 4. Interpretasi cepat",
        "",
        "- File wajib hilang = data tidak bisa dipakai untuk analisis lengkap.",
        "- Konflik = perbedaan Garmin vs Intervals di luar ambang; jangan dirata-ratakan tanpa cek definisi.",
        "- Data berakhir < 23:59 = hari parsial; metrik harian belum final.",
        "",
        _analysis_request(5),
        "",
    ]
    content = "\n".join(lines)
    path = config.REPORT_DIR / f"Garmin-Packet-Audit-{start}_{end}.md"
    path.write_text(content, encoding="utf-8")
    return path, content, {"start": start, "end": end, "days": len(days)}
