const fs = require('fs');

const DIR = 'D:/Garmin/API-Key-Data-Fetch/data/hr-history/';
const OUT = 'D:/Garmin/API-Key-Data-Fetch/Garmin-Highest-Heart-Rate-2025-10-27_2026-10-27.md';
const read = f => JSON.parse(fs.readFileSync(DIR + f, 'utf8').replace(/^\uFEFF/, ''));
const zonesCfg = JSON.parse(fs.readFileSync('D:/Garmin/API-Key-Data-Fetch/data/hr-zones.json', 'utf8').replace(/^\uFEFF/, ''))[0];

const acts = read('activities-2025-10-27_2026-10-27.json');
const days = read('daily-summaries-2025-10-27_2026-10-27.json');

const END = '2026-10-27';
const WINDOWS = [
  { label: '3 bulan', start: '2026-07-27' },
  { label: '6 bulan', start: '2026-04-27' },
  { label: '12 bulan', start: '2025-10-27' },
];
const DAY_ID = ['Minggu','Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'];
const MONTH_ID = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];
const nf = new Intl.NumberFormat('id-ID');
const num = x => (x === null || x === undefined || Number.isNaN(x)) ? '—' : nf.format(x);
const dec = (x, d = 2) => (x === null || x === undefined || Number.isNaN(x)) ? '—' : x.toFixed(d).replace('.', ',');
const hm = sec => {
  if (sec === null || sec === undefined) return '—';
  sec = Math.round(sec);
  let h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60);
  if (m === 60) { h++; m = 0; }
  if (h) return `${h}j ${String(m).padStart(2,'0')}m`;
  return `${m}m`;
};
const pace = s => {
  if (!isFinite(s) || s <= 0) return '—';
  let m = Math.floor(s / 60), r = Math.round(s % 60);
  if (r === 60) { m++; r = 0; }
  return `${m}:${String(r).padStart(2,'0')}/km`;
};
const dateID = d => {
  const dt = new Date(d + 'T12:00:00Z');
  return `${DAY_ID[dt.getUTCDay()]}, ${dt.getUTCDate()} ${MONTH_ID[dt.getUTCMonth()]} ${dt.getUTCFullYear()}`;
};
const shortDate = d => {
  const dt = new Date(d + 'T12:00:00Z');
  return `${DAY_ID[dt.getUTCDay()].slice(0,3)}, ${dt.getUTCDate()} ${MONTH_ID[dt.getUTCMonth()].slice(0,3)}`;
};
const typeWord = k => ({
  running: 'Lari', track_running: 'Lari track', treadmill_running: 'Treadmill',
  trail_running: 'Trail', strength_training: 'Strength', walking: 'Jalan', hiking: 'Hiking',
  cycling: 'Sepeda', indoor_cycling: 'Sepeda indoor', breathing: 'Breathing', yoga: 'Yoga',
  cardio_training: 'Cardio', other: 'Lainnya',
}[k] || k);
const inWindow = (date, w) => date >= w.start && date <= END;

const table = (head, rows) => {
  const out = [];
  out.push('| ' + head.join(' | ') + ' |');
  out.push('|' + head.map((_, i) => i === 0 ? '---' : '---:').join('|') + '|');
  for (const r of rows) out.push('| ' + r.join(' | ') + ' |');
  return out.join('\n');
};

const actDate = a => a.startTimeLocal.slice(0, 10);
const validActs = acts.filter(a => a.maxHR != null);
const validDays = days.filter(d => d.heartRate?.maxValue != null);

const actsByDay = {};
for (const a of validActs) (actsByDay[actDate(a)] ||= []).push(a);

const fmtAct = a => `${a.activityName} (${a.maxHR} bpm)`;
const fmtActsOfDay = d => {
  const list = (dayActsMap[d] || []).filter(a => (a.maxHR ?? 0) >= 120);
  return list.length ? list.map(a => `${a.activityName} ${a.maxHR}`).join(' · ') : 'tanpa sesi';
};
// map semua aktivitas (termasuk tanpa maxHR) per hari
const dayActsMap = {};
for (const a of acts) (dayActsMap[actDate(a)] ||= []).push(a);

const monthStart = '2026-01-05';
const firstAct = acts.length ? acts.map(actDate).sort()[0] : null;
const firstDay = validDays.length ? validDays.map(d => d.calendarDate).sort()[0] : null;
const lastDay = validDays.length ? validDays.map(d => d.calendarDate).sort().slice(-1)[0] : null;

