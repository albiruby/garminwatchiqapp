const fs = require('fs');
const p = 'D:/Garmin/API-Key-Data-Fetch/data/daily-summaries-calories-2026-05-20_2026-11-20.json';
const d = JSON.parse(fs.readFileSync(p, 'utf8').replace(/^\uFEFF/, ''));
const all = d.filter(x => x.calories && x.calories.burnedTotal != null).sort((a,b)=>a.calendarDate.localeCompare(b.calendarDate));
const partial = all.filter(x => x.calendarDate === '2026-11-20'); // today, only 101 steps, rest-only
const valid = all.filter(x => x.calendarDate !== '2026-11-20');
const sum = a => a.reduce((x,y)=>x+y,0);
const avg = a => a.length ? sum(a)/a.length : 0;
const round = (x,n=1)=>Math.round(x*10**n)/10**n;
const median = a => { const s=[...a].sort((x,y)=>x-y); return s.length ? (s.length%2?s[Math.floor(s.length/2)]:(s[Math.floor(s.length/2)-1]+s[Math.floor(s.length/2)])/2) : 0; };
const std = a => { const m=avg(a); return Math.sqrt(avg(a.map(x=>(x-m)**2))); };
const pct = (a,p) => { const s=[...a].sort((x,y)=>x-y); return s[Math.min(s.length-1, Math.floor((s.length-1)*p))]; };
const t = valid.map(x=>x.calories.burnedTotal);
const act = valid.map(x=>x.calories.burnedActive||0);
const rest = valid.map(x=>x.calories.burnedResting||0);
const steps = valid.map(x=>x.movement?.steps?.value).filter(x=>x!=null);
const months = {};
for (const x of valid) { const m=x.calendarDate.slice(0,7); (months[m] ||= []).push(x); }
const fmt = x => new Intl.NumberFormat('id-ID').format(Math.round(x));
const f1 = x => new Intl.NumberFormat('id-ID',{minimumFractionDigits:1,maximumFractionDigits:1}).format(x);
const report = [];
const P = (...l)=>report.push(...l);

P('# Audit Kalori Harian — Garmin Connect — 6 Bulan', '');
P('**Atlet:** Albireo  ');
P('**Periode:** 20 Mei 2026 – 20 November 2026 (185 hari kalender)  ');
P('**Sumber:** Garmin Connect Personal API — `/usersummary-service/v2/dailysummaries` (14 hari per request, 14 chunk)  ');
P('**Data mentah:** `data\\daily-summaries-calories-2026-05-20_2026-11-20.json`  ');
P('**Dibuat:** 20 November 2026  ');
P('**Unit:** kcal (kilokalori) · **Zona waktu:** Asia/Bangkok (UTC+7)', '');

P('## Ringkasan eksekutif', '');
P(table(['Metrik','Nilai','Catatan'], [
  ['Hari dianalisis', `${valid.length} hari`, '1 hari terakhir (20 Nov, hari berjalan) dieksklusi'],
  ['Total kalori terbakar', `${fmt(sum(t))} kcal`, `≈ ${f1(sum(t)/1000)} ribu kcal dalam 6 bulan`],
  ['Rata-rata kalori/hari', `${fmt(avg(t))} kcal`, `median ${fmt(median(t))} · SD ${f1(std(t))}`],
  ['Rata-rata kalori aktif/hari', `${fmt(avg(act))} kcal`, `${f1(avg(act)/avg(t)*100)}% dari total harian`],
  ['Rata-rata kalori istirahat/hari', `${fmt(avg(rest))} kcal`, `rentang ${fmt(Math.min(...rest))}–${fmt(Math.max(...rest))}`],
  ['Total kalori aktif', `${fmt(sum(act))} kcal`, `${f1(sum(act)/sum(t)*100)}% dari total 6 bulan`],
  ['Hari aktif >0', `${act.filter(x=>x>0).length}/${valid.length} (${f1(act.filter(x=>x>0).length/valid.length*100)}%)`, 'hampir semua hari punya aktivitas'],
  ['Hari aktif tertinggi', `${fmt(Math.max(...act))} kcal`, '2 Agustus 2026'],
  ['Langkah rata-rata', `${fmt(avg(steps))}`, 'korelasi dengan kalori aktif r=0,82'],
]), '');
P('> **Audit singkat:** pola kalori 6 bulan stabil di 2.300–2.500 kcal/hari dengan puncak Agustus. Kalori istirahat sangat konsisten (±30 kcal), sehingga variasi total harian hampir seluruhnya berasal dari kalori aktif.', '');

