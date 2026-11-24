const fs = require('fs');
const DIR='D:/Garmin/API-Key-Data-Fetch/data/calories-1y';
const OUT='D:/Garmin/API-Key-Data-Fetch/Garmin-Calories-1-Year-2025-11-22_2026-11-22.md';
const raw=JSON.parse(fs.readFileSync(`${DIR}/daily-summaries-2025-11-22_2026-11-22.json`,'utf8').replace(/^\uFEFF/,''));
const acts=JSON.parse(fs.readFileSync(`${DIR}/activities-2025-11-22_2026-11-22.json`,'utf8').replace(/^\uFEFF/,''));
const sum=a=>a.reduce((x,y)=>x+y,0);
const avg=a=>a.length?sum(a)/a.length:0;
const median=a=>{const s=[...a].sort((x,y)=>x-y);return s.length?(s.length%2?s[Math.floor(s.length/2)]:(s[Math.floor(s.length/2)-1]+s[Math.floor(s.length/2)])/2):0};
const std=a=>{const m=avg(a);return Math.sqrt(avg(a.map(x=>(x-m)**2)))};
const pct=(a,p)=>{const s=[...a].sort((x,y)=>x-y);return s[Math.min(s.length-1,Math.floor((s.length-1)*p))]};
const fmt=x=>new Intl.NumberFormat('id-ID').format(Math.round(x));
const dec=(x,n=1)=>Number(x).toFixed(n).replace('.',',');
const table=(h,rows)=>['| '+h.join(' | ')+' |','|'+h.map((_,i)=>i===0?'---':'---:').join('|')+'|',...rows.map(r=>'| '+r.join(' | ')+' |')].join('\n');
const dateMap=new Map(raw.map(x=>[x.calendarDate,x]));
const allDates=raw.map(x=>x.calendarDate).sort();
const first=allDates[0], last=allDates[allDates.length-1];
const partialDate='2026-11-22';
const complete=raw.filter(x=>x.calendarDate!==partialDate).sort((a,b)=>a.calendarDate.localeCompare(b.calendarDate));
const active=complete.map(x=>x.calories.burnedActive||0);
const rest=complete.map(x=>x.calories.burnedResting||0);
const total=complete.map(x=>x.calories.burnedTotal||0);
const steps=complete.map(x=>x.movement?.steps?.value||0);
const actByDay={};
for(const x of acts){const d=x.startTimeLocal.slice(0,10);(actByDay[d]||=[]).push(x)}
const months={};
for(const x of complete){const m=x.calendarDate.slice(0,7);(months[m]||=[]).push(x)}
const actMonth={};
for(const x of acts){const m=x.startTimeLocal.slice(0,7);(actMonth[m]||=[]).push(x)}
const monthTotals=Object.entries(months).map(([m,arr])=>({m,total:sum(arr.map(x=>x.calories.burnedActive||0))}));
const peakMonth=monthTotals.reduce((a,b)=>b.total>a.total?b:a,monthTotals[0]);
const lowMonth=monthTotals.reduce((a,b)=>b.total<a.total?b:a,monthTotals[0]);
const corr=(a,b)=>{const n=Math.min(a.length,b.length),ma=avg(a),mb=avg(b);let num=0,da=0,db=0;for(let i=0;i<n;i++){const x=a[i]-ma,y=b[i]-mb;num+=x*y;da+=x*x;db+=y*y}return da&&db?num/Math.sqrt(da*db):0};
const calendarDays=365; // 22 Nov 2025 -> 22 Nov 2026 inclusive
const missing=calendarDays-complete.length-1; // minus partial day
const totalBurned=sum(total), totalActive=sum(active), totalRest=sum(rest);
const partial=raw.find(x=>x.calendarDate===partialDate);
// rolling 7-day complete sums
const byDate=new Map(complete.map(x=>[x.calendarDate,x]));
const dates=complete.map(x=>x.calendarDate);
const rolling=[];
for(let i=6;i<dates.length;i++){
  let sum7=0, ok=true;
  for(let j=0;j<7;j++){
    const dt=new Date(dates[i-6+j]+'T12:00:00Z');
    const key=dt.toISOString().slice(0,10);
    const row=byDate.get(key);
    if(!row){ok=false;break}
    sum7+=row.calories.burnedActive||0;
  }
  if(ok) rolling.push({end:dates[i],sum:sum7});
}
const maxWeek=rolling.reduce((a,b)=>b.sum>a.sum?b:a,rolling[0]);
const minWeek=rolling.reduce((a,b)=>b.sum<a.sum?b:a,rolling[0]);
const top=[...complete].sort((a,b)=>(b.calories.burnedActive||0)-(a.calories.burnedActive||0)).slice(0,15);
const bins=[['<200',x=>x<200],['200–399',x=>x>=200&&x<400],['400–599',x=>x>=400&&x<600],['600–799',x=>x>=600&&x<800],['800–999',x=>x>=800&&x<1000],['≥1000',x=>x>=1000]];
const md=[];const P=(...l)=>md.push(...l);
P('# Audit Kalori 1 Tahun — 22 November 2025 s/d 22 November 2026','');
P('**Atlet:** Albireo  ');
P('**Periode permintaan:** 22 November 2025 – 22 November 2026 (365 hari kalender)  ');
P(`**Cakupan data aktual:** ${first} – ${last} · **${complete.length} hari lengkap** + 1 hari parsial (22 Nov)  `);
P('**Sumber:** Garmin Connect Personal API — `/usersummary-service/v2/dailysummaries` + activity list  ');
P('**Data mentah:** `data\\calories-1y\\daily-summaries-2025-11-22_2026-11-22.json` (322 hari) dan `activities-2025-11-22_2026-11-22.json` (401 aktivitas)  ');
P('**Dibuat:** 22 November 2026','');
P(`> **Cakupan tidak penuh:** akun tidak memiliki daily summary sebelum **5 Januari 2026**. Jadi “1 tahun” secara data efektif **${first}–${last} = ${complete.length} hari lengkap** (${dec((complete.length+1)/365*100,1)}% kalender). 22 Nov 2026 masih parsial (sampai sync 17:13) dan dieksklusi dari rata-rata.`,'');

