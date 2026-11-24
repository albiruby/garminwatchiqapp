# Frandroid Review — Suunto Run (foto on-wrist, kondisi nyata)

Sumber: https://www.frandroid.com/marques/suunto/2611795_test-de-la-suunto-run-une-course-sans-faute-a-un-prix-mini

## File (9 foto on-wrist, UI terbaca)
- `01-sport-menu.jpg` — daftar sport mode (ikon kuning + nama)
- `02-weekly-bars.jpg` — bar chart mingguan kuning di atas hitam
- `03-hr-zones.jpg` — zona HR dengan bar warna
- `04-recovery.jpg` — layar recovery (angka + status)
- `05-settings-list.jpg` — daftar settings (ikon + teks)
- `06-notifications.jpg` — daftar notifikasi
- `07-watchface-1155.jpg` — watchface analog-digital (11:55)
- `08-system-menu.jpg` — menu sistem (ikon + teks)
- `09-stopwatch.jpg` — stopwatch 00:03.1 (angka merah/putih)

## Gaya Visual UI yang terlihat (kondisi cahaya nyata, bukan render)
- Keterbacaan di bawah sinar matahari: putih di atas hitam tetap kontras — validasi pilihan background hitam kita
- Menu: ikon lingkaran kuning + teks putih + sub-teks abu-abu — konsisten di semua layar
- Bar chart kuning di atas hitam = kontras tertinggi untuk progres (kandidat pola progress target kita)
- Stopwatch: angka besar putih + desimal merah — aksen merah hanya untuk fraksi terkecil
- Watchface 11:55: jarum + angka digital hijau-kuning — contoh penggunaan warna berani yang tetap terbaca

## Relevan untuk RacePilot
- Foto-foto ini membuktikan pola kita (putih + 1 aksen + abu-abu) terbaca di kondisi nyata, bukan cuma render studio
- Bar chart kuning = pola terbaik untuk indikator progres target / confidence
- Desimal merah pada stopwatch = ide untuk menampilkan fraksi detik hanya saat relevan (misal delta < 10 detik)