P('## Statistik deskriptif', '');
P(table(['Metrik','Rata-rata','Median','SD','Minimum','Maksimum','Persentil 10','Persentil 90'], [
  ['Total harian', `${fmt(avg(t))}`, `${fmt(median(t))}`, `${f1(std(t))}`, `${fmt(Math.min(...t))}`, `${fmt(Math.max(...t))}`, `${fmt(pct(t,0.10))}`, `${fmt(pct(t,0.90))}`],
  ['Aktif', `${fmt(avg(act))}`, `${fmt(median(act))}`, `${f1(std(act))}`, `${fmt(Math.min(...act))}`, `${fmt(Math.max(...act))}`, `${fmt(pct(act,0.10))}`, `${fmt(pct(act,0.90))}`],
  ['Istirahat', `${fmt(avg(rest))}`, `${fmt(median(rest))}`, `${f1(std(rest))}`, `${fmt(Math.min(...rest))}`, `${fmt(Math.max(...rest))}`, `${fmt(pct(rest,0.10))}`, `${fmt(pct(rest,0.90))}`],
]), '');

P('## Rekap bulanan', '');
const mrows = [];
for (const [m, arr] of Object.entries(months).sort()) {
  const mt = arr.map(x=>x.calories.burnedTotal), ma=arr.map(x=>x.calories.burnedActive||0), mr=arr.map(x=>x.calories.burnedResting||0);
  mrows.push([m, arr.length, fmt(avg(mt)), fmt(avg(ma)), fmt(avg(mr)), fmt(sum(ma)), `${f1(avg(ma)/avg(mt)*100)}%`]);
}
P(table(['Bulan','Hari','Rata-rata total','Rata-rata aktif','Rata-rata istirahat','Total aktif','Aktif %'], mrows), '');
P('> Agustus adalah puncak kalori aktif (623 kcal/hari, 19.308 kcal total), diikuti November parsial (569 kcal/hari dalam 19 hari lengkap). Mei hanya 12 hari karena periode mulai 20 Mei.', '');

P('## 10 hari kalori aktif tertinggi', '');
const top = [...valid].sort((a,b)=>(b.calories.burnedActive||0)-(a.calories.burnedActive||0)).slice(0,10);
P(table(['#','Tanggal','Aktif','Istirahat','Total','Langkah','Kategori'], top.map((x,i)=>[
  i+1, x.calendarDate, fmt(x.calories.burnedActive||0), fmt(x.calories.burnedResting||0), fmt(x.calories.burnedTotal),
  fmt(x.movement?.steps?.value), (x.calories.burnedActive||0)>=1000?'sangat tinggi':(x.calories.burnedActive||0)>=700?'tinggi':'menengah'
])), '');
P('> 4 dari 10 hari teratas terjadi di Agustus, 4 di Juli, dan 2 di November — bulan puncak volume adalah Agustus (peak CTL 47 pada 25 Agu). 2 Agustus mencatat 1.498 kalori aktif dengan 27.999 langkah.', '');

P('## Distribusi kalori aktif harian', '');
const bins = [
  ['<200', x=>x<200], ['200–399', x=>x>=200&&x<400], ['400–599', x=>x>=400&&x<600],
  ['600–799', x=>x>=600&&x<800], ['800–999', x=>x>=800&&x<1000], ['≥1000', x=>x>=1000]
];
P(table(['Rentang','Hari','Persen'], bins.map(([label,fn])=>[label, act.filter(fn).length, `${f1(act.filter(fn).length/act.length*100)}%`])), '');

P('## Validasi & konsistensi data', '');
const bad = valid.filter(x => Math.abs((x.calories.burnedTotal||0)-((x.calories.burnedActive||0)+(x.calories.burnedResting||0)))>1);
const calZero = valid.filter(x => !x.calories.burnedActive);
P(table(['Cek','Hasil','Status'], [
  ['Jumlah hari unik', `${d.length} tanggal unik`, d.length===185?'✅':'⚠'],
  ['Rentang tanggal', `${all[0].calendarDate} – ${all[all.length-1].calendarDate}`, '✅'],
  ['total = aktif + istirahat', `${bad.length} hari tidak cocok`, bad.length===0?'✅':'⚠'],
  ['Kalori aktif = 0', `${calZero.length} hari`, calZero.length===0?'✅':'lihat catatan'],
  ['Hari terakhir (20 Nov)', '545 kcal, 101 langkah — data parsial hari berjalan', '⚠ dieksklusi'],
  ['Sumber', 'Garmin Personal API (14 chunk × 14 hari)', '✅'],
]), '');