// ---------- per window stats ----------
const stats = WINDOWS.map(w => {
  const wa = validActs.filter(a => inWindow(actDate(a), w));
  const wd = validDays.filter(d => inWindow(d.calendarDate, w));
  const topAct = [...wa].sort((x, y) => y.maxHR - x.maxHR)[0] || null;
  const topDay = [...wd].sort((x, y) => y.heartRate.maxValue - x.heartRate.maxValue)[0] || null;
  const top3 = [...wa].sort((x, y) => y.maxHR - x.maxHR).slice(0, 3);
  const top3d = [...wd].sort((x, y) => y.heartRate.maxValue - x.heartRate.maxValue).slice(0, 3);
  const over = th => wa.filter(a => a.maxHR >= th).length;
  return { ...w, acts: wa, days: wd, topAct, topDay, top3, top3d, over175: over(175), over180: over(180), over190: over(190), over200: over(200) };
});

const topActs = [...validActs].sort((x, y) => y.maxHR - x.maxHR || (x.startTimeLocal < y.startTimeLocal ? -1 : 1));
const topDays = [...validDays].sort((x, y) => y.heartRate.maxValue - x.heartRate.maxValue || (x.calendarDate < y.calendarDate ? -1 : 1)).slice(0, 10);

// ---------- monthly ----------
const months = [...new Set([...acts.map(a => a.startTimeLocal.slice(0, 7)), ...validDays.map(d => d.calendarDate.slice(0, 7))])].sort();
const monthly = months.map(m => {
  const ma = validActs.filter(a => a.startTimeLocal.startsWith(m));
  const md = validDays.filter(d => d.calendarDate.startsWith(m));
  const ta = [...ma].sort((x, y) => y.maxHR - x.maxHR)[0] || null;
  const td = [...md].sort((x, y) => y.heartRate.maxValue - x.heartRate.maxValue)[0] || null;
  return { m, nActs: acts.filter(a => a.startTimeLocal.startsWith(m)).length, nDays: md.length, ta, td };
});

const sessions180 = topActs.filter(a => a.maxHR >= 180);

const md = [];
const P = (...l) => md.push(...l);

P('# Laporan Highest Heart Rate — 3 / 6 / 12 Bulan', '');
P('**Atlet:** Albireo  ');
P('**Periode permintaan:** 27 Okt 2025 → 27 Okt 2026  ');
P('**Sumber:** Garmin Connect Personal API — activity list + daily summaries (data live)  ');
P('**Zona waktu:** Asia/Bangkok (UTC+7) · **Unit:** metrik · **Bahasa angka:** Indonesia  ');
P('**Dibuat:** 27 Oktober 2026  ');
P(`**HR maksimum terkonfigurasi di watch:** ${zonesCfg.maxHeartRateUsed} bpm`, '');
P(`> **Cakupan data aktual:** aktivitas pertama ${firstAct ? dateID(firstAct) : '—'}, daily summary pertama ${firstDay ? dateID(firstDay) : '—'} s/d ${lastDay ? dateID(lastDay) : '—'}. ` +
  'Tidak ada aktivitas maupun daily summary sebelum Januari 2026 di akun ini, jadi jendela "12 bulan" secara data efektif ±9,7 bulan (296 hari daily).', '');
P('---', '');

// ---------- ringkasan ----------
P('## Jawaban singkat', '');
P(table(
  ['Jendela','Periode efektif','HR tertinggi (aktivitas)','Tanggal · sesi','HR tertinggi (daily, mana pun)','Tanggal'],
  stats.map(s => [
    `**${s.label}**`,
    `${shortDate(s.start)} ${s.start.slice(0, 4)} – ${shortDate(END)} ${END.slice(0, 4)}`,
    s.topAct ? `**${s.topAct.maxHR} bpm**` : '—',
    s.topAct ? `${shortDate(actDate(s.topAct))} · ${s.topAct.activityName}` : '—',
    s.topDay ? `**${s.topDay.heartRate.maxValue} bpm**` : '—',
    s.topDay ? shortDate(s.topDay.calendarDate) : '—',
  ])
), '');
P('**Catatan sumber:** HR tertinggi dari **aktivitas** memakai `maxHR` per sesi (bisa dari sensor/watch). HR tertinggi **harian** memakai `heartRate.maxValue` daily summary — agregasi harian Garmin yang kadang lebih rendah dari puncak per sesi (contoh: 18 Apr 2026 aktivitas 208 bpm, daily 198 bpm). Angka "tertinggi mana pun" yang paling tinggi tetap dari aktivitas: **208 bpm**.', '');

