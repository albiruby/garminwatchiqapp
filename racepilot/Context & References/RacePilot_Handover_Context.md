# RacePilot --- Handover Context

> Dokumen handover untuk melanjutkan pengembangan RacePilot tanpa harus
> membaca seluruh riwayat percakapan.
>
> **Tanggal snapshot:** 13 November 2026\
> **Produk:** RacePilot --- Garmin Connect IQ Data Field\
> **Target perangkat yang sudah diuji/dikonfirmasi:** Garmin Forerunner
> 165\
> **Versi terakhir yang disebutkan:** 2.0.0 (build dan package berhasil)

------------------------------------------------------------------------

## 1. Ringkasan Produk

RacePilot adalah Garmin Connect IQ **Data Field** untuk membantu pelari
memantau performa terhadap target jarak dan waktu finis secara langsung
selama aktivitas. Fokus utamanya adalah menampilkan metrik pacing dan
proyeksi race dalam satu layar, dengan engine yang disesuaikan untuk
Outdoor/GPS Run, Track Run, dan Treadmill Run.

Konsep tampilan utama:

-   **Lap Pace** --- pace saat ini yang telah difilter dan distabilkan.
-   **Distance** --- jarak aktivitas.
-   **Time** --- waktu aktivitas.
-   **Projected Finish** --- estimasi waktu finis berdasarkan performa
    saat ini.
-   **Ahead/Behind** --- selisih proyeksi finis terhadap target.
-   **Need Pace** --- pace rata-rata yang dibutuhkan untuk menyelesaikan
    sisa jarak sesuai target.
-   **Track-specific information** --- unit pace per 400 m (atau panjang
    track yang dikonfigurasi) dan penghitung lap.

Tagline yang digunakan pada materi promosi: **"Smarter Pace. Stronger
Finish."**

## 2. Target Platform dan Kompatibilitas

-   Target awal pengembangan dan pengujian: **Forerunner 165**.
-   Simulator yang digunakan: **Connect IQ Simulator --- Forerunner 165
    (5.2.0)**.
-   Aplikasi merupakan **Data Field**, bukan watch app mandiri.
-   Aktivitas yang relevan: Running, Track Run, dan Treadmill Run.
-   Pengembangan universal device compatibility sudah dimulai melalui
    `DeviceProfile.mc`, `FontManager.mc`, dan layout proporsional.
-   Untuk menambah perangkat, SDK perangkat terkait perlu tersedia dan
    product ID perangkat perlu ditambahkan ke `manifest.xml` (misalnya
    `<iq:product id="frXXX"/>`). Jangan menganggap kompatibilitas semua
    Forerunner otomatis terjamin hanya karena layout adaptif; lakukan
    build dan pengujian per device family, ukuran layar, resolusi, dan
    API capability.

### Catatan ukuran layar

Forerunner 165 menggunakan layar AMOLED bulat dengan resolusi **390 ×
390 px**. Layout harus memperhitungkan area aman berbentuk lingkaran,
bukan sekadar canvas persegi. Hindari menempatkan teks penting terlalu
dekat sudut canvas karena area tersebut tidak terlihat pada layar bulat.

## 3. Arsitektur Aplikasi

Arsitektur yang terakhir dilaporkan:

``` text
RacePilotApp.mc
  └── App entry point dan relay settings

RacePilotView.mc
  └── Rendering UI / empat section tampilan

Layout.mc
  └── Measure-first positioning dan responsive layout

DeviceProfile.mc
  └── Device metrics, scale factors, safe area, buffer sizes

FontManager.mc
  └── Semantic font sizing

PaceEngine.mc
  └── Unified orchestration layer
      ├── GPSEngine.mc
      ├── TrackEngine.mc
      └── TreadmillEngine.mc

RunStateMachine.mc
  └── Lifecycle state dan transition handling

PaceFilter.mc
  └── Pace smoothing, median/EWMA, rate limiting, pace lock

PredictionBuffer.mc
  └── Multi-source finish-time prediction

ConfidenceScore.mc
  └── Pace/GPS confidence calculation

TelemetryLayer.mc
  └── Algorithm diagnostics dan performance tracking

UnitTestRunner.mc
  └── Synthetic test scenarios
```

Alur data konseptual:

``` text
Garmin Activity Info
        |
        v
Activity / Run-Type Detection
        |
        v
RunStateMachine + PaceEngine
        |
        +---- GPSEngine (Outdoor GPS)
        |
        +---- TrackEngine (Track Run)
        |
        +---- TreadmillEngine (Treadmill)
        |
        v
PaceFilter + Confidence + PredictionBuffer
        |
        v
Unified Display Values
        |
        v
RacePilotView + Layout
```

Prinsip penting: semua nilai yang ditampilkan UI harus berasal dari satu
jalur output terpusat. Jangan menghitung Projected Finish, Need Pace,
Ahead/Behind, atau Lap Pace secara terpisah di layer rendering karena
dapat menghasilkan angka yang tidak konsisten.

## 4. Tiga Specialized Pace Engines

### 4.1 GPSEngine --- Outdoor Run

Fitur yang sudah dilaporkan:

-   Adaptive GPS confidence berdasarkan kualitas dan variasi data.
-   GPS spike/outlier rejection.
-   Corner protection menggunakan analisis heading agar pace tidak
    bereaksi berlebihan saat berbelok.
-   Tunnel/tree-cover hold dengan grace period (sebelumnya disebut 5
    detik).
-   GPS recovery handling.
-   Pace lock untuk menahan tampilan ketika pace sudah stabil.
-   Relative change filter / pembatas perubahan pace.
-   Grade compensation.
-   Cadence spike detection.
-   GPS quality dan confidence diagnostics.

Tujuan: pace tidak melonjak atau drop secara tidak realistis akibat
noise GPS, tikungan, pepohonan, tunnel, atau perubahan kualitas sinyal.

### 4.2 TrackEngine --- Track Run

Konfigurasi dan fitur yang sudah dilaporkan:

-   Default satu lap = **400 m**.

-   Track length dapat dikonfigurasi; dukungan panjang custom perlu
    diverifikasi sesuai implementasi final.

-   Pace ditampilkan per satu putaran track, bukan per kilometer.

-   Rumus dasar pace per lap:

    `lap pace = (lap time / lap distance) × configured lap length`

-   Lap counter dengan format seperti `12/12.5` (completed laps /
    estimated total laps).

-   Auto-detect lap menggunakan jarak lap Garmin sekitar 350--450 m pada
    implementasi awal.

-   Lap transition prediction sekitar 395 m.

-   Lap blending pada sekitar 50 m pertama setelah transisi lap.

-   Split buffer.

-   Interval detection berdasarkan variasi pace; implementasi awal
    menyebut variance di atas 8 detik per 400 m.

-   Hysteresis lebih ketat (implementasi awal menyebut threshold 0.5
    detik).

-   Tidak menghitung pace dari koordinat GPS secara mandiri;
    mengandalkan corrected distance Garmin.

-   Track mode tidak menunggu GPS lock untuk berpindah ke state racing
    ketika timer berjalan.

**Penting untuk validasi:** Track Run tidak selalu berarti lap aktual
tepat 400 m. Lane, garis start/finish, posisi pelari, dan pengukuran
perangkat dapat menyebabkan variasi. Pastikan konfigurasi track length
dipakai konsisten oleh lap detection, lap pace, lap count, projected
finish, dan need pace. Jangan mengunci asumsi 400 m di sebagian modul
sementara modul lain memakai nilai konfigurasi.

### 4.3 TreadmillEngine --- Treadmill Run

Implementasi yang dilaporkan:

-   Warmup phase menggunakan Garmin native pace (`currentSpeed`) secara
    eksklusif.
-   Warmup awal: 0--200 m; parameter tambahan yang pernah disebut adalah
    30 detik / 10 sampel.
-   Minimum lap distance pernah dinaikkan dari 20 m menjadi 50 m.
-   Pace sanity check menolak nilai di luar rentang 2:00--15:00 min/km.
-   Treadmill memprioritaskan Garmin pace dibanding calculated pace.
-   Setelah warmup, masuk progressive blending (sekitar 200--500 m),
    lalu normal engine.
-   Distance delta validation menolak lonjakan jarak yang tidak masuk
    akal (pernah disebut \>5 m/s).
-   Treadmill calibration multiplier tersedia di settings.