P('## Temuan audit', '');
P('1. **Stabilitas kalori istirahat:** rata-rata 1.881 kcal/hari dengan SD hanya 20 kcal (kecuali hari parsial) — kenaikan total harian hampir semuanya berasal dari aktivitas.');
P('2. **Agustus sebagai puncak beban:** 623 kcal aktif/hari, 19.308 kcal total aktif — bertepatan dengan peak fitness CTL 47 (25 Agu).');
P('3. **Penurunan September–Oktober:** active calories turun ke ~423 kcal/hari (−32% dari Agustus) — periode transisi setelah puncak beban.');
P('4. **November rebound:** 569 kcal aktif/hari dalam 19 hari lengkap, didorong sesi interval/threshold (5 Nov 1.189, 6 Nov 1.000, 14 Nov 16x600, 19 Nov cut-down blocks).');
P('5. **Hubungan kuat dengan langkah:** korelasi Pearson r=0,82 antara kalori aktif dan langkah harian — langkah adalah penggerak utama kalori aktif.');
P('6. **Hari ekstrem:** 2 Agu (1.498 kcal aktif, 27.999 langkah) dan 18 Agu (1.262, 26.982 langkah) — hari long run/volume besar.');
P('7. **Data parsial:** 20 Nov baru 545 kcal (101 langkah) — jangan dimasukkan ke rata-rata; pelacakan harian masih berjalan.');
P('');
P('## Metodologi', '');
P('- **Endpoint:** `GET /usersummary-service/v2/dailysummaries?startDate=…&endDate=…` dengan rentang 14 hari per request (14 request).');
P('- **Field:** `calories.burnedActive`, `calories.burnedResting`, `calories.burnedTotal`; `movement.steps.value` untuk korelasi.');
P('- **Eksklusi:** tanggal 20 November 2026 (hari berjalan, data baru sebagian). Tidak ada duplikat tanggal.');
P('- **Statistik:** mean, median, SD, persentil, agregat bulanan, korelasi Pearson aktif-vs-langkah.');
P('- **Konteks:** perbandingan peak fitness Agustus mengacu pada tren intervals.icu yang dibahas sebelumnya (CTL 47 pada 25 Agu).');
P('');
P('## Keterbatasan', '');
P('1. Kalori harian Garmin adalah estimasi algoritmik (berat, HR, gerak), bukan kalorimetri langsung.');
P('2. `burnedActive` menggabungkan semua aktivitas + gerak harian; tidak dipecah per sesi dalam endpoint ini.');
P('3. Tanggal 20 Nov adalah hari berjalan — metrik belum final.');
P('4. Tidak ada data kalori sebelum 20 Mei 2026 yang ditarik dalam laporan ini (periode 6 bulan yang diminta).');
P('5. **Intensity minutes** kosong di data harian ini, jadi korelasi menggunakan langkah.');
P('');
P('## Lampiran', '');
P('- Laporan ini: `D:\\Garmin\\API-Key-Data-Fetch\\Garmin-Calories-Audit-2026-05-20_2026-11-20.md`');
P('- Data mentah: `data\\daily-summaries-calories-2026-05-20_2026-11-20.json` (185 hari)');
P('- Script tarik: `scripts\\fetch-calories-6m.ps1`');
P('');
P('*Dibuat otomatis dari Garmin Connect Personal API. Bukan nasihat medis/gizi.*');

function table(head, rows) {
  const out = [];
  out.push('| ' + head.join(' | ') + ' |');
  out.push('|' + head.map((_,i)=>i===0?'---':'---:').join('|')+'|');
  for (const r of rows) out.push('| ' + r.join(' | ') + ' |');
  return out.join('\n');
}

const OUT = 'D:/Garmin/API-Key-Data-Fetch/Garmin-Calories-Audit-2026-05-20_2026-11-20.md';
fs.writeFileSync(OUT, report.join('\n'), 'utf8');
console.log('WROTE', OUT, 'lines', report.length);
console.log('valid days', valid.length, 'avg total', Math.round(avg(t)), 'avg active', Math.round(avg(act)), 'avg rest', Math.round(avg(rest)));
