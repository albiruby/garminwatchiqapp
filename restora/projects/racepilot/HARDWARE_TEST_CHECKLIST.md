# RacePilot v2.1.0 — Hardware Test Checklist (FR165)

> **Tujuan:** Validasi runtime di jam fisik sebelum submit Connect IQ Store.
> Simulator tidak bisa memvalidasi sensor GPS/speed asli, jadi checklist ini wajib.
>
> **Target:** Garmin Forerunner 165 (390×390 AMOLED)
> **Durasi total estimasi:** ~90 menit (bisa dicicil)

---

## 0. Persiapan

- [ ] Install `RacePilot.iq` via Connect IQ Mobile → sinkron ke jam
- [ ] Pastikan firmware jam terbaru
- [ ] Tambah RacePilot sebagai data field di 2 activity profile:
  - Running (Outdoor)
  - Treadmill
  - Track Run (jika tersedia di FR165)
- [ ] Siapkan stopwatch HP sebagai pembanding waktu
- [ ] Catat baterai awal jam (%)

---

## 1. Settings Sync (WAJIB pertama)

| Test | Langkah | Expected | Actual | Pass? |
|------|---------|----------|--------|-------|
| S1 | Buka Connect IQ Mobile → RacePilot → Settings | 8 setting muncul | | ☐ |
| S2 | Ubah Race Preset → sync | Jam menampilkan target baru | | ☐ |
| S3 | Ubah Run Type = Track → sync | Header `TRACK RUN` muncul | | ☐ |
| S4 | Ubah Run Type = Treadmill → sync | Header `TREADMILL RUN` muncul | | ☐ |
| S5 | Ubah Custom Distance + Time (preset Custom) | Target finis berubah sesuai | | ☐ |
| S6 | Toggle Debug Mode = ON | Baris debug muncul di bawah | | ☐ |
| S7 | Restart jam → buka aktivitas | Setting tersimpan (persist) | | ☐ |

**Catatan:** Jika S1 gagal, seluruh test lain tidak valid → stop & lapor.

---

## 2. Outdoor GPS Run

| Test | Langkah | Expected | Actual | Pass? |
|------|---------|----------|--------|-------|
| O1 | Mulai aktivitas tanpa GPS | Label `WAIT GPS` (teal) | | ☐ |
| O2 | Tunggu GPS lock | Pace muncul tanpa spike awal | | ☐ |
| O3 | Lari stabil 2 menit | Pace stabil, proyeksi stabil | | ☐ |
| O4 | Percepat mendadak | Pace naik wajar (tidak lonjak) | | ☐ |
| O5 | Perlambat mendadak | Pace turun wajar | | ☐ |
| O6 | Lewat tikungan tajam | Pace tidak drop drastis | | ☐ |
| O7 | Lewat bawah pohon/gedung | Pace tidak ekstrem | | ☐ |
| O8 | Masuk tunnel (~5s) | Pace freeze (hold), lalu recover halus | | ☐ |
| O9 | Keluar tunnel | Pace recover gradual, tidak lonjak | | ☐ |
| O10 | Cek proyeksi vs stopwatch | Selisih < 15 detik dari hitungan manual | | ☐ |
| O11 | Cek need pace masuk akal | Antara 3:00–8:00/km untuk target wajar | | ☐ |
| O12 | Auto-pause (berhenti di lampu merah) | State `PAUSED`, proyeksi freeze | | ☐ |
| O13 | Resume | State `RESUMED` → `RACING` | | ☐ |
| O14 | Selesai target | `FINISHED` → `LOCKED` (freeze 3s) | | ☐ |

---

## 3. Treadmill Run (KRITIS — bug historis 24:30/km)

| Test | Langkah | Expected | Actual | Pass? |
|------|---------|----------|--------|-------|
| T1 | Start treadmill dari diam | Header `TREADMILL RUN` + icon | | ☐ |
| T2 | **Detik 0–30** | Pace ≈ pace treadmill (BUKAN 20:00+) | | ☐ |
| T3 | **Detik 30–90 (blending)** | Pace stabil, tidak ada lompatan | | ☐ |
| T4 | Setelah 500m | Pace = 70% native + 30% lap | | ☐ |
| T5 | Bandingkan pace vs layar treadmill | Selisih < 15 detik/km | | ☐ |
| T6 | Naikkan kecepatan treadmill | Pace ikut naik dalam ~5s | | ☐ |
| T7 | Turunkan kecepatan | Pace ikut turun | | ☐ |
| T8 | Berhenti (timer pause) | Freeze, tidak reset | | ☐ |
| T9 | Resume | Lanjut normal | | ☐ |
| T10 | Bandingkan jarak jam vs treadmill (1 km) | Selisih < 50m (kalibrasi 100) | | ☐ |
| T11 | Ubah kalibrasi ke 105, test 1 km lagi | Jarak jam naik ~5% | | ☐ |
| T12 | Pastikan kalibrasi TIDAK dobel | Jarak tidak jadi +10% | | ☐ |