Masalah historis yang memicu perbaikan: pada awal treadmill run,
RacePilot pernah menampilkan pace sekitar 24:30/km sementara data field
Garmin lain menunjukkan 5:50/km. Setelah sekitar 1 km, pace baru
mengikuti. Warmup native-pace priority dan sanity check ditambahkan
untuk mengatasi masalah tersebut.

**Validasi wajib:** pastikan pace sudah masuk akal sejak awal aktivitas,
tidak menampilkan nilai ekstrem, dan tidak mengalami transisi mendadak
ketika berpindah dari warmup ke blending dan normal phase.

## 5. Unified Pace Engine dan Stabilitas Algoritma

Perubahan yang telah dilaporkan:

-   `PaceEngine.mc` menjadi orchestrator untuk tiga engine.
-   `PaceFilter.mc` mengintegrasikan EWMA, median filter, rate limiter,
    pace lock, dan adaptive alpha.
-   `PredictionBuffer.mc` memakai beberapa sumber berbobot: instant
    pace, lap pace, EWMA, dan historical data.
-   Projection lock digunakan untuk menghindari projected finish berubah
    terlalu liar.
-   `ConfidenceScore` menghitung confidence berdasarkan activity info,
    pace, dan ketersediaan GPS.
-   `TelemetryLayer.mc` mencatat pace variance, rejection rate, dan
    distribusi GPS.
-   Filtering dan prediction diintegrasikan dengan state machine.

Target perilaku:

1.  Pace tidak boleh tiba-tiba berubah dari angka wajar menjadi angka
    ekstrem tanpa bukti data yang kuat.
2.  Pace harus cukup responsif ketika pelari benar-benar mempercepat
    atau memperlambat.
3.  Smoothing tidak boleh terlalu agresif hingga menimbulkan delay
    panjang.
4.  Outdoor, Track, dan Treadmill boleh menggunakan sumber data berbeda,
    tetapi output dan definisi metrik harus konsisten.
5.  Invalid/stale data harus ditandai atau diabaikan, bukan diam-diam
    dipakai untuk proyeksi.
6.  Saat confidence rendah, sistem harus memilih hold/fallback yang aman
    daripada menampilkan angka palsu.
7.  Seluruh perhitungan harus menangani nilai nol, null, negative,
    NaN/infinity, timer pause, dan perubahan state.

## 6. Run State Machine

State yang pernah dilaporkan:

-   `NO_TARGET`
-   `IDLE`
-   `GPS_ACQUIRING`
-   `WAIT_GPS`
-   `READY`
-   `COUNTDOWN`
-   `RACING`
-   `PAUSED`
-   `RESUMED`
-   `AUTO_PAUSED`
-   `MANUAL_PAUSED`
-   `FINISHING`
-   `FINISHED`
-   `LOCKED`

Ada beberapa nama state yang muncul pada iterasi berbeda. Periksa enum
dan implementasi aktual agar tidak ada state duplikat atau transisi yang
tidak dapat dicapai.

Fitur yang dilaporkan:

-   Finish lock.
-   Auto-pause dan manual-pause handling.
-   Finishing zone.
-   `shouldFreezeProjections()`.
-   `shouldHideNeedPace()`.
-   State-aware display behavior.

Aturan yang harus dijaga:

-   Saat paused, waktu dan proyeksi tidak boleh terus berjalan seolah
    aktivitas aktif.
-   Saat target belum valid, jangan tampilkan proyeksi atau need pace
    yang menyesatkan.
-   Ketika target tercapai, jangan biarkan status kembali menjadi racing
    akibat noise jarak.
-   Finish lock harus mencegah flicker di sekitar garis finis.
-   GPS acquisition hanya relevan untuk mode yang membutuhkan GPS.
-   Track dan treadmill tidak boleh tertahan oleh GPS requirement yang
    tidak relevan.

## 7. Race Presets dan Target

Implementasi yang pernah dilaporkan:

-   Total **46 race presets**.
-   5K: 14 preset, dari Sub 18:00 sampai Sub 35:00.
-   10K: 11 preset, dari Sub 40:00 sampai Sub 70:00.
-   Half Marathon: 10 preset, dari Sub 1:20 sampai Sub 2:30.
-   Marathon: 9 preset, dari Sub 2:30 sampai Sub 5:00.
-   Custom: 1 pilihan.
-   Custom distance dan custom target time.

