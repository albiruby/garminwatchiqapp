# DC Rainmaker — COROS Pace 4 (foto jam asli)

Sumber: https://www.dcrainmaker.com/2025/11/coros-pace-4-in-depth-sports-review.html

## File (10 foto jam asli)
- `01-menu-run.jpg` — menu Run / Indoor Run / Trail Run
- `02-flashlight.jpg` — grid menu sistem (ikon warna-warni)
- `03-map-navigation.jpg` — peta breadcrumb + jarak 12.42 km
- `04-race-predictor.jpg` — tabel Race Predictor (5K/10K/Half/Marathon + waktu)
- `05-running-fitness.jpg` — Running Fitness 84.3 + bar
- `06-training-load.jpg` — Training Load 606 TL + status
- `07-watchface-color.jpg` — watchface warna-warni (17:48)
- `08-app-grid.jpg` — grid ikon aplikasi
- `09-watchface-green.jpg` — watchface hijau (08:36)
- `10-target-run.jpg` — layar workout Target Run + navigasi

## Gaya Visual UI yang terlihat
- Menu: ikon kecil + teks putih, satu item terpilih; font ramping, spasi lega
- Race Predictor: **tabel 2 kolom (jarak | waktu)** dengan bar warna per baris — pola tabel kompak terbaik untuk referensi kita
- Running Fitness / Training Load: **satu angka hero + bar + label status** — sama dengan pola Projected Finish + delta kita
- Watchface: angka outline/warna berani (hijau, multicolor) di atas hitam — berani tapi tetap terbaca
- Peta: garis breadcrumb cyan di atas hitam, label jarak oranye di bawah

## Relevan untuk RacePilot
- Tabel Race Predictor mereka = validasi bahwa proyeksi per-jarak dalam tabel kompak bekerja di layar kecil
- Pola "angka hero + bar + status" sudah sama dengan arsitektur kita (Projected + delta)
- Bar warna tersegmentasi (Running Fitness) = kandidat pola untuk confidence indicator
- Menu ikon + teks mereka lebih padat dari kita; kita tetap di jalur minimalis (4 metrik) — benar untuk data field
