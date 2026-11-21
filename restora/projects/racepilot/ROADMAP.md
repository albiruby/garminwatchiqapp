# RacePilot — Roadmap

> Dokumen ini melacak rencana update RacePilot agar tidak terlupa.
> **Versi terakhir:** v2.1.0 (multi-device, 71 device)
> **Status rilis:** Re-release sebagai app BARU (App ID `01d6a798-591e-4be2-bfdf-5469e2dc9651`), pending review Garmin (±3 hari).

---

## Status Saat Ini (v2.1.0)

- Unified pacing architecture (`RPDisplaySnapshot` single source of truth)
- 3 engine: Outdoor GPS, Track, Treadmill
- 46 race presets + Custom
- Multi-device: 71 device (3 Instinct 1-bit/32KB dikecualikan)
- 8 settings (Race Preset, Custom Dist, Custom Time, Run Type, Treadmill Calib, Track Length, Pace Smoothing, Debug)
- 15 unit test, zero warning build
- Package: `build/RacePilot-multidevice.iq`

---

## v2.2 — "Polish & Fundamentals"  *(dikerjakan 15 Nov 2026 — diverifikasi simulator + 15 unit test)*

> Tanpa permission baru kecuali FitContributor (deklarasi manifest). Risiko rendah, dampak user besar.

| Fitur | Value | Status |
|-------|-------|--------|
| Metric/Imperial units | Setting Units: Auto/Metric/Imperial; pace & dist otomatis | ✅ |
| Pilihan layout Standard / Focus | Setting LayoutMode; Focus = pace besar + dist/time sebaris | ✅ |
| Theme + warna aksen | Setting Theme (Dark/HighContrast) + Accent (5 warna) | ✅ |
| Alerts getar off-target | Vibrate saat behind >5 detik, throttle 30 detik, bisa dimatikan | ✅ |
| FIT custom fields (projFinish, aheadBehind, needPace) | Direkam per detik, bisa dianalisa di Garmin Connect | ✅ |
| Debug overlay lengkap (engine + GPS quality + conf/rej/lock) | Strip bawah, kode pendek, auto-resize dari tinggi font | ✅ |

**Effort:** rendah–sedang

---

## v2.3 — "Accuracy Upgrade"

| Fitur | Catatan | Status |
|-------|---------|--------|
| GAP (Minetti cost model) | Pace disesuaikan tanjakan/turunan (butuh barometer) | ⬜ |
| Late-race fade model | Proyeksi menyesuaikan kelelahan (marathon) | ⬜ |
| Negative / Positive split strategy | Target pace per segmen | ⬜ |
| Interval/workout awareness | `getCurrentWorkoutStep()` → auto target per step | ⬜ |
| Lane-aware track length (lane 1–8) | Lap efektif lebih akurat | ⬜ |
| Auto-calibrate treadmill | Kalibrasi otomatis dari beberapa run | ⬜ |
| typecheck 3 + unit test expansion | Kualitas kode | ⬜ |

**Effort:** sedang

---

## v2.4 — "Expansion"

| Fitur | Permission/Catatan | Status |
|-------|--------------------|--------|
| Cycling/Edge power pacing | `info.currentPower` (butuh power meter) | ⬜ |
| HR-based suggestion / cardiac drift | `UserProfile` ✅ sudah ada | ⬜ |
| Touch page cycling | Device touch (tombol fisik terbatas) | ⬜ |
| Localization (ID/DE/FR/ES/JP) | Resource strings | ⬜ |
| Instinct 1-bit support (32KB/monokrom) | Optimasi memori berat (opsional) | ⬜ |

**Effort:** sedang–besar

---

## v3.0 — "Platform / Big Bets"

| Fitur | Catatan | Status |
|-------|---------|--------|
| Weather-adjusted pacing | Permission **Weather** + HP tersambung | ⬜ |
| Course-aware strategy | Investigasi API course (kemungkinan terbatas di data field) | ⬜ |
| Companion glance/widget | Tipe app **terpisah** (app kedua) | ⬜ |
| Optional cloud analytics | Butuh `Communications` + privacy policy | ⬜ |
| Advanced telemetry dashboard | Tuning berbasis data lapangan | ⬜ |

**Effort:** besar · butuh review Garmin untuk permission/network

---

## R&D / Investigasi (belum masuk versi)

- [ ] Course elevation profile — cek apakah API navigasi bisa diakses data field
- [ ] Multi-source sensor fusion (footpod + GPS) untuk hybrid indoor/outdoor
- [ ] Fatigue/power model untuk ultra & trail
- [ ] A/B tuning confidence thresholds via telemetry internal

---

## Catatan Permission & Keterbatasan (penting)

### Tanpa permission tambahan (aman di data field)
- Units, layout, theme (render)
- GAP (altitude — butuh hardware barometer, bukan permission)
- Lane-aware, treadmill calib, fade model, split strategy (math)
- FIT custom fields (`FitContributor`, limit 255 byte/message)
- Alerts (`Attention` + `DataFieldAlert`)
- Baca HR (`info.currentHeartRate`)

### Butuh permission tambahan
- HR zones / max HR → **UserProfile** (sudah ada)
- Weather → **Weather** (belum; butuh HP + dukungan device)
- Network → **Communications** (data field umumnya tidak boleh network)

### Terbatas / tidak ideal di data field
- Course elevation profile (API navigasi tidak penuh diekspos)
- Multi-page via tombol fisik (touch tap bisa)
- Cycling power (hardware power meter)
- Instinct 1-bit (butuh optimasi memori berat)

### Butuh tipe app berbeda
- Glance/widget (tipe app terpisah)
- Background/network sync

---

## Prinsip Tiap Rilis

1. Tidak merusak yang stabil — regression test terus ditambah (mulai 15).
2. Permission minimal — tambah hanya bila perlu + alasan jelas.
3. Uji multi-device minimal 4 family: AMOLED, MIP, Edge, Instinct.
4. Store metadata rapi tiap rilis (What's New akurat).
5. Build: zero warning, `-O2`, package multi-device.

---

## Urutan Kerja Disarankan

```
v2.1.1 (hotfix bila ada feedback lapangan)
   └─ bug dari user

v2.2  → units, layout, theme, alerts, FIT fields, debug
v2.3  → GAP, fade model, split strategy, interval, lane, treadmill calib
v2.4  → cycling power, HR drift, touch pages, i18n, Instinct 1-bit
v3.0  → weather, glance, cloud (opsional)
```

---

## Ide dari Feedback / Referensi (backlog)

- Tambah opsi Track Length 250m & 500m ke Settings Guide (sudah ada di implementasi)
- Samakan Settings Guide: ganti "Pace Response: Auto" → "Pace Smoothing: 50 (Balanced)"
- Debug Mode: tampilkan active engine + GPS quality (sesuai guide)
- Screenshot store dengan data nyata (simulasi lari), bukan placeholder `0.00`

---

_Last updated: v2.1.0 re-release._