Target yang dipilih harus menjadi single source of truth untuk:

-   Target distance.
-   Target finish time.
-   Goal pace.
-   Projected finish.
-   Need pace.
-   Ahead/behind delta.
-   Total lap untuk Track Run.

Periksa konsistensi satuan: meter vs kilometer, detik vs menit, pace per
km vs pace per lap. Untuk custom time, jangan mengasumsikan input menit
selalu cukup jika UI/code mendukung jam dan detik.

## 8. Settings yang Terlihat di Garmin Connect IQ Mobile

Setelah perbaikan settings, halaman Settings akhirnya dilaporkan muncul
di Connect IQ Mobile. Screenshot memperlihatkan delapan setting berikut:

  Setting                          Nilai pada screenshot Fungsi
  ------------------------------ ----------------------- ----------------------------------------
  Race Preset                                 Set Target Memilih preset jarak dan target finish
  Custom Distance (m)                               5000 Jarak custom dalam meter
  Custom Time (min)                                   30 Target waktu custom dalam menit
  Run Type                                   Auto Detect Auto, Outdoor, Track, atau Treadmill
  Treadmill Calibration (x100)                       100 Faktor kalibrasi treadmill
  Track Length                                      400m Panjang lap track
  Pace Smoothing                                      50 Tingkat smoothing/responsivitas pace
  Debug Mode                                         Off Menampilkan diagnostik internal

### Penjelasan setting

**Race Preset**\
Memilih target race siap pakai. RacePilot memakai jarak dan waktu target
untuk menghitung goal pace, projected finish, ahead/behind, dan need
pace.

**Custom Distance (m)**\
Dipakai ketika Race Preset memilih Custom. Masukkan jarak total dalam
meter. Contoh: 3000, 5000, 7500, 10000, 21097, atau 42195.

**Custom Time (min)**\
Dipakai bersama Custom Distance untuk menentukan target finish. Pastikan
implementasi aktual mengubah menit menjadi detik secara konsisten.

**Run Type**\
- Auto Detect: aplikasi memilih engine berdasarkan jenis aktivitas atau
sinyal yang tersedia. - Outdoor Run: engine berbasis GPS. - Track Run:
engine track dengan pace per lap. - Treadmill Run: engine treadmill yang
mengutamakan data pace Garmin.

**Treadmill Calibration (x100)**\
Nilai 100 berarti faktor 1.00 atau tidak ada penyesuaian. Contoh 105
berarti faktor 1.05. Ini dimaksudkan untuk mengoreksi perbedaan
konsisten antara jarak treadmill dan jarak yang dicatat Garmin. Jangan
mengubahnya tanpa membandingkan jarak Garmin dengan jarak treadmill
setelah kalibrasi. Pastikan arah penerapan multiplier benar dan
terdokumentasi di kode.

**Track Length**\
Panjang satu putaran track. Default 400 m. Ubah hanya jika menggunakan
track dengan panjang berbeda dan pastikan semua perhitungan memakai
nilai yang sama.

**Pace Smoothing**\
Mengontrol kompromi antara respons cepat dan tampilan pace yang stabil.
Nilai lebih rendah cenderung lebih responsif dan lebih sensitif terhadap
fluktuasi; nilai lebih tinggi cenderung lebih halus tetapi dapat
menambah delay. Screenshot menunjukkan nilai 50. Arti matematis tepat,
rentang valid, dan arah skala harus dikonfirmasi dari implementasi
aktual.

**Debug Mode**\
Menampilkan informasi diagnostik seperti confidence, engine aktif, GPS
quality, filtering status, dan prediction diagnostics. Sebaiknya Off
untuk penggunaan normal/store build.

### Riwayat masalah settings

-   Awalnya settings tidak muncul di Garmin Connect IQ Mobile walaupun
    app sudah beberapa kali di-update.
-   Akar masalah yang ditemukan: `properties.xml` memiliki 38 property
    ID yang tidak cocok dengan ID yang dipakai kode.
