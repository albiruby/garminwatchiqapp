from pathlib import Path

from garmin_packet.report import (
    _zone_rows,
    build_daily_packet,
    build_session_packet,
    build_weekly_report,
)


def test_daily_packet_contains_required_sections_and_values(tmp_path, monkeypatch):
    from garmin_packet import config

    monkeypatch.setattr(config, "REPORT_DIR", tmp_path)
    path, content, summary = build_daily_packet("2026-11-22", cutoff="18:11 WIB")

    assert path.exists()
    assert path.parent == tmp_path
    for heading in (
        "## 1. Ringkasan data",
        "## 2. Tidur",
        "## 3. Heart rate & HRV",
        "## 4. Stres & Body Battery",
        "## 5. SpO₂ & pernapasan",
        "## 6. Training load & recovery",
        "## 7. Aktivitas",
        "## 8. Body composition & berat",
        "## 9. Nutrisi & hidrasi",
        "## 10. Baseline",
        "### 10.2 28/90 hari",
        "## 11. Data quality & conflicts",
        "## 12. Definitions",
        "## 13. Analysis request",
        "## 14. Lampiran file",
    ):
        assert heading in content
    assert "Treadmill Running" in content
    assert "20,18 km" in content
    assert "43,34" in content
    assert "85" in content
    assert "undefined" not in content
    assert "NaN" not in content
    assert "garmin-api-key" not in content
    assert summary["sleep_s"] == 28740


def test_zone_rows_do_not_duplicate_top_zone():
    rows = _zone_rows([0, 0, 0, 0, 0, 0, 0], [125, 143, 161, 175, 192, 208])
    assert len(rows) == 7
    assert len({row[0] for row in rows}) == 7
    assert rows[-1][0].startswith("Z6")


def test_session_packet_contains_laps_and_decoupling(tmp_path, monkeypatch):
    from garmin_packet import config

    monkeypatch.setattr(config, "REPORT_DIR", tmp_path)
    path, content, summary = build_session_packet(25157631151)

    assert path.exists()
    assert "## 1. Detail sesi" in content
    assert "## 2. Konteks harian" in content
    assert "#### Laps" in content
    assert "#### Cardiac decoupling" in content
    assert "5:27/km" in content
    assert "21" in content
    assert summary["activity_id"] == 25157631151


def test_legacy_session_packet_works_without_daily_folder(tmp_path, monkeypatch):
    from garmin_packet import config

    monkeypatch.setattr(config, "REPORT_DIR", tmp_path)
    path, content, summary = build_session_packet(24946233617)

    assert path.exists()
    assert "Garmin session JSON" in content
    assert "5:25/km" in content
    assert "| Lap | Tipe |" in content
    assert summary["date"] == "2026-11-03"


def test_weekly_report_contains_totals_and_activities(tmp_path, monkeypatch):
    from garmin_packet import config

    monkeypatch.setattr(config, "REPORT_DIR", tmp_path)
    path, content, summary = build_weekly_report("2026-11-16", "2026-11-22")

    assert path.exists()
    assert "## 1. Ringkasan eksekutif" in content
    assert "## 2. Ringkasan harian" in content
    assert "## 3. Training load" in content
    assert "## 4. Sesi" in content
    assert "Total langkah" in content
    assert "Treadmill Running" in content
    assert summary["present"] >= 1
