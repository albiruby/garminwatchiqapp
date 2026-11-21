# RacePilot v2.2.0 — Connect IQ Store Metadata Draft

> Draft siap pakai untuk Connect IQ Store submission.
> Isi bagian `<isi>` (support email/URL) sebelum submit.

---

## 1. Basic Info

| Field | Value |
|-------|-------|
| **App Name** | RacePilot |
| **Tagline** | Smarter Pace. Stronger Finish. |
| **Category** | Data Fields |
| **Sub-category** | Running |
| **Price** | (gratis / berbayar — tentukan) |
| **Version** | 2.2.0 |
| **Min SDK** | 3.2.0 |
| **Languages** | English |
| **Package** | `build/RacePilot-v2.2.0.iq` |

---

## 2. Short Description (max ~150 char)

```
Race pacing data field: live projected finish, ahead/behind, need pace and a progress ring. 3 layouts. Outdoor, Track & Treadmill.
```

---

## 3. Full Description

```
RacePilot answers the one question every runner asks mid-race:
"Will I hit my target finish time — and what pace do I need to run?"

Instead of just showing current pace, RacePilot projects your finish time
in real time and tells you exactly how far ahead or behind you are.

WHAT YOU SEE
• Projected Finish — estimated finish time, updated live
• Ahead / Behind — how much time you're ahead of or behind target
• Need Pace — the pace you must hold to hit your goal
• Lap Pace — smoothed, stable pace (no jitter)
• Progress ring — distance covered toward your race distance

PICK YOUR LAYOUT
• Standard (HUD) — projected finish hero with a progress ring
• Delta — giant +/- time vs target with a color status bar
• Grid — classic split grid: lap pace, need pace, distance, time
• Focus — big pace with distance and time in one line

THREE RUN MODES
• Outdoor GPS — spike rejection, corner protection, tunnel hold,
  GPS recovery
• Track Run — pace per lap (/400m or custom), lap counter,
  lap blending
• Treadmill Run — 3-phase warmup that fixes early-pace errors,
  single-point calibration (x100)

46 RACE PRESETS
5K (Sub 18–35), 10K (Sub 40–70), Half Marathon (Sub 1:20–2:30),
Marathon (Sub 2:30–5:00), and Custom distance/time.

MORE
• Metric / Imperial units (auto from watch)
• Dark or High Contrast theme, 5 accent colors
• Off-target vibration alert (can be turned off)
• Projected finish, ahead/behind and need pace recorded to your
  activity — view the charts in Garmin Connect

WHO IT'S FOR
Runners chasing a specific goal time — PR attempts, race day,
tempo runs, and interval sessions on the track.
```

---

## 4. "What's New" (v2.2.0)

```
• New UI: Suunto-style HUD with distance progress ring
• Two new layouts: Delta (big +/- vs target) and Grid
• Metric / Imperial units, Dark / High Contrast theme, 5 accent colors
• Projected finish, ahead/behind and need pace charts in Garmin Connect
• Fixed: projected finish could stop updating mid-race
• Fixed: Auto run type could switch to treadmill when GPS dropped
  (e.g. tunnels), causing distance jumps
• Smarter off-target alert: vibrates when you fall behind, then
  reminds at most every 2 minutes
• 20 automated tests, zero code warnings
```

---

## 5. Screenshots

Siap pakai (dipotong dari simulator, < 150 KB): folder `SS Redesign UI/Store/`.

| # | File | Scene |
|---|------|-------|
| 1 | `store_1_fr165_standard.jpg` | Standard HUD — projected 24:09, ▲0:51 ahead |
| 2 | `store_2_fr165_delta.jpg` | Delta layout — +0:51, status bar |
| 3 | `store_3_fr165_grid.jpg` | Grid layout |
| 4 | `store_4_edge540.jpg` | Edge 540 (rectangular) |
| 5 | `store_5_venux1.jpg` | Venu X1 |

Catatan: angka berasal dari simulasi (target 5K sub-25). Untuk store yang lebih meyakinkan, bisa diganti screenshot dari lari nyata.

---

## 6. Hero / Cover Images

| Asset | Spec | Status |
|-------|------|--------|
| Hero image | 1440×720, JPG/PNG/GIF, max 2048 KB | `SS Redesign UI/Hero v2.2.0/HeroImage_v2.2.0.jpg` (UI baru, 134 KB) |
| Cover image | 500×500, max 300 KB | `Asset Developer Portal/CoverImageIcons.jpg` |

---

## 7. Permissions Justification

| Permission | Alasan |
|------------|--------|
| **Positioning** | Membaca GPS untuk pace & jarak outdoor |
| **UserProfile** | Menyesuaikan unit pace (metric/imperial) |
| **FitContributor** | Merekam projected finish, ahead/behind, need pace ke file aktivitas |

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

---

## 10. Pre-Submit Checklist

- [x] Build clean (0 code warnings; hanya info icon auto-scale)
- [x] Store package `build/RacePilot-v2.2.0.iq` (85 device build)
- [x] 20 unit test lulus
- [x] Version bump 2.2.0
- [x] Description + What's New
- [x] 5 screenshot store
- [x] FIT contributions (chart di Garmin Connect)
- [ ] **Hardware test di jam fisik** (HARDWARE_TEST_CHECKLIST.md) — wajib, tidak bisa disimulasikan
- [ ] Hero image versi UI baru (opsional, yang lama masih valid)
- [ ] Support email / URL
- [ ] Privacy policy (jika diminta)