-   `settings.xml` juga mereferensikan ID yang salah.
-   `strings.xml` kehilangan beberapa string resource.
-   File konfigurasi kemudian ditulis ulang agar konsisten.
-   Property ID yang disebut dalam perbaikan: `RacePrefs`,
    `CustomDistM`, `CustomTimeMin`, `RunType`, `TreadmillCalib`,
    `TrackLapLen`, `PaceSmoothing`, `DebugMode`.
-   Periksa kembali bahwa ID di `properties.xml`, `settings.xml`,
    `strings.xml`, dan kode Monkey C benar-benar sama persis. Jangan
    menambahkan banyak setting tanpa menguji batasan platform dan
    tampilan mobile.

## 9. UI dan Layout

Tampilan utama dirancang sebagai satu data field dengan empat area:

``` text
┌─────────────────────────────┐
│          LAP PACE           │
│           5:30/km           │
├──────────────┬──────────────┤
│   DISTANCE   │     TIME     │
│     3.20     │    12:45     │
├─────────────────────────────┤
│       PROJECTED FINISH      │
│           25:05             │
│       +0:04 AHEAD           │
├─────────────────────────────┤
│          NEED PACE          │
│           5:15/km           │
│       TRACK LAP COUNT       │
└─────────────────────────────┘
```

Untuk Track Run, unit pace berubah menjadi per lap (misalnya `/400m`)
dan badge `TRACK RUN` serta lap count dapat ditampilkan.

Prinsip layout:

-   Rendering harus dipisahkan dari business logic.
-   Gunakan measure-first positioning.
-   Gunakan device profile dan semantic font manager.
-   Hindari hardcoded pixel positions.
-   Perhitungkan safe area layar bulat.
-   Ukuran font harus menyesuaikan panjang angka, bukan hanya ukuran
    layar.
-   Jangan biarkan label dan nilai saling bertabrakan.
-   Uji nilai ekstrem: pace satu digit menit, waktu lebih dari 99 menit,
    jarak panjang, angka placeholder, dan label status terpanjang.
-   Pastikan tampilan tetap terbaca dalam kondisi data kosong, GPS
    acquiring, paused, finished, dan no target.
-   Optimalkan refresh dan battery usage.

## 10. Build, Package, dan File

Status terakhir yang dilaporkan:

-   Build berhasil.
-   Package berhasil.
-   Package: `RacePilot.iq`.
-   Path Windows yang pernah disebut: `D:\GarminRacePilot\RacePilot.iq`.
-   Versi yang disebut setelah universal device compatibility: `2.0.0`.
-   Sebelumnya versi 1.1.0 dan beberapa iterasi v1.2/v1.3 juga disebut.
-   Build warnings yang pernah muncul: container types dan icon size;
    pernah disebut non-critical.

**Catatan:** status build sukses bukan bukti bahwa semua fitur benar
secara runtime. File `.iq`, source code, dan SDK tidak disertakan dalam
handover ini. Path di atas berasal dari riwayat percakapan dan perlu
diverifikasi di mesin pengembang.

## 11. Testing yang Sudah Disebut

-   Connect IQ Simulator untuk Forerunner 165.
-   Treadmill test di jam fisik dilaporkan cukup baik, dengan masalah
    awal pace delay yang kemudian ditangani melalui warmup/native pace
    priority.
-   `UnitTestRunner.mc` dibuat dengan 10 synthetic test scenarios.
-   `TelemetryLayer.mc` dibuat untuk memantau performa algoritma.

Simulator pernah memiliki keterbatasan: tombol fisik/simulator tidak
selalu berfungsi seperti aktivitas nyata karena Data Field membutuhkan
Activity context.

## 12. Known Issues dan Hal yang Masih Harus Diverifikasi

Berikut bukan klaim bahwa semua masalah masih terjadi; ini daftar risiko
dan verifikasi yang perlu dilakukan berdasarkan riwayat:

1.  **Pace smoothing vs responsiveness:** pastikan smoothing tidak
    menyebabkan delay panjang, khususnya pada treadmill startup,
    akselerasi, dan perubahan pace yang nyata.
2.  **GPS pace stability:** uji area terbuka, tikungan tajam, pepohonan,
    gedung tinggi, tunnel, dan GPS recovery.
3.  **Track lap detection:** uji lap pertama, lap terakhir, interval
    cepat/lambat, auto-lap Garmin, manual lap, dan panjang track non-400
    m.