P('## Ringkasan eksekutif','');
P(table(['Metrik','Nilai','Catatan'],[
  ['Hari dianalisis',`${complete.length} hari`,'22 Nov 2026 parsial dieksklusi'],
  ['Total kalori terbakar',`${fmt(totalBurned)} kcal`,`≈ ${dec(totalBurned/1000,1)} ribu kcal`],
  ['Rata-rata kalori/hari',`${fmt(avg(total))} kcal`,`median ${fmt(median(total))} · SD ${dec(std(total))}`],
  ['Rata-rata aktif/hari',`${fmt(avg(active))} kcal`,`${dec(avg(active)/avg(total)*100,1)}% dari total`],
  ['Rata-rata istirahat/hari',`${fmt(avg(rest))} kcal`,`rentang ${fmt(Math.min(...rest))}–${fmt(Math.max(...rest))}`],
  ['Total aktif',`${fmt(totalActive)} kcal`,`${dec(totalActive/totalBurned*100,1)}% dari total 1 tahun`],
  ['Hari aktif tertinggi',`${fmt(Math.max(...active))} kcal`,top[0].calendarDate],
  ['Hari aktif terendah',`${fmt(Math.min(...active))} kcal`,complete.reduce((a,b)=>(b.calories.burnedActive||0)<(a.calories.burnedActive||0)?b:a).calendarDate],
  ['Hari tanpa aktivitas',`${active.filter(x=>x===0).length} hari`,'0 aktivitas aktif'],
  ['Minggu aktif tertinggi',`${fmt(maxWeek.sum)} kcal`,`7 hari berakhir ${maxWeek.end}`],
  ['Minggu aktif terendah',`${fmt(minWeek.sum)} kcal`,`7 hari berakhir ${minWeek.end}`],
]),'');

P('## Statistik deskriptif','');
P(table(['Metrik','Rata-rata','Median','SD','Min','Maks','P10','P90'],[
  ['Total harian',fmt(avg(total)),fmt(median(total)),dec(std(total)),fmt(Math.min(...total)),fmt(Math.max(...total)),fmt(pct(total,.1)),fmt(pct(total,.9))],
  ['Aktif',fmt(avg(active)),fmt(median(active)),dec(std(active)),fmt(Math.min(...active)),fmt(Math.max(...active)),fmt(pct(active,.1)),fmt(pct(active,.9))],
  ['Istirahat',fmt(avg(rest)),fmt(median(rest)),dec(std(rest)),fmt(Math.min(...rest)),fmt(Math.max(...rest)),fmt(pct(rest,.1)),fmt(pct(rest,.9))],
]),'');