**T2 adalah test paling penting** — inilah bug yang pernah muncul.

---

## 4. Track Run

| Test | Langkah | Expected | Actual | Pass? |
|------|---------|----------|--------|-------|
| R1 | Start di track 400m | Header `TRACK RUN` | | ☐ |
| R2 | Pace unit | `/400m` (bukan `/km`) | | ☐ |
| R3 | Lap count | `LAP 0/12.5` (untuk 5K) | | ☐ |
| R4 | Setelah 1 lap | `LAP 1/12.5`, pace per-lap benar | | ☐ |
| R5 | Lap 2–3 | Lap count naik konsisten | | ☐ |
| R6 | Interval cepat/lambat | Pace per-lap mengikuti | | ☐ |
| R7 | Tekan lap button manual | Lap ter-reset benar | | ☐ |
| R8 | Track 250m (ubah setting) | `/250m`, `LAP x/20` | | ☐ |
| R9 | Target bukan kelipatan lap | Proyeksi tetap masuk akal | | ☐ |
| R10 | Need pace per-lap | `/400m`, bukan `/km` | | ☐ |

---

## 5. State & Edge Cases

| Test | Langkah | Expected | Actual | Pass? |
|------|---------|----------|--------|-------|
| E1 | Tanpa target (preset 0) | `--:--` semua, tidak ada crash | | ☐ |
| E2 | Target = Custom | Berlaku jarak+waktu custom | | ☐ |
| E3 | Ganti target di tengah aktivitas | Langsung sync | | ☐ |
| E4 | Layar di-scroll ke data field lain | Compute tetap jalan (tidak freeze) | | ☐ |
| E5 | Kembali ke RacePilot | Nilai akurat (bukan stale) | | ☐ |
| E6 | Aktivitas sangat lambat (>10:00/km) | Tidak crash, angka wajar | | ☐ |
| E7 | Aktivitas sangat cepat (<3:00/km) | Tidak crash | | ☐ |
| E8 | Jarak 0 (baru start) | `0.00`, tidak NaN | | ☐ |

---

## 6. Battery & Performance

| Test | Langkah | Expected | Actual | Pass? |
|------|---------|----------|--------|-------|
| B1 | Catat baterai sebelum lari 30 menit | Baseline | | ☐ |
| B2 | Setelah 30 menit dengan RacePilot | Drop < 5% (setara data field lain) | | ☐ |
| B3 | Amati kelancaran refresh | Tidak patah-patah/lag | | ☐ |
| B4 | Debug Mode ON vs OFF | Performa tidak beda jauh | | ☐ |

---

## 7. Visual / Readability

| Test | Langkah | Expected | Actual | Pass? |
|------|---------|----------|--------|-------|
| V1 | Di bawah matahari terang | Teks tetap terbaca | | ☐ |
| V2 | Malam hari | Kontras cukup | | ☐ |
| V3 | Semua label tidak terpotong bezel | `LAP PACE`, `NEED PACE` utuh | | ☐ |
| V4 | Header treadmill/track tidak kepotong | Utuh | | ☐ |
| V5 | Cek unit `/km` vs `/400m` konsisten | Sesuai mode | | ☐ |

---

## Kriteria Lulus

**WAJIB lulus semua di section 1 (Settings), 2 (Outdoor core: O1–O4, O10, O14), 3 (Treadmill: T1–T6, T12), 4 (Track: R1–R4).**

Jika ada yang gagal → catat langkah + screenshot → laporkan sebelum publish.

---

## Log Hasil

| Tanggal | Versi | Perangkat | Lulus | Gagal | Catatan |
|---------|-------|-----------|-------|-------|---------|
| | v2.1.0 | FR165 | | | |