4.  **Track pace unit:** pastikan UI, projected finish, need pace, dan
    split menggunakan unit yang benar dan tidak mencampur `/km` dengan
    `/400m`.
5.  **Treadmill calibration:** pastikan faktor x100 diterapkan dengan
    arah dan titik pipeline yang benar; cegah kalibrasi diterapkan dua
    kali.
6.  **Target changes:** ubah preset atau custom target sebelum aktivitas
    dan pastikan seluruh output langsung sinkron.
7.  **State transitions:** uji auto-pause, manual pause, resume, GPS
    loss, finish zone, finish lock, dan activity restart.
8.  **Prediction stability:** uji proyeksi saat pace berubah, berhenti,
    berjalan, dan data confidence rendah.
9.  **Data validity:** pastikan nilai nol, stale, null, NaN, infinity,
    negative, dan lonjakan data ditangani aman.
10. **Settings persistence:** simpan setting di Connect IQ Mobile, tutup
    aplikasi, sinkronkan perangkat, lalu verifikasi nilai di jam.
11. **Device compatibility:** build dan uji tiap perangkat yang
    ditambahkan ke manifest. Responsive layout saja tidak menjamin API
    dan behavior kompatibel.
12. **Battery/refresh:** ukur konsumsi baterai dan pastikan tidak ada
    perhitungan mahal yang berjalan terlalu sering.
13. **Memory/performance:** uji buffer dan telemetry dalam aktivitas
    panjang; pastikan array/buffer dibatasi dan tidak tumbuh tanpa
    batas.
14. **Store compliance:** cek manifest, permissions, metadata, privacy
    policy bila diperlukan, icon, screenshots, description, dan What's
    New sebelum upload.
15. **Warning cleanup:** evaluasi warning container types dan icon size;
    jangan menganggap aman sebelum memahami dampaknya.
16. **Regression tests:** setiap perubahan engine harus diuji pada
    ketiga mode, bukan hanya mode yang sedang diperbaiki.

## 13. Skenario Acceptance Test yang Direkomendasikan

### Outdoor GPS Run

-   Start tanpa GPS: tampilkan acquiring/ready state yang jelas.
-   GPS lock: pace muncul tanpa spike awal.
-   Lari stabil: pace dan projected finish stabil.
-   Percepat/perlambat: output mengikuti secara wajar tanpa lonjakan.
-   Tikungan, pepohonan, gedung, dan kehilangan GPS: pace tidak menjadi
    angka ekstrem.
-   Finish target: ahead/behind dan finish lock benar.

### Track Run

-   Track 400 m dengan Auto Lap aktif dan nonaktif.
-   Track dengan panjang custom.
-   Lap pertama dan transisi lap.
-   Interval cepat/lambat.
-   Target jarak yang bukan kelipatan panjang lap.
-   Validasi lap count, lap pace, projected finish, dan need pace.
-   Pastikan tidak membutuhkan GPS lock jika desain engine memang tidak
    memerlukannya.

### Treadmill Run

-   Start dari kondisi diam.
-   Pace treadmill stabil sejak awal.
-   Perubahan kecepatan treadmill.
-   Stop sementara dan resume.
-   Kalibrasi default 100 dan nilai kalibrasi yang telah diuji.
-   Perbandingan jarak Garmin dengan jarak treadmill.
-   Pastikan tidak ada pace ekstrem atau transisi mendadak antar fase.

### Cross-mode / lifecycle

-   Ubah Run Type Auto Detect dan tiap mode manual.
-   Ubah target sebelum aktivitas.
-   Pause/resume.
-   Auto-pause.
-   Activity selesai dan mulai ulang.
-   Settings persistence setelah sync.
-   Uji seluruh state dengan target valid dan tanpa target.

## 14. Store Listing dan Materi Visual

Materi yang sudah dibuat/dibahas:

-   Hero image Connect IQ Store: spesifikasi **1440 × 720 px**,
    JPG/GIF/PNG, maksimal 2048 KB.
-   Cover image: **500 × 500 px**, maksimal 300 KB.
-   Screen images: maksimal 150 KB per image.
-   Screen image campaign menampilkan lima kondisi:
    -   At a Glance
    -   Ahead of Target
    -   Behind Target
    -   Treadmill Run
    -   Track Run