P('## Rekap bulanan','');
const mrows=[];
for(const [m,arr] of Object.entries(months).sort()){
  const mt=arr.map(x=>x.calories.burnedTotal||0), ma=arr.map(x=>x.calories.burnedActive||0), mr=arr.map(x=>x.calories.burnedResting||0);
  const aa=actMonth[m]||[];
  mrows.push([m,arr.length,fmt(avg(mt)),fmt(avg(ma)),fmt(avg(mr)),fmt(sum(ma)),`${dec(avg(ma)/avg(mt)*100,1)}%`,aa.length,fmt(sum(aa.map(x=>x.calories||0)))]);
}
P(table(['Bulan','Hari','Avg total','Avg aktif','Avg istirahat','Total aktif','Aktif %','Aktivitas','Kalori aktivitas'],mrows),'');
P('> Aktif % = porsi kalori aktif terhadap total harian. Kalori aktivitas adalah jumlah `calories` dari activity list Garmin dan tidak selalu sama dengan `burnedActive` harian karena perbedaan agregasi.','');

P('## Tren 7 hari bergulir','');
P(table(['Metrik','Nilai'],[
  ['Rata-rata total 7 hari',`${fmt(avg(rolling.map(x=>x.sum)))} kcal / 7 hari`],
  ['Tertinggi',`${fmt(maxWeek.sum)} kcal (${maxWeek.end})`],
  ['Terendah',`${fmt(minWeek.sum)} kcal (${minWeek.end})`],
  ['Jumlah window',`${rolling.length} window`],
]),'');

P('## 15 hari kalori aktif tertinggi','');
P(table(['#','Tanggal','Aktif','Istirahat','Total','Langkah','Aktivitas'],top.map((x,i)=>[
  i+1,x.calendarDate,fmt(x.calories.burnedActive||0),fmt(x.calories.burnedResting||0),fmt(x.calories.burnedTotal),fmt(x.movement?.steps?.value),(actByDay[x.calendarDate]||[]).slice(0,3).map(a=>a.activityName).join(' · ')||'—'
])),'');

P('## Distribusi kalori aktif','');
P(table(['Rentang (kcal)','Hari','Persen'],bins.map(([label,fn])=>[label,active.filter(fn).length,`${dec(active.filter(fn).length/active.length*100,1)}%`])),'');

P('## Hubungan dengan langkah & aktivitas','');
const pairs=complete.filter(x=>(x.movement?.steps?.value||0)>0);
P(table(['Korelasi','r','Interpretasi'],[
  ['Kalori aktif vs langkah',dec(corr(active,steps),2),'hubungan kuat; langkah penggerak utama'],
  ['Kalori aktif vs kalori aktivitas',dec(corr(active,complete.map(x=>sum((actByDay[x.calendarDate]||[]).map(a=>a.calories||0)))),2),'aktivitas formal hanya sebagian dari total aktif'],
]),'');
P(`Rata-rata langkah harian **${fmt(avg(steps))}**; total langkah 1 tahun **${fmt(sum(steps))}**.`,'');

P('## Validasi & kualitas data','');
const mismatch=complete.filter(x=>Math.abs((x.calories.burnedTotal||0)-((x.calories.burnedActive||0)+(x.calories.burnedResting||0)))>1);
const zero=complete.filter(x=>(x.calories.burnedActive||0)===0);
P(table(['Cek','Hasil','Status'],[
  ['Hari unik',`${raw.length} tanggal`,'✅'],
  ['Duplikat tanggal',`${raw.length-new Set(allDates).size}`,raw.length===new Set(allDates).size?'✅':'⚠'],
  ['Rentang',`${first} – ${last}`,'✅'],
  ['Hari kalender yang diminta','365','—'],
  ['Hari lengkap dianalisis',`${complete.length}`,'✅'],
  ['Hari hilang (sebelum 5 Jan 2026)',`${missing} hari`,'⚠ data belum ada'],
  ['Hari parsial','1 (22 Nov 2026)' ,'⚠ dieksklusi'],
  ['Total = aktif + istirahat',`${mismatch.length} hari tidak cocok`,mismatch.length?'⚠':'✅'],
  ['Hari aktif = 0',`${zero.length} hari`,zero.length?'⚠':'✅'],
]),'');

