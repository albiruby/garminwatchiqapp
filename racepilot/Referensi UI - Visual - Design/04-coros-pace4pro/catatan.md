# COROS Pace 4 Pro — Catatan Desain

Sumber: https://coros.com/pace4pro

## File
- `01-hero.png` — hero (1.47" AMOLED, titanium, 43 g)
- `02-page.png` — full page (LTPO refresh, peta, voice, HRV, flashlight)
- `03-training-zones.png` — layar training zones (HR 168 bpm + zone bar + pace + distance)

## Gaya Visual UI (dari 03-training-zones.png — acuan terbaik)
- Background navy gelap (~`#0A1628`), bukan hitam pekat — alternatif palet untuk tema kita
- Angka hero raksasa putih (168 + "bpm" kecil menempel kanan atas)
- Zone bar tersegmentasi (biru→cyan→hijau→kuning→oranye→merah) dengan marker segitiga putih di zona aktif
- Label kategori merah ("Heart Rate"), label metrik oranye ("Pace", "Distance")
- Dua metrik sejajar di bawah: pace `4'53"` + distance `12.19`, format pace pakai `'`/`"` bukan `:`

## Tipografi
- Angka: sans-serif inflated/bold, sangat besar, tabular
- Unit menempel kecil di kanan atas angka (bukan baseline bawah seperti kita)
- Label kategori: kecil, berwarna (bukan abu-abu)

## Warna
- BG navy `#0A1628`, teks `#FFFFFF`
- Zone: biru, cyan, hijau, kuning, oranye, merah (standar HR zone)
- Label metrik: oranye (`#FFA500`-ish); label kategori: merah muda/merah

## Relevan untuk RacePilot
- Alternatif unit menempel kanan-atas (vs baseline-bawah kita) — patut diuji keterbacaannya
- Zone bar tersegmentasi = pola bagus untuk confidence indicator atau progress target
- Format pace `4'53"` vs `4:53` — kita pakai `:`, konsisten dengan Garmin; jangan ganti
- Navy sebagai alternatif tema gelap selain hitam pekat (opsi Theme v2.2)