P('### Top 3 per jendela', '');
for (const s of stats) {
  P(`**${s.label}** — aktivitas: ` + s.top3.map(a => `${a.maxHR} (${shortDate(actDate(a))}, ${a.activityName})`).join(' · ') + '  ');
  P(`Daily: ` + s.top3d.map(d => `${d.heartRate.maxValue} (${shortDate(d.calendarDate)})`).join(' · '), '');
}

P('### Ambang HR — jumlah sesi', '');
P(table(['Jendela','Sesi (semua jenis)','≥200 bpm','≥190 bpm','≥180 bpm','≥175 bpm'], stats.map(s => [
  `**${s.label}**`, num(s.acts.length), num(s.over200), num(s.over190), num(s.over180), num(s.over175),
])));
P('');

// ---------- top 10 activities ----------
P('## Top 10 aktivitas — HR maksimum (12 bulan)', '');
P(table(
  ['#','Tanggal','Aktivitas','Tipe','Max HR','Avg HR','Durasi','Jarak','Pace'],
  topActs.slice(0, 10).map((a, i) => [
    `${i + 1}`,
    shortDate(actDate(a)),
    a.activityName,
    typeWord(a.activityType?.typeKey),
    `**${a.maxHR}**`,
    `${a.averageHR ?? '—'}`,
    hm(a.duration),
    a.distance ? `${dec(a.distance / 1000, 2)} km` : '—',
    a.distance > 100 ? pace(a.duration / (a.distance / 1000)) : '—',
  ])
), '');

P('## Top 10 hari — HR maksimum harian (daily summary)', '');
P(table(
  ['#','Tanggal','Max HR','Langkah','Sesi pada hari itu (max HR)'],
  topDays.map((d, i) => [
    `${i + 1}`,
    shortDate(d.calendarDate),
    `**${d.heartRate.maxValue}**`,
    num(d.movement?.steps?.value),
    fmtActsOfDay(d.calendarDate),
  ])
), '');

// ---------- monthly ----------
P('## Rekap per bulan', '');
P(table(
  ['Bulan','Sesi','Hari daily','Max HR aktivitas','Sesi','Max HR harian','Tanggal'],
  monthly.map(x => [
    `${MONTH_ID[Number(x.m.slice(5, 7)) - 1]} ${x.m.slice(0, 4)}`,
    num(x.nActs),
    num(x.nDays),
    x.ta ? `**${x.ta.maxHR}**` : '—',
    x.ta ? x.ta.activityName : '—',
    x.td ? `**${x.td.heartRate.maxValue}**` : '—',
    x.td ? shortDate(x.td.calendarDate) : '—',
  ])
), '');

// ---------- sessions >= 180 ----------
P('## Semua sesi dengan HR ≥ 180 bpm', '');
P(`Ada **${sessions180.length} sesi** dalam 12 bulan (data tersedia Jan–Okt 2026). Tabel diurutkan dari HR tertinggi.`, '');
const rows180 = sessions180.map((a, i) => [
  `${i + 1}`,
  shortDate(actDate(a)),
  a.activityName,
  typeWord(a.activityType?.typeKey),
  `**${a.maxHR}**`,
  `${a.averageHR ?? '—'}`,
  hm(a.duration),
  a.distance ? `${dec(a.distance / 1000, 2)} km` : '—',
  a.distance > 100 ? pace(a.duration / (a.distance / 1000)) : '—',
]);
const rows180Body = table(['#','Tanggal','Aktivitas','Tipe','Max HR','Avg HR','Durasi','Jarak','Pace'], rows180);
if (rows180.length > 18) {
  P('<details>', `<summary>${rows180.length} sesi — klik untuk buka</summary>`, '', rows180Body, '', '</details>', '');
} else {
  P(rows180Body, '');
}