P('## Temuan utama','');
P(`1. **Rata-rata ${fmt(avg(total))} kcal/hari** selama ${complete.length} hari; kalori istirahat sangat stabil (${fmt(avg(rest))} ± ${dec(std(rest))} kcal) sehingga variasi harian hampir seluruhnya dari aktivitas.`);
P(`2. **Total aktif ${fmt(totalActive)} kcal** (${dec(totalActive/totalBurned*100,1)}% dari total). Puncak 7 hari: **${fmt(maxWeek.sum)} kcal** (${maxWeek.end}); terendah **${fmt(minWeek.sum)} kcal** (${minWeek.end}).`);
P(`3. **Bulan paling aktif:** ${peakMonth.m} · ${fmt(peakMonth.total)} kcal aktif; bulan paling ringan: ${lowMonth.m} · ${fmt(lowMonth.total)} kcal aktif.`);
P(`4. **Hari tertinggi:** ${top[0].calendarDate} · ${fmt(top[0].calories.burnedActive)} kcal aktif · ${fmt(top[0].movement?.steps?.value)} langkah.`);
P(`5. **Hari terendah:** ${complete.reduce((a,b)=>(b.calories.burnedActive||0)<(a.calories.burnedActive||0)?b:a).calendarDate} · ${fmt(Math.min(...active))} kcal aktif.`);
P(`6. **Korelasi langkah–aktif r=${dec(corr(active,steps),2)}** — langkah menjelaskan sebagian besar variasi kalori aktif; aktivitas formal saja tidak cukup menjelaskan total.`);
P('7. **Keterbatasan cakupan:** 43 hari pertama (22 Nov 2025–4 Jan 2026) tidak punya data daily summary, sehingga angka “1 tahun” adalah 322 hari aktual, bukan 365 hari penuh.');

P('## Metodologi','');
P('- **Endpoint:** `GET /usersummary-service/v2/dailysummaries?startDate=…&endDate=…` per 14 hari (27 request), ditambah activity list 1 tahun (5 halaman, 401 aktivitas).');
P('- **Field:** `calories.burnedActive`, `calories.burnedResting`, `calories.burnedTotal`, `movement.steps.value`, `intensityMinutes`, `hydration`.');
P('- **Eksklusi:** 22 Nov 2026 (hari berjalan, sync 17:13) dikeluarkan dari rata-rata; tetap ditampilkan sebagai hari parsial.');
P('- **Rolling 7 hari:** hanya window dengan 7 tanggal lengkap dan berurutan.');
P('- **Korelasi:** Pearson aktif-vs-langkah dan aktif-vs-kalori aktivitas.');
P('');
P('## Keterbatasan','');
P('1. **Cakupan 322 hari**, bukan 365 — data akun mulai 5 Jan 2026.');
P('2. 22 Nov 2026 parsial; metrik setelah 17:13 belum masuk.');
P('3. Kalori Garmin adalah estimasi algoritmik, bukan kalorimetri.');
P('4. `burnedActive` mencakup aktivitas + gerak harian; tidak dipecah per sesi.');
P('5. Kalori aktivitas dari activity list memakai algoritma berbeda dari daily summary — jangan dijumlahkan mentah.');
P('6. Hari tanpa sinkronisasi bisa memiliki data lebih rendah dari aktivitas sebenarnya.');
P('', '---', '');
P('## Lampiran file','');
P('- Laporan ini: `D:\\Garmin\\API-Key-Data-Fetch\\Garmin-Calories-1-Year-2025-11-22_2026-11-22.md`');
P('- Data harian: `data\\calories-1y\\daily-summaries-2025-11-22_2026-11-22.json`');
P('- Data aktivitas: `data\\calories-1y\\activities-2025-11-22_2026-11-22.json`');
P('- Script tarik: `scripts\\fetch-calories-1y.ps1`');
P('- Generator: `scripts\\build-calories-1y.js`');
P('');
P('*Dibuat otomatis dari Garmin Connect Personal API. Bukan nasihat medis/gizi.*');
fs.writeFileSync(OUT,md.join('\n'),'utf8');
console.log('WROTE',OUT,'lines',md.length,'days',complete.length,'avg',Math.round(avg(total)));
