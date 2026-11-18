# RacePilot v2.1.0 — Connect IQ Store Metadata Draft

> Draft siap pakai untuk Connect IQ Store submission.
> Sesuaikan URL/email sebelum submit.

---

## 1. Basic Info

| Field | Value |
|-------|-------|
| **App Name** | RacePilot |
| **Tagline** | Smarter Pace. Stronger Finish. |
| **Category** | Data Fields |
| **Sub-category** | Running |
| **Price** | (gratis / berbayar — tentukan) |
| **Version** | 2.1.0 |
| **Min SDK** | 3.2.0 |
| **Languages** | English |

---

## 2. Short Description (max ~150 char)

```
Race pacing data field with live projected finish, ahead/behind indicator, and need-pace guidance. Outdoor, Track & Treadmill.
```

---

## 3. Full Description

```
RacePilot answers the one question every runner asks mid-race:
"Will I hit my target finish time — and what pace do I need to run?"

Instead of just showing current pace, RacePilot projects your finish time
in real time and tells you exactly how far ahead or behind you are.

WHAT YOU SEE
• Lap Pace — smoothed, stable pace (no jitter)
• Distance & Timer — your activity progress
• Projected Finish — estimated finish time at current pace
• Ahead / Behind — how much time you're ahead of or behind target
• Need Pace — the pace you must hold to hit your goal

THREE RUN MODES
• Outdoor GPS — spike rejection, corner protection, tunnel hold,
  grade compensation, GPS recovery
• Track Run — pace per lap (/400m or custom), lap counter,
  auto lap detection, lap blending
• Treadmill Run — 3-phase warmup that fixes Garmin's early-pace
  errors, single-point calibration (x100)

46 RACE PRESETS
5K (Sub 18–35), 10K (Sub 40–70), Half Marathon (Sub 1:20–2:30),
Marathon (Sub 2:30–5:00), and Custom distance/time.

BUILT FOR STABILITY
• Confidence engine (0–100%) suppresses unreliable data
• Adaptive smoothing that reacts faster when GPS is clean
• Projection lock prevents the finish estimate from vibrating
• Multi-source prediction (instant + lap + EWMA + history)
• Finish lock freezes display after you cross the line

WHO IT'S FOR
Runners chasing a specific goal time — PR attempts, race day,
tempo runs, and interval sessions on the track.
```

---

## 4. "What's New" (v2.1.0)

```
• Unified architecture with single source-of-truth display model
• Treadmill 3-phase warmup — eliminates early-run pace errors
• Configurable track length (200/250/300/400/500m)
• Auto-pause detection with distance-stagnation guard
• Finish lock prevents flicker across the finish line
• Distance-gated grade filter for smoother hill compensation
• Cleaner UI matching the reference layout
• Fixed "LAP LAP" lap-count duplication
• 15 automated unit tests, zero build warnings
```

---

## 5. Screenshots Plan (5 campaign images)

Store butuh gambar layar jam (biasanya 5). Scene yang direkomendasikan:

| # | Scene | Data contoh |
|---|-------|-------------|
| 1 | **At a Glance** — Outdoor default | 5:32/km, 8.24km, 42:37, proyeksi 49:47, ▲0:13 AHEAD, 5:18/km |
| 2 | **Ahead of Target** | 5:12/km, 10.35km, 53:15, proyeksi 49:38, ▲0:22 AHEAD, 5:15/km |
| 3 | **Behind Target** | 6:02/km, 12.40km, 1:15:10, proyeksi 50:13, ▼0:28 BEHIND, 6:10/km |
| 4 | **Treadmill Run** | 5:45/km, 7.60km, 40:00, proyeksi 50:00, ▼ON TARGET, 5:40/km |
| 5 | **Track Run** | 1:24/400m, 3.20km, 12:45, proyeksi 25:05, ▲0:15 AHEAD, 1:25/400m |

**Catatan:** Gunakan skenario 10K target 50:00 sebagai basis konsisten (lihat reference infographic).

---

## 6. Hero / Cover Images

| Asset | Spec | Status |
|-------|------|--------|
| Hero image | 1440×720, JPG/PNG/GIF, max 2048 KB | ☐ Belum |
| Cover image | 500×500, max 300 KB | ☐ Belum |
| Screen images | max 150 KB each | ☐ Belum |

Aset promosi yang sudah ada di `Context & References/` bisa dipakai/di-edit.

---

## 7. Permissions Justification

| Permission | Alasan |
|------------|--------|
| **Positioning** | Membaca GPS untuk pace & jarak outdoor |
| **UserProfile** | Menyesuaikan unit pace (metric/imperial) |

---

## 8. Privacy

- Data stays on device — **tidak ada pengiriman ke server**.
- Tidak mengumpulkan data pribadi.
- Privacy policy URL: `<isi bila diperlukan oleh store>`

---

## 9. Support / Contact

| Field | Value |
|-------|-------|
| Support email | `<isi>` |
| Support URL | `<isi>` |
| Source repo | `<isi bila open> ` |

---

## 10. Pre-Submit Checklist

- [ ] Build clean (zero warnings) — ✅ sudah
- [ ] Store package `.iq` generated — ✅ sudah (31.4 KB)
- [ ] Hardware test lulus (lihat HARDWARE_TEST_CHECKLIST.md) — ☐
- [ ] 5 screenshot campaign siap — ☐
- [ ] Hero + cover image siap — ☐
- [ ] Description + What's New diisi — ✅ draft siap
- [ ] Privacy policy (jika diminta) — ☐
- [ ] Version bump final — 2.1.0 ✅
- [ ] Icon 54×54 (fr165) — ✅ sudah
- [ ] Languages di manifest — ✅ sudah

---

## Catatan Strategi Rilis

**Rilis 1: fr165 saja (v2.1.0)**
- Fokus stabilitas di device utama
- Kumpulkan feedback lapangan
- Fix bug hardware-specific jika ada

**Rilis 2 (v2.2+): Multi-device**
- Tambah fr165m, fr255/255s, fr265/265s, fr955, fr965
- Build + test per device (ukuran layar & API beda)
- Jangan klaim kompatibel sebelum test tiap device