-   Materi visual menggunakan tema gelap, aksen oranye, teks putih, dan
    identitas RacePilot.
-   Infografik RacePilot Settings Guide sudah dibuat dalam versi
    portrait dan landscape.
-   Versi landscape menjelaskan delapan setting, termasuk quick
    recommendations.

### Catatan angka pada screenshot promosi

Angka yang ditampilkan harus konsisten secara matematis. Jangan memakai
data contoh acak. Untuk setiap contoh, hitung ulang: - Pace = waktu /
jarak. - Projected finish = proyeksi waktu untuk target distance. - Need
pace = sisa waktu / sisa jarak. - Ahead/behind = target finish time
dibanding projected finish. - Track pace = waktu lap untuk panjang lap
yang dikonfigurasi.

Pastikan definisi tanda positif/negatif pada ahead/behind konsisten di
UI, algoritma, dan materi promosi.

## 15. Prinsip Pengembangan yang Harus Dipertahankan

1.  **Correctness before features.** Jangan menambah fitur sebelum
    perhitungan inti dan lifecycle stabil.
2.  **Single source of truth.** Semua display values berasal dari
    unified output.
3.  **Mode-specific engines.** GPS, Track, dan Treadmill memiliki
    karakteristik data yang berbeda; jangan memaksa satu algoritma
    mentah untuk semuanya.
4.  **Fail safe.** Data tidak valid harus ditolak atau ditahan, bukan
    menghasilkan pace/proyeksi palsu.
5.  **Responsive, not jumpy.** Pace harus stabil tetapi tetap responsif.
6.  **Units must be explicit.** Meter, kilometer, second, minute, `/km`,
    dan `/lap` tidak boleh tercampur.
7.  **Device-aware UI.** Semua ukuran dan posisi mengikuti device
    profile serta safe area.
8.  **Test on hardware.** Simulator saja tidak cukup untuk memvalidasi
    sensor, GPS, treadmill, dan perilaku aktivitas.
9.  **Settings parity.** XML, app code, dan UI mobile harus sinkron.
10. **No unsupported claims.** Jangan mengklaim kompatibel dengan semua
    Forerunner sebelum pengujian nyata per perangkat.

## 16. Prioritas Kerja Berikutnya

Urutan kerja yang disarankan:

1.  Audit source code aktual terhadap arsitektur dan ringkasan ini;
    tandai bagian yang benar-benar ada vs yang baru direncanakan.
2.  Buat test matrix dan jalankan regression test untuk Outdoor GPS,
    Track, dan Treadmill.
3.  Audit semua formula dan satuan untuk pace, projected finish, need
    pace, ahead/behind, dan lap count.
4.  Validasi smoothing dan prediction menggunakan data aktivitas nyata,
    terutama startup dan perubahan pace.
5.  Uji settings end-to-end: Connect IQ Mobile → sync → jam → runtime
    behavior.
6.  Uji layout di Forerunner 165 dan perangkat tambahan yang akan
    didukung.
7.  Audit memory, battery, refresh rate, dan buffer lifecycle.
8.  Bersihkan warning build yang relevan.
9.  Siapkan release candidate, changelog, metadata, dan materi store
    yang sesuai dengan fitur yang benar-benar diuji.

------------------------------------------------------------------------

## 17. Informasi yang Belum Tersedia dalam Handover

Untuk melanjutkan implementasi secara presisi, lengkapi dokumen ini
dengan:

-   Source code terbaru seluruh file `.mc`, XML, dan manifest.
-   `manifest.xml` final beserta daftar device product ID.
-   SDK/Monkey C version yang digunakan untuk build.
-   Formula aktual dan rentang valid setiap setting.
-   Daftar 10 synthetic test scenarios beserta expected/actual result.
-   Contoh file FIT/rekaman aktivitas untuk Outdoor, Track, dan
    Treadmill.
-   Screenshot UI terbaru dari perangkat fisik.
-   Daftar warning build lengkap.
-   Status review/publishing Connect IQ Store terkini.

**Status handover:** ringkasan ini merekam keputusan, arsitektur, fitur,
bug historis, settings, materi promosi, dan prioritas pengujian yang
disebutkan dalam percakapan. Ini bukan audit source code dan tidak
menggantikan verifikasi implementasi aktual.