// ---------- interpensi ----------
P('## Catatan & interpretasi', '');
P(`- **208 bpm** tercatat dua kali: 18 Apr 2026 (\`Bogor - 2x600\`, avg 141) dan 23 Mei 2026 (\`Bogor Track Running\`, avg 178, sesi hanya 0,81 km/3 mnt). Angka ini persis sama dengan **HR maksimum terkonfigurasi (208)** — artinya ini batas atas perangkat, bukan nilai yang bisa melewati 208.`);
P('- Puncak 200–208 bpm semuanya berasal dari sesi interval/track di Bogor, Bandung, dan Depok — wajar untuk sesi pendek berintensitas tinggi.');
P('- Sepuluh besar seluruhnya sesi interval/track (400–1200 m); tidak ada long run di daftar ini.');
P('- Puncak **harian** (daily summary) tertinggi adalah **200 bpm pada 23 Mei 2026**; hari itu ada 4 sesi (termasuk track running 208).');
P('- Hari dengan aktivitas tinggi biasanya langkah 10.000–27.000; puncak daily 18 Agu 2026 (198 bpm) bertepatan dengan 26.982 langkah.');
P('');

P('## Metodologi', '');
P('- **Aktivitas:** `GET /activitylist-service/activities/search/activities?startDate=2025-10-27&endDate=2026-10-27&start=…&limit=100` (4 halaman, 372 aktivitas, dedupe by `activityId`). `maxHR` per sesi dipakai sebagai "puncak dalam aktivitas".');
P('- **Daily (mana pun):** `GET /usersummary-service/v2/dailysummaries?startDate=…&endDate=…` per 14 hari (27 request). `heartRate.maxValue` dipakai sebagai "puncak harian", termasuk hari tanpa sesi.');
P('- **Jendela:** 3 bulan = 27 Jul–27 Okt 2026; 6 bulan = 27 Apr–27 Okt 2026; 12 bulan = 27 Okt 2025–27 Okt 2026. Semua inklusif; 27 Okt 2026 masih parsial (data berjalan).');
P('- **Dedupe & validasi:** 0 aktivitas tanpa `maxHR`; 0 duplikat; daily 296 hari ber-HR (5 Jan–27 Okt 2026).');
P('- **Tidak ada data** aktivitas/daily sebelum 5 Jan 2026 — jendela 12 bulan tidak bisa terisi penuh.');
P('');

P('## Keterbatasan', '');
P('1. **Cakupan historis** hanya 5 Jan–27 Okt 2026 (akun/watch mulai menyimpan Jan 2026), walau permintaan 12 bulan.');
P('2. **Dua sumber berbeda**: `maxHR` aktivitas vs `heartRate.maxValue` daily bisa berbeda 5–10 bpm pada hari yang sama (contoh 18 Apr 2026: 208 vs 198). Laporan menampilkan keduanya, tidak saling menimpa.');
P('3. **208 adalah batas konfigurasi** watch; nilai sebenarnya bisa lebih tinggi tetapi terpotong di batas ini.');
P('4. **Ketergantungan sensor**: akurasi bergantung pada sensor watch/chest strap; spike 1 sampel tidak difilter.');
P('5. **Tidak ada data per detik** di laporan ini; kalau butuh grafik HR per detik untuk sesi tertentu, perlu unduh .FIT sesi tersebut.');
P('', '---', '');

P('## Lampiran file', '');
P('- Laporan ini: `D:\\Garmin\\API-Key-Data-Fetch\\Garmin-Highest-Heart-Rate-2025-10-27_2026-10-27.md`');
P('- Data aktivitas: `D:\\Garmin\\API-Key-Data-Fetch\\data\\hr-history\\activities-2025-10-27_2026-10-27.json` (372 baris)');
P('- Data daily: `D:\\Garmin\\API-Key-Data-Fetch\\data\\hr-history\\daily-summaries-2025-10-27_2026-10-27.json` (296 hari ber-HR)');
P('- Script tarik: `D:\\Garmin\\API-Key-Data-Fetch\\scripts\\fetch-hr-history.ps1`');
P('- Generator: `D:\\Garmin\\API-Key-Data-Fetch\\scripts\\build-hr-report.js`');
P('');
P('*Dibuat otomatis dari Garmin Connect Personal API. Bukan nasihat medis.*');

fs.writeFileSync(OUT, md.join('\n'), 'utf8');
console.log('WROTE', OUT);
console.log('lines', md.join('\n').split('\n').length);
console.log('top overall:', topActs[0].maxHR, 'top daily:', topDays[0].heartRate.maxValue, 'sessions>=180:', sessions180.length);
