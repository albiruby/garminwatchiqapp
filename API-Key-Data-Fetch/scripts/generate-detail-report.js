const fs = require('fs');

const DIR = 'D:/Garmin/API-Key-Data-Fetch/data/';
const OUT = 'D:/Garmin/API-Key-Data-Fetch/Garmin-Weekly-Report-2026-10-19_25-DETAIL.md';
const read = f => JSON.parse(fs.readFileSync(DIR + f, 'utf8').replace(/^\uFEFF/, ''));
const exists = f => fs.existsSync(DIR + f);

const DATES = ['2026-10-19','2026-10-20','2026-10-21','2026-10-22','2026-10-23','2026-10-24','2026-10-25'];
const DAY_ID = ['Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'];
const MONTH_ID = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];

const nf = new Intl.NumberFormat('id-ID');
const num = x => (x === null || x === undefined || Number.isNaN(x)) ? '—' : nf.format(Math.round(x));
const dec = (x, d = 2) => (x === null || x === undefined || Number.isNaN(x)) ? '—' : x.toFixed(d).replace('.', ',');
const hm = sec => {
  if (sec === null || sec === undefined) return '—';
  sec = Math.round(sec);
  let h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60);
  if (m === 60) { h++; m = 0; }
  if (h) return `${h}j ${String(m).padStart(2,'0')}m`;
  return `${m}m`;
};
const hms = sec => {
  if (sec === null || sec === undefined) return '—';
  sec = Math.round(sec);
  const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
  return h ? `${h}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}` : `${m}:${String(s).padStart(2,'0')}`;
};
const pace = secPerKm => {
  if (!isFinite(secPerKm) || secPerKm <= 0) return '—';
  let m = Math.floor(secPerKm / 60), s = Math.round(secPerKm % 60);
  if (s === 60) { m++; s = 0; }
  return `${m}:${String(s).padStart(2,'0')}/km`;
};
const clockLocal = ms => new Date(ms).toISOString().slice(11,16);
const clockGmt = iso => new Date((iso.endsWith('Z') ? iso : iso + 'Z')).getTime() + 7 * 3600 * 1000;
const clockGmtStr = iso => new Date(clockGmt(iso)).toISOString().slice(11,16);
const dateID = d => {
  const dt = new Date(d + 'T12:00:00Z');
  return `${DAY_ID[(dt.getUTCDay() + 6) % 7]}, ${dt.getUTCDate()} ${MONTH_ID[dt.getUTCMonth()]} ${dt.getUTCFullYear()}`;
};
const signed = x => x === null || x === undefined ? '—' : (x > 0 ? `+${x}` : (x < 0 ? `−${Math.abs(x)}` : '0'));
const shortDate = d => {
  const dt = new Date(d + 'T12:00:00Z');
  return `${DAY_ID[(dt.getUTCDay() + 6) % 7].slice(0,3)}, ${dt.getUTCDate()} ${MONTH_ID[dt.getUTCMonth()].slice(0,3)}`;
};

const table = (head, rows) => {
  const out = [];
  out.push('| ' + head.join(' | ') + ' |');
  out.push('|' + head.map((_, i) => i === 0 ? '---' : '---:').join('|') + '|');
  for (const r of rows) out.push('| ' + r.join(' | ') + ' |');
  return out.join('\n');
};

function paceOf(a) {
  if (!a || !a.distance || a.distance < 100) return null;
  return a.duration / (a.distance / 1000);
}

// ---------- load ----------
const v2 = read('daily-summaries-v2.json').data;
const sleep = read('sleep-summaries.json');
const hrv = read('hrv-daily.json').hrvSummaries;
const bb = read('body-battery.json');
const acts = read('activities.json');
const wellness = read('wellness-activities.json');
const settings = read('user-settings.json');
const zonesCfg = read('hr-zones.json')[0];

const sleepByDate = Object.fromEntries(sleep.map(s => [s.calendarDate, s]));
const hrvByDate = Object.fromEntries(hrv.map(h => [h.calendarDate, h]));
const bbByDate = Object.fromEntries(bb.map(b => [b.date, b]));
const v2ByDate = Object.fromEntries(v2.map(d => [d.calendarDate, d]));
const wellnessByDate = {};
for (const w of wellness) (wellnessByDate[w.calendarDate] ||= []).push(w);

const actDetails = {};
for (const f of fs.readdirSync(DIR)) {
  const m = f.match(/^activity-(\d+)\.json$/);
  if (m) actDetails[m[1]] = read(f);
}

let fitLaps = {};
try { fitLaps = JSON.parse(fs.readFileSync('D:/Garmin/API-Key-Data-Fetch/fit/fit-laps.json', 'utf8')); } catch { fitLaps = {}; }
const intensityWord = t => ({ warmup: 'Warm-up', active: 'Aktif', recovery: 'Recovery', cooldown: 'Cool-down', rest: 'Istirahat' }[t] || t || '—');
const lapClock = iso => new Date(new Date(iso).getTime() + 7 * 3600 * 1000).toISOString().slice(11,19);
const fitAth = Object.values(fitLaps).find(x => x?.athlete)?.athlete || {};
const fitFtp = (Object.values(fitLaps).find(x => x?.ftp != null) || {}).ftp ?? null;
const fitBmi = fitAth.weightKg && fitAth.heightM ? fitAth.weightKg / (fitAth.heightM * fitAth.heightM) : null;
const lastRunAct = [...acts].sort((x, y) => x.startTimeLocal < y.startTimeLocal ? 1 : -1)[0];
const lastFit = fitLaps[String(lastRunAct?.activityId)] || {};
const recFmt = min => min != null ? `${Math.floor(min / 60)}j ${Math.round(min % 60)}m` : '—';
const maxRecMin = Object.values(fitLaps).reduce((m, x) => Math.max(m, x?.recoveryTimeMin ?? 0), 0);

const spo2 = {}, hrRaw = {}, nutrition = {};
for (const d of DATES) {
  if (exists(`spo2-${d}.json`)) spo2[d] = read(`spo2-${d}.json`);
  if (exists(`daily-hr-${d}.json`)) hrRaw[d] = read(`daily-hr-${d}.json`);
  if (exists(`nutrition-${d}.json`)) nutrition[d] = read(`nutrition-${d}.json`);
}

const zoneFloors = [zonesCfg.zone1Floor, zonesCfg.zone2Floor, zonesCfg.zone3Floor, zonesCfg.zone4Floor, zonesCfg.zone5Floor];

function zoneEstimate(hr) {
  if (!hr || !hr.heartRateValues) return null;
  const counts = [0,0,0,0,0,0];
  for (const [, bpm] of hr.heartRateValues) {
    let z = 0;
    for (let i = zoneFloors.length - 1; i >= 0; i--) if (bpm >= zoneFloors[i]) { z = i + 1; break; }
    counts[z]++;
  }
  return counts.slice(1).map(c => Math.round(c * 2));
}

const actsOn = d => acts.filter(a => a.startTimeLocal.startsWith(d)).sort((x,y) => x.startTimeLocal.localeCompare(y.startTimeLocal));

const sum = (arr, f) => arr.reduce((x, o) => x + (f(o) || 0), 0);
const avg = (arr, f) => {
  const v = arr.map(f).filter(x => x !== null && x !== undefined && !Number.isNaN(x));
  return v.length ? v.reduce((a,b) => a+b, 0) / v.length : null;
};

// ---------- derived daily rows ----------
const rows = v2.map(d => {
  const s = sleepByDate[d.calendarDate] || {};
  const h = hrvByDate[d.calendarDate] || {};
  const z = zoneEstimate(hrRaw[d.calendarDate]);
  return {
    date: d.calendarDate,
    steps: d.movement?.steps?.value ?? null,
    stepGoal: d.movement?.steps?.goal ?? null,
    distKm: (d.movement?.steps?.distanceInMeters || 0) / 1000,
    calTotal: d.calories?.burnedTotal ?? null,
    calActive: d.calories?.burnedActive ?? null,
    calResting: d.calories?.burnedResting ?? null,
    hrMin: d.heartRate?.minValue ?? null,
    hrMax: d.heartRate?.maxValue ?? null,
    hrRest: d.heartRate?.restingValue ?? null,
    mod: d.intensityMinutes?.moderate ?? 0,
    vig: d.intensityMinutes?.vigorous ?? 0,
    stress: d.stress?.avgLevel ?? null,
    stressMax: d.stress?.maxLevel ?? null,
    stressQual: d.stress?.qualifier ?? null,
    bbMin: d.bodyBattery?.minValue ?? null,
    bbMax: d.bodyBattery?.maxValue ?? null,
    hrv: h.lastNightAvg ?? null,
    sleepMin: s.sleepTimeSeconds ? s.sleepTimeSeconds / 60 : null,
    score: s.sleepScores?.overall?.value ?? null,
    zones: z,
    acts: actsOn(d.calendarDate).length,
  };
});

const weekly = {
  steps: sum(rows, r => r.steps),
  dist: sum(rows, r => r.distKm),
  calTotal: sum(rows, r => r.calTotal),
  calActive: sum(rows, r => r.calActive),
  calResting: sum(rows, r => r.calResting),
  runKm: sum(acts, a => a.distance) / 1000,
  runSec: sum(acts, a => a.duration),
  runCal: sum(acts, a => a.calories),
  sleepMin: sum(rows, r => r.sleepMin),
  scoreAvg: avg(rows, r => r.score),
  hrvAvg: avg(rows, r => r.hrv),
  stressAvg: avg(rows, r => r.stress),
  spo2Avg: avg(rows, r => spo2[r.date]?.averageSpO2),
  rhr: avg(rows, r => r.hrRest),
  mod: sum(rows, r => r.mod),
  vig: sum(rows, r => r.vig),
};

const md = [];
const P = (...lines) => md.push(...lines);

// ---------- header ----------
P('# Laporan Detail Mingguan Garmin — 19–25 Oktober 2026', '');
P('**Atlet:** Albireo  ');
P('**Sumber:** Garmin Connect Personal API (JSON) + 8 file .FIT asli  ');
P('**Periode:** Senin 19 Okt 2026 00:00 → Minggu 25 Okt 2026 (25 Okt parsial s/d 09:57)  ');
P(`**Zona waktu:** ${settings.timeZone} (UTC+7) · **Unit:** metrik · **Bahasa angka:** Indonesia  `);
P('**Perangkat:** Garmin device type `37125`, firmware `29.05`  ');
P('**Dibuat:** 26 Oktober 2026 · **Versi:** detail per hari + per sesi', '');
P('> Laporan ini memakai 49 file JSON mentah di `D:\\Garmin\\API-Key-Data-Fetch\\data` dan 8 file .FIT di `D:\\Garmin\\API-Key-Data-Fetch\\fit`. Key API tidak dibaca ulang saat menyusun laporan ini.', '');
P('---', '');

// ---------- TOC ----------
P('## Daftar isi', '');
P('- [Ringkasan mingguan](#ringkasan-mingguan)');
P('- [Profil & zona HR](#profil--zona-hr)');
for (const d of DATES) P(`- [${dateID(d)}](#${dateID(d).toLowerCase().replace(/[^a-z0-9 -]/g,'').replace(/ /g,'-')})`);
P('- [Peringkat minggu ini](#peringkat-minggu-ini)');
P('- [Cakupan API & metodologi](#cakupan-api--metodologi)');
P('- [Keterbatasan data](#keterbatasan-data)');
P('- [Lampiran file](#lampiran-file)');
P('', '---', '');

// ---------- weekly summary ----------
P('## Ringkasan mingguan', '');
P('### Angka utama', '');
P(table(['Metrik','Nilai','Metrik','Nilai'], [
  ['Total langkah', `**${num(weekly.steps)}**`, 'Rata-rata langkah/hari', num(weekly.steps / 7)],
  ['Total jarak harian', `${dec(weekly.dist,1)} km`, 'Total kalori terbakar', `${num(weekly.calTotal)} kcal`],
  ['Kalori aktif', `${num(weekly.calActive)} kcal`, 'Kalori BMR', `${num(weekly.calResting)} kcal`],
  ['Sesi olahraga', `**${acts.length}**`, 'Total volume lari', `**${dec(weekly.runKm,2)} km**`],
  ['Durasi olahraga', hm(weekly.runSec), 'Kalori olahraga', `${num(weekly.runCal)} kcal`],
  ['Tidur rata-rata', `**${hm((weekly.sleepMin / 7) * 60)}**`, 'Skor tidur rata-rata', `**${dec(weekly.scoreAvg,1)}/100**`],
  ['HRV rata-rata', `${dec(weekly.hrvAvg,1)} ms`, 'Resting HR rata-rata', `${num(weekly.rhr)} bpm`],
  ['Stres rata-rata', `${dec(weekly.stressAvg,1)}/100`, 'SpO2 rata-rata', `${dec(weekly.spo2Avg,1)}%`],
  ['Intensity minutes', `${num(weekly.mod)} M / ${num(weekly.vig)} V`, 'Goal mingguan', '150 menit'],
  ['VO2 max est. (sesi terakhir)', lastFit.vo2Max?.final != null ? dec(lastFit.vo2Max.final, 1) : '—', 'Recovery time terpanjang', recFmt(maxRecMin || null)],
]), '');

P('### Tabel harian', '');
P(table(
  ['Hari','Sesi','Lari (km)','Langkah','Kalori total','Tidur','Skor','HRV','RHR','Stres','BB min–max','SpO2'],
  rows.map(r => {
    const dayActs = actsOn(r.date);
    const km = dayActs.reduce((x,a) => x + (a.distance || 0), 0) / 1000;
    return [
      DAY_ID[(new Date(r.date + 'T12:00:00Z').getUTCDay() + 6) % 7].slice(0,3) + ' ' + r.date.slice(8),
      dayActs.length ? `${dayActs.length}` : '—',
      km ? dec(km,2) : '—',
      num(r.steps),
      num(r.calTotal),
      hm(r.sleepMin * 60),
      `${r.score ?? '—'}`,
      r.hrv ? `${r.hrv} ms` : '—',
      `${r.hrRest ?? '—'}`,
      `${r.stress ?? '—'}`,
      `${r.bbMin ?? '—'}–${r.bbMax ?? '—'}`,
      `${dec(spo2[r.date]?.averageSpO2,0)}%`,
    ];
  })
), '');

P('### Distribusi zona HR (estimasi dari sampel HR 2 menit)', '');
const zTotals = [0,0,0,0,0];
for (const r of rows) if (r.zones) r.zones.forEach((v,i) => zTotals[i] += v);
const zSum = zTotals.reduce((a,b) => a+b, 0);
P(table(['Zona','Batas mulai','Total','% dari waktu ≥Z1'], [
  ...zTotals.map((v,i) => [`Z${i+1}`, `${zoneFloors[i]} bpm`, `${num(v)} mnt`, zSum ? `${dec(v / zSum * 100, 1)}%` : '—']),
  ['**Total**','',`**${num(zSum)} mnt**`,'100%'],
]), '');
P('> Estimasi: setiap sampel HR mewakili 2 menit. Waktu di bawah Z1 tidak dihitung.', '');

P('### Ringkasan per jenis aktivitas', '');
const typeName = k => ({ treadmill_running: 'Treadmill', running: 'Outdoor run', strength_training: 'Strength' }[k] || k);
const groups = {};
for (const a of acts) {
  const k = a.activityType.typeKey;
  const g = groups[k] ||= { n: 0, km: 0, sec: 0, cal: 0, elev: 0 };
  const det = actDetails[a.activityId]?.summaryDTO || a;
  g.n++; g.km += (a.distance || 0) / 1000; g.sec += a.duration || 0; g.cal += a.calories || 0; g.elev += det.elevationGain || 0;
}
P(table(['Jenis','Sesi','Jarak','Durasi','Kalori','Elevasi +'], [
  ...Object.entries(groups).map(([k,g]) => [typeName(k), `${g.n}`, g.km ? `${dec(g.km,2)} km` : '—', hm(g.sec), `${num(g.cal)} kcal`, g.elev ? `${num(g.elev)} m` : '—']),
  ['**Total**', `**${acts.length}**`, `**${dec(weekly.runKm,2)} km**`, `**${hm(weekly.runSec)}**`, `**${num(weekly.runCal)} kcal**`, `**${num(sum(acts, a => (actDetails[a.activityId]?.summaryDTO?.elevationGain || 0)))} m**`],
]), '');

// ---------- profile ----------
P('## Profil & zona HR', '');
P(table(['Item','Nilai','Item','Nilai'], [
  ['Zona HR','HR Reserve','Max HR', `${zonesCfg.maxHeartRateUsed} bpm`],
  ['Resting HR dipakai', `${zonesCfg.restingHeartRateUsed} bpm`, 'Z1 mulai', `${zonesCfg.zone1Floor} bpm`],
  ['Z2 mulai', `${zonesCfg.zone2Floor} bpm`, 'Z3 mulai', `${zonesCfg.zone3Floor} bpm`],
  ['Z4 mulai', `${zonesCfg.zone4Floor} bpm`, 'Z5 mulai', `${zonesCfg.zone5Floor} bpm`],
  ['FTP (running power)', fitFtp != null ? `${fitFtp} W` : '—', 'Zona power Z5', fitFtp != null ? `${dec(fitFtp * 1.0,0)}–${dec(fitFtp * 1.15,0)} W` : '—'],
  ['Berat badan', fitAth.weightKg != null ? `${num(fitAth.weightKg)} kg (dari .FIT)` : '—', 'Tinggi / BMI', fitAth.heightM != null ? `${dec(fitAth.heightM,2).replace('.',',')} m / ${fitBmi ? dec(fitBmi,1) : '—'}` : '—'],
  ['Umur (profil)', fitAth.age ?? '—', 'Gender', fitAth.gender === 'male' ? 'Laki-laki' : (fitAth.gender || '—')],
  ['Locale', settings.preferredLocale, 'Format tanggal', settings.dateFormat.displayFormat],
  ['Format waktu', settings.timeFormat.displayFormat, 'Hari pertama', settings.firstDayOfWeek.dayName],
]), '');
P('---', '');

// ---------- per day ----------
const dayNotes = {
  '2026-10-19': [
    'SpO2 menyentuh **89%** saat tidur — satu pembacaan terisolasi, bukan rata-rata.',
    'Hari dengan stres tertinggi (41) dan Body Battery terendah (11).',
  ],
  '2026-10-20': [
    'Dua sesi dalam satu pagi: lari 5x1K lalu strength 30 menit.',
    'Deep sleep hanya 54 menit (13%) sehingga skor tidur jadi 84.',
    'Stres maksimum minggu ini: **98**.',
  ],
  '2026-10-21': [
    'Tidur 7j36m dengan REM 2j02m; Body Battery sempat 90.',
  ],
  '2026-10-22': [
    'Tidur terpanjang minggu ini: **8j31m**, stres tidur hanya 6.',
    'Body Battery mencapai **100** — puncak mingguan.',
  ],
  '2026-10-23': [
    'Langkah terendah minggu ini (10.298) — di bawah goal 13.020.',
    'Skor tidur tertinggi: **98** (deep 19%, REM 25%).',
  ],
  '2026-10-24': [
    'Sesi outdoor: **397 m elevasi**, HR max **182**, TE 3,6/2,1 — sesi terberat minggu ini.',
    'Floors 146 naik / 147 turun kemungkinan anomali barometer (tidak ada sesi stair).',
  ],
  '2026-10-25': [
    'Data harian **parsial** (berhenti 09:57), jadi kalori/stres/langkah belum penuh.',
    'Lari terpanjang minggu ini: **14,18 km** di treadmill.',
  ],
};

const stressWord = q => ({ calm: 'tenang', balanced: 'seimbang', stressful: 'stres', very_stressful: 'sangat stres', unknown: 'belum final' }[q] || q || '—');
const qualWord = q => ({ EXCELLENT: 'EXCELLENT', GOOD: 'GOOD', FAIR: 'FAIR', POOR: 'POOR' }[q] || q || '—');
const eventWord = t => ({ SLEEP: 'Tidur', ACTIVITY: 'Aktivitas', STRESS: 'Stres', RECOVERY: 'Pemulihan', NAP: 'Tidur siang' }[t] || t);
const splitWord = t => ({
  INTERVAL_WARMUP: 'Warm-up', INTERVAL_ACTIVE: 'Interval aktif', INTERVAL_RECOVERY: 'Recovery',
  INTERVAL_COOLDOWN: 'Cool-down', INTERVAL_REST: 'Istirahat', RWD_RUN: 'Total lari',
  RWD_WALK: 'Jalan', RWD_STAND: 'Diam',
}[t] || t);
const teMsg = m => {
  if (!m) return '—';
  const raw = m.replace(/_\d+$/, '');
  const M = {
    NO_AEROBIC_BENEFIT: 'tidak ada',
    MINOR_AEROBIC_BENEFIT: 'manfaat aerobik minor',
    MAINTAINING_AEROBIC_BENEFIT: 'mempertahankan manfaat aerobik',
    MAINTAINING_AEROBIC_BASE: 'mempertahankan base aerobik',
    IMPROVING_AEROBIC_BASE: 'meningkatkan base aerobik',
    IMPROVING_AEROBIC_ENDURANCE: 'meningkatkan daya tahan aerobik',
    IMPROVING_AEROBIC_CAPACITY: 'meningkatkan kapasitas aerobik',
    MAJOR_AEROBIC_BENEFIT: 'manfaat aerobik besar',
    OVERLOADING_AEROBIC_BENEFIT: 'overloading aerobik',
    RECOVERY_AEROBIC_BENEFIT: 'pemulihan aerobik',
    NO_ANAEROBIC_BENEFIT: 'tidak ada',
    MINOR_ANAEROBIC_BENEFIT: 'manfaat anaerobik minor',
    MAINTAINING_ANAEROBIC_BASE: 'mempertahankan base anaerobik',
    MAINTAINING_ANAEROBIC_FITNESS: 'mempertahankan fitness anaerobik',
    IMPROVING_ANAEROBIC_CAPACITY: 'meningkatkan kapasitas anaerobik',
    MAJOR_ANAEROBIC_BENEFIT: 'manfaat anaerobik besar',
    OVERLOADING_ANAEROBIC_BENEFIT: 'overloading anaerobik',
    RECOVERY_ANAEROBIC_BENEFIT: 'pemulihan anaerobik',
  };
  return M[raw] || raw.toLowerCase().replace(/_/g, ' ');
};
const teLabelWord = l => ({
  AEROBIC_BASE: 'Base aerobik', TEMPO: 'Tempo', THRESHOLD: 'Threshold',
  VO2_MAX: 'VO2 Max', MAX_OXYGEN: 'VO2 Max', SPRINT: 'Sprint', ANAEROBIC: 'Anaerobik',
  RECOVERY: 'Pemulihan', SPEED_ENDURANCE: 'Speed endurance', SUSTAINED_TEMPO: 'Tempo berkelanjutan',
}[l] || l || '—');
const fbWord = f => ({
  NONE: '—', STRESSFUL_PERIOD: 'periode stres', RESTFUL_PERIOD: 'periode restoratif',
  EASY_AEROBIC_BASE: 'base aerobik ringan', IMPROVING_AEROBIC_BASE: 'meningkatkan base aerobik',
  MAINTAINING_AEROBIC_BASE: 'mempertahankan base aerobik', IMPROVING_AEROBIC_ENDURANCE: 'meningkatkan daya tahan aerobik',
}[f] || (f || '—').toLowerCase().replace(/_/g, ' ').replace(/-/g, ' '));

function activityBlock(a, idx) {
  const det = actDetails[a.activityId];
  const s = det?.summaryDTO || a;
  const isRun = (a.activityType.typeKey || '').includes('running');
  const isStrength = (a.activityType.typeKey || '').includes('strength');
  const start = a.startTimeLocal.slice(11,16);
  const p = paceOf(s);
  const best = s.maxSpeed ? 1000 / s.maxSpeed : null;
  const zoneSec = [a.hrTimeInZone_1, a.hrTimeInZone_2, a.hrTimeInZone_3, a.hrTimeInZone_4, a.hrTimeInZone_5].map(x => Math.round((x || 0) / 60));

  P(`#### Sesi ${idx} — ${start} · ${a.activityName}`, '');
  P(`**${isStrength ? 'Strength' : (isRun ? 'Lari' : a.activityType.typeKey)}** · ${a.duration ? hm(a.duration) : ''}${s.distance ? ` · ${dec(s.distance/1000,2)} km` : ''} · ${num(s.calories)} kcal`, '');

  const left = [];
  const fs_fit = fitLaps[String(a.activityId)];
  const fs_s = fs_fit?.session || {};
  const dyn = fs_fit?.dynRange || {};
  const meta = det?.metadataDTO || {};
  if (isStrength) {
    left.push(['Durasi', hm(s.duration)], ['Waktu bergerak', hm(s.movingDuration)]);
    left.push(['Kalori', `${num(s.calories)} kcal`], ['Kalori BMR', `${num(s.bmrCalories)} kcal`]);
    left.push(['HR rata-rata', `${s.averageHR} bpm`], ['HR maks / min', `${s.maxHR} / ${s.minHR} bpm`]);
    left.push(['Set aktif', num(s.activeSets)], ['Total reps', num(s.totalExerciseReps)]);
    left.push(['Suhu', `${dec(s.averageTemperature,0)}°C`], ['Training Effect', `${dec(s.trainingEffect,1)} / ${dec(s.anaerobicTrainingEffect,1)}`]);
    left.push(['Recovery HR', '—'], ['Body Battery', signed(s.differenceBodyBattery)]);
    left.push(['Langkah', num(s.steps)], ['Estimasi keringat', `${num(s.waterEstimated)} ml`]);
    left.push(['Intensity minutes', `${s.moderateIntensityMinutes} M / ${s.vigorousIntensityMinutes} V`], ['Lap', `${meta.lapCount ?? '—'}`]);
    left.push(['VO2 max est.', fs_fit?.vo2Max ? `${dec(fs_fit.vo2Max.first, 1)} → ${dec(fs_fit.vo2Max.final, 1)}` : '—'], ['Recovery time', recFmt(fs_fit?.recoveryTimeMin)]);
  } else {
    const workKj = fs_s.totalWorkKj ?? (s.totalWork != null ? s.totalWork * 4.184 : null);
    left.push(['Jarak', `${dec(s.distance/1000,2)} km`], ['Durasi (timer)', hm(s.duration)]);
    left.push(['Waktu bergerak', hm(s.movingDuration)], ['Elapsed total', hm(s.elapsedDuration)]);
    left.push(['Pace rata-rata', pace(p)], ['Pace terbaik', pace(best)]);
    left.push(['Kecepatan rata-rata', `${dec(s.averageSpeed*3.6,1)} km/j`], ['Kecepatan maks', s.maxSpeed ? `${dec(s.maxSpeed*3.6,1)} km/j` : '—']);
    left.push(['GAP (grade-adj pace)', s.avgGradeAdjustedSpeed ? pace(1000/s.avgGradeAdjustedSpeed) : '—'], ['Vertical speed maks', s.maxVerticalSpeed != null ? `${dec(s.maxVerticalSpeed,1)} m/s` : '—']);
    left.push(['Kalori (C)', `${num(s.calories)} kcal`], ['Kalori BMR (metabolic)', `${num(s.bmrCalories)} kcal`]);
    left.push(['Total work', workKj != null ? `${num(workKj)} kJ ≈ ${num(workKj * 0.239)} kcal` : '—'], ['Estimasi keringat', `${num(s.waterEstimated ?? fs_s.estSweatLoss)} ml`]);
    left.push(['Langkah', num(s.steps)], ['Suhu rata-rata', `${dec(s.averageTemperature,0)}°C (${dec(s.minTemperature,0)}–${dec(s.maxTemperature,0)}°C)`]);
    if (s.elevationGain != null) {
      left.push(['Elevasi naik / turun', `${num(s.elevationGain)} / ${num(s.elevationLoss)} m`], ['Elevasi min–avg–maks', `${dec(s.minElevation,0)}–${dec(s.avgElevation,0)}–${dec(s.maxElevation,0)} m`]);
    }
    left.push(['HR rata2 / maks / min', `${s.averageHR} / ${s.maxHR} / ${s.minHR} bpm`], ['Recovery HR', `${s.recoveryHeartRate ?? '—'} bpm`]);
    left.push(['Zona HR Z1–Z5 (mnt)', zoneSec.join(' / ')], ['Intensity minutes', `${s.moderateIntensityMinutes} M / ${s.vigorousIntensityMinutes} V`]);
    left.push(['Body Battery Δ', signed(s.differenceBodyBattery)], ['Lap count', `${meta.lapCount ?? '—'}`]);
  }

  const rows4 = [];
  for (let i = 0; i < left.length; i += 2) {
    const x2 = left[i], y2 = left[i + 1] || ['', ''];
    rows4.push([x2[0], x2[1], y2[0], y2[1]]);
  }
  P(table(['Metrik','Nilai','Metrik','Nilai'], rows4), '');

  if (!isStrength) {
    P('**Dinamika lari**', '');
    P(table(['Metrik','Rata-rata sesi','Rentang antar lap'], [
      ['Cadence', `${dec(s.averageRunCadence,0)} spm`, dyn.cadenceSpm ? `${dec(dyn.cadenceSpm.min,0)}–${dec(dyn.cadenceSpm.max,0)} spm` : '—'],
      ['Panjang langkah', s.strideLength != null ? `${dec(s.strideLength,1)} cm` : '—', dyn.stepCm ? `${dec(dyn.stepCm.min,1)}–${dec(dyn.stepCm.max,1)} cm` : '—'],
      ['Ground contact time', s.groundContactTime != null ? `${dec(s.groundContactTime,0)} ms` : '—', dyn.gctMs ? `${dec(dyn.gctMs.min,0)}–${dec(dyn.gctMs.max,0)} ms` : '—'],
      ['Vertical oscillation', s.verticalOscillation != null ? `${dec(s.verticalOscillation,1)} cm` : '—', dyn.voCm ? `${dec(dyn.voCm.min,1)}–${dec(dyn.voCm.max,1)} cm` : '—'],
      ['Vertical ratio', s.verticalRatio != null ? `${dec(s.verticalRatio,1)} %` : '—', dyn.vr ? `${dec(dyn.vr.min,1)}–${dec(dyn.vr.max,1)} %` : '—'],
    ]), '');

    if (s.averagePower != null || s.maxPower != null) {
      P('**Power**', '');
      P(table(['Metrik','Nilai','Metrik','Nilai'], [
        ['Power rata-rata', `${num(s.averagePower)} W`, 'Power maks', `${num(s.maxPower)} W`],
        ['Normalized Power', `${num(s.normalizedPower)} W`, 'Power min', `${num(s.minPower)} W`],
        ['FTP (threshold)', fs_fit?.ftp != null ? `${fs_fit.ftp} W` : '—', 'Data wind power', meta.hasRunPowerWindData ? 'ya' : 'tidak'],
      ]), '');
      const pz = fs_fit?.pwrZones;
      if (pz) {
        const secs = pz.sec || [];
        const bounds = pz.bounds || [];
        const zRows = [];
        for (let i = 0; i < 6; i++) {
          const hi = bounds[i] != null && bounds[i] < 4000 ? bounds[i] : null;
          const lo = i > 0 ? bounds[i - 1] : null;
          const label = i === 0 ? `Z1 (< ${hi} W)` : hi == null ? `Z${i + 1} (> ${lo} W)` : `Z${i + 1} (${lo}–${hi} W)`;
          zRows.push([label, secs[i] != null ? `${dec(secs[i] / 60, 1)} mnt` : '—']);
        }
        P(table(['Zona power (FIT)','Waktu'], zRows), '');
      }
    }

    P('**Pelatihan & pemulihan**', '');
    P(table(['Metrik','Nilai','Metrik','Nilai'], [
      ['Training Effect', `${dec(s.trainingEffect,1)} aer / ${dec(s.anaerobicTrainingEffect,1)} ana`, 'Label TE', teLabelWord(s.trainingEffectLabel)],
      ['Pesan aerobik', teMsg(s.aerobicTrainingEffectMessage), 'Pesan anaerobik', teMsg(s.anaerobicTrainingEffectMessage)],
      ['RPE (0–10)', s.directWorkoutRpe != null ? dec(s.directWorkoutRpe / 10, 1) : '—', 'Feel (0–10)', s.directWorkoutFeel != null ? dec(s.directWorkoutFeel / 10, 1) : '—'],
      ['VO2 max est.', fs_fit?.vo2Max ? `${dec(fs_fit.vo2Max.first, 1)} → ${dec(fs_fit.vo2Max.final, 1)}` : '—', 'Recovery time', recFmt(fs_fit?.recoveryTimeMin)],
    ]), '');

    const upl = meta.uploadedDate ? `${meta.uploadedDate.slice(0,10)} ${clockGmtStr(meta.uploadedDate)}` : '—';
    P(`_Metadata: ${meta.fileFormat?.formatKey === 'fit' ? 'file .FIT asli' : 'file ' + (meta.fileFormat?.formatKey ?? '—')} · diunggah ${upl} · ${meta.manufacturer || '—'} · ${meta.favorite ? 'favorit ⭐' : 'bukan favorit'}_`, '');
  }
  P(`**HR zone sesi:** Z1 ${zoneSec[0]}m · Z2 ${zoneSec[1]}m · Z3 ${zoneSec[2]}m · Z4 ${zoneSec[3]}m · Z5 ${zoneSec[4]}m`, '');

  // splits
  let splits = det?.splitSummaries || [];
  if (isStrength) {
    splits = splits.filter(x => x.splitType === 'INTERVAL_ACTIVE' || x.splitType === 'INTERVAL_REST');
    if (splits.length) {
      P('**Segmen:**', '');
      P(table(['Segmen','Durasi','HR avg','HR max','Kalori'],
        splits.map(x => [splitWord(x.splitType), hm(x.duration), `${x.averageHR} bpm`, `${x.maxHR} bpm`, `${num(x.calories)} kcal`])), '');
    }
  } else {
    const fitSegs = (fs_fit?.splitSummaries || []).filter(x => (x.distanceM || 0) > 0 || (x.timerSec || 0) > 0);
    if (fitSegs.length) {
      P('**Segmen sesi (split .FIT):**', '');
      P(table(['Segmen','Jarak','Durasi','Pace','Vel maks','HR a/m','Elev ±','kcal','Vert'], fitSegs.map(x => [
        splitWord((x.type || '').toUpperCase()),
        x.distanceM ? `${dec(x.distanceM / 1000, 2)} km` : '—',
        x.timerSec ? hms(x.timerSec) : '—',
        x.paceSecPerKm ? pace(x.paceSecPerKm) : '—',
        x.maxSpeed != null ? `${dec(x.maxSpeed * 3.6, 1)} km/j` : '—',
        `${x.avgHR ?? '—'}/${x.maxHR ?? '—'}`,
        (x.ascent != null || x.descent != null) ? `+${x.ascent ?? 0}/−${x.descent ?? 0} m` : '—',
        x.calories != null ? num(x.calories) : '—',
        x.avgVertSpeed != null ? `${dec(x.avgVertSpeed, 2)} m/s` : '—',
      ])), '');
    } else {
      const hasInterval = splits.some(x => x.splitType === 'INTERVAL_ACTIVE');
      if (hasInterval) {
        const order = ['INTERVAL_WARMUP','INTERVAL_ACTIVE','INTERVAL_RECOVERY','INTERVAL_COOLDOWN'];
        splits = splits.filter(x => order.includes(x.splitType)).sort((x,y) => order.indexOf(x.splitType) - order.indexOf(y.splitType));
      } else {
        splits = splits.filter(x => x.splitType === 'RWD_RUN').slice(0,1);
      }
      if (splits.length > 1) {
        P('**Segmen sesi:**', '');
        P(table(['Segmen','Jarak','Durasi','Pace','HR avg','HR max','Power avg','Elevasi'],
          splits.map(x => [
            splitWord(x.splitType),
            x.distance ? `${dec(x.distance/1000,2)} km` : '—',
            hms(x.duration),
            pace(paceOf(x)),
            `${x.averageHR ?? '—'} bpm`,
            `${x.maxHR ?? '—'} bpm`,
            x.averagePower ? `${x.averagePower} W` : '—',
            x.elevationGain != null ? `+${x.elevationGain} m` : '—',
          ])), '');
      }
    }
  }

  const fit = fitLaps[String(a.activityId)];
  if (fit?.laps?.length) {
    const counts = {};
    for (const l of fit.laps) { const k = intensityWord(l.intensity); counts[k] = (counts[k] || 0) + 1; }
    P(`**Lap (.FIT):** ${fit.laps.length} lap · ` + Object.entries(counts).map(([k, v]) => `${k} ${v}`).join(' · '), '');
    const lapTable = table(
      ['#','Mulai','Jarak','Durasi','Pace','Vel maks','HR a/m','Cad a/m','Power a/m','NP','kJ','VO','GCT','Langkah','VR','Elev +/−','kcal','Suhu','Tipe'],
      fit.laps.map(l => [
        `${l.i}`,
        lapClock(l.startUtc),
        l.distanceM ? `${num(l.distanceM)} m` : '—',
        hms(l.timerSec),
        l.paceSecPerKm ? pace(l.paceSecPerKm) : '—',
        l.maxSpeedMs != null ? `${dec(l.maxSpeedMs * 3.6, 1)}` : '—',
        `${l.avgHR ?? '—'}/${l.maxHR ?? '—'}`,
        `${l.cadenceSpm ?? '—'}/${l.maxCadenceSpm ?? '—'}`,
        `${l.avgPower ?? '—'}/${l.maxPower ?? '—'}`,
        l.normPower != null ? num(l.normPower) : '—',
        l.totalWorkKj != null ? num(l.totalWorkKj) : '—',
        l.avgVOcm != null ? dec(l.avgVOcm, 1) : '—',
        l.avgGctMs != null ? dec(l.avgGctMs, 0) : '—',
        l.avgStepCm != null ? dec(l.avgStepCm, 1) : '—',
        l.avgVR != null ? dec(l.avgVR, 1) : '—',
        `${l.ascent != null ? '+' + l.ascent : '—'}/${l.descent != null ? '−' + l.descent : '—'}`,
        l.calories != null ? num(l.calories) : '—',
        l.avgTemp != null ? `${l.avgTemp}°C` : '—',
        intensityWord(l.intensity),
      ])
    );
    P('> Legenda lap: Vel maks km/j · Cad spm · Power W · NP W · work kJ · VO cm · GCT ms · Langkah cm · VR % · kcal (C) · Suhu rata-rata. Rata-rata dinamika per lap dari pesan `lap` .FIT.', '');
    if (fit.laps.length > 12) {
      P('<details>', `<summary>${fit.laps.length} lap — klik untuk buka</summary>`, '', lapTable, '', '</details>', '');
    } else {
      P(lapTable, '');
    }
  }

  P('');
}

for (const d of DATES) {
  const r = rows.find(x => x.date === d);
  const dd = v2ByDate[d];
  const sl = sleepByDate[d];
  const h = hrvByDate[d];
  const sp = spo2[d];
  const dayActs = actsOn(d);
  const z = r.zones || [0,0,0,0,0];

  P(`## ${dateID(d)}`, '');

  const flags = [];
  if (d === '2026-10-25') flags.push('⚠️ data parsial');
  if (r.steps < r.stepGoal) flags.push('langkah di bawah goal');
  if (dayActs.length) flags.push(`${dayActs.length} sesi`);
  P(`**${flags.join(' · ')}**`, '');

  P(table(['Metrik','Nilai','Metrik','Nilai'], [
    ['Langkah', `${num(r.steps)} / goal ${num(r.stepGoal)} ${r.steps >= r.stepGoal ? '✅' : '❌'}`, 'Jarak harian', `${dec(r.distKm,2)} km`],
    ['Kalori total', `${num(r.calTotal)} kcal`, 'Kalori aktif', `${num(r.calActive)} kcal`],
    ['Kalori BMR', `${num(r.calResting)} kcal`, 'Kalori masuk', dd.calories?.consumedValue != null ? `${num(dd.calories.consumedValue)} kcal` : '—'],
    ['Lantai naik / turun', `${num(dd.movement?.floorsAscended?.value)} / ${num(dd.movement?.floorsDescended?.value)}`, 'Intensity minutes', `${r.mod} M / ${r.vig} V`],
    ['HR min–max', `${r.hrMin}–${r.hrMax} bpm`, 'Resting HR', `${r.hrRest} bpm`],
    ['Stres rata-rata', `${r.stress}/100 (${stressWord(r.stressQual)})`, 'Stres maks', `${r.stressMax}`],
    ['Body Battery', `${r.bbMin}–${r.bbMax}`, 'Charged / drained', `+${dd.bodyBattery?.chargedValue ?? '—'} / −${dd.bodyBattery?.drainedValue ?? '—'}`],
    ['SpO2 avg / min', `${sp?.averageSpO2 ?? '—'}% / ${sp?.lowestSpO2 ?? '—'}%`, 'Respirasi', `${dd.respiration?.avgValue ?? '—'} rpm (${dd.respiration?.minValue ?? '—'}–${dd.respiration?.maxValue ?? '—'})`],
    ['Hidrasi', `${num(dd.hydration?.consumedInFractionalMl)} ml / goal ${num(dd.hydration?.goalInMl)} ml`, 'Zona HR Z1–Z5', `±${z.map(v => Math.round(v)).join(' / ')} mnt`],
  ]), '');

  // sleep
  P('### Tidur', '');
  if (sl) {
    const start = clockLocal(sl.sleepStartTimestampLocal);
    const end = clockLocal(sl.sleepEndTimestampLocal);
    const total = sl.sleepTimeSeconds;
    P(`**${start} → ${end}** · ${hm(total)} · skor **${sl.sleepScores?.overall?.value ?? '—'} (${sl.sleepScores?.overall?.qualifierKey ?? '—'})**`, '');
    P(table(['Durasi','Deep','Light','REM','Awake','HR tidur','Stres tidur','SpO2 tidur'], [
      [
        hm(total),
        `${hm(sl.deepSleepSeconds)} (${sl.sleepScores?.deepPercentage?.value ?? '—'}%)`,
        `${hm(sl.lightSleepSeconds)} (${sl.sleepScores?.lightPercentage?.value ?? '—'}%)`,
        `${hm(sl.remSleepSeconds)} (${sl.sleepScores?.remPercentage?.value ?? '—'}%)`,
        `${hm(sl.awakeSleepSeconds)} · ${sl.awakeCount}x`,
        `${sl.avgHeartRate} bpm`,
        `${sl.avgSleepStress}`,
        `${sl.averageSpO2Value}% (min ${sl.lowestSpO2Value}%)`,
      ],
    ]), '');
    const comp = [
      ['Durasi', qualWord(sl.sleepScores?.totalDuration?.qualifierKey)],
      ['Stres', qualWord(sl.sleepScores?.stress?.qualifierKey)],
      ['Awake count', qualWord(sl.sleepScores?.awakeCount?.qualifierKey)],
      ['Restlessness', qualWord(sl.sleepScores?.restlessness?.qualifierKey)],
      ['REM %', `${sl.sleepScores?.remPercentage?.value ?? '—'}% ${qualWord(sl.sleepScores?.remPercentage?.qualifierKey)}`],
      ['Deep %', `${sl.sleepScores?.deepPercentage?.value ?? '—'}% ${qualWord(sl.sleepScores?.deepPercentage?.qualifierKey)}`],
      ['Light %', `${sl.sleepScores?.lightPercentage?.value ?? '—'}% ${qualWord(sl.sleepScores?.lightPercentage?.qualifierKey)}`],
    ];
    P('**Komponen skor:** ' + comp.map(([k,v]) => `${k} ${v}`).join(' · '), '');
  } else {
    P('_Tidak ada data tidur._', '');
  }

  // HRV
  P('### HRV', '');
  if (h) {
    P(`**${h.lastNightAvg} ms** semalam · avg 7 hari **${h.weeklyAvg} ms** · status **${h.status}** · baseline ${h.baseline.balancedLow}–${h.baseline.balancedUpper} ms (low-upper ${h.baseline.lowUpper})`, '');
  } else {
    P('_Tidak ada data HRV._', '');
  }

  // activities
  P('### Aktivitas', '');
  if (!dayActs.length) P('_Tidak ada sesi tercatat._', '');
  dayActs.forEach((a, i) => activityBlock(a, i + 1));

  // body battery timeline
  const b = bbByDate[d];
  if (b?.bodyBatteryActivityEvent?.length) {
    P('### Body Battery timeline', '');
    P(table(['Waktu','Event','Durasi','Dampak','Feedback'], b.bodyBatteryActivityEvent.map(e => [
      clockGmtStr(e.eventStartTimeGmt),
      eventWord(e.eventType),
      hm(e.durationInMilliseconds / 1000),
      signed(e.bodyBatteryImpact),
      (e.shortFeedback && fbWord(e.shortFeedback) || '—'),
    ])), '');
  }

  // health snapshot
  const snaps = wellnessByDate[d] || [];
  if (snaps.length) {
    P('### Health Snapshot', '');
    for (const w of snaps) {
      const g = t => w.summaryTypeDataList.find(x => x.summaryType === t) || {};
      P(`**${w.activityName}** · ${w.startTimestampLocal.slice(11,16)} · ${Math.round((new Date(w.endTimestampLocal) - new Date(w.startTimestampLocal)) / 1000)} detik`, '');
      P(table(['HR avg','HR min–max','Respirasi','Stres','SpO2','RMSSD','SDRR'], [[
        `${g('HEART_RATE').avgValue ?? '—'}`,
        `${g('HEART_RATE').minValue ?? '—'}–${g('HEART_RATE').maxValue ?? '—'}`,
        `${dec(g('RESPIRATION').avgValue,1)}`,
        `${g('STRESS').avgValue ?? '—'}`,
        `${g('SPO2').avgValue ?? '—'}%`,
        `${g('RMSSD_HRV').avgValue ?? '—'}`,
        `${g('SDRR_HRV').avgValue ?? '—'}`,
      ]]), '');
    }
  }

  // notes
  if (dayNotes[d]) {
    P('### Catatan', '');
    for (const note of dayNotes[d]) P(`- ${note}`);
    P('');
  }

  P('---', '');
}

// ---------- rankings ----------
P('## Peringkat minggu ini', '');
const ranked = [...acts].sort((x,y) => (y.distance || 0) - (x.distance || 0));
const bestPace = acts.filter(a => a.distance > 100).sort((x,y) => (x.duration/x.distance) - (y.duration/y.distance))[0];
const bestTE = [...acts].sort((x,y) => (y.aerobicTrainingEffect || 0) - (x.aerobicTrainingEffect || 0))[0];
const maxHR = [...acts].sort((x,y) => (y.maxHR || 0) - (x.maxHR || 0))[0];
P(table(['Kategori','Sesi','Nilai'], [
  ['Lari terpanjang', `${ranked[0].activityName} (${shortDate(ranked[0].startTimeLocal.slice(0,10))})`, `${dec(ranked[0].distance/1000,2)} km`],
  ['Pace terbaik', `${bestPace.activityName} (${shortDate(bestPace.startTimeLocal.slice(0,10))})`, `${pace(bestPace.duration/(bestPace.distance/1000))}`],
  ['Training Effect tertinggi', `${bestTE.activityName} (${shortDate(bestTE.startTimeLocal.slice(0,10))})`, `${dec(bestTE.aerobicTrainingEffect,1)} aer / ${dec(bestTE.anaerobicTrainingEffect,1)} ana`],
  ['HR maks tertinggi', `${maxHR.activityName} (${shortDate(maxHR.startTimeLocal.slice(0,10))})`, `${maxHR.maxHR} bpm`],
  ['Tidur terbaik', 'Jumat 23 Okt', '98/100 (8j15m)'],
  ['Tidur terendah', 'Selasa 20 Okt', '84/100 (6j41m)'],
  ['Langkah terbanyak', 'Sabtu 24 Okt', `${num(17613)}`],
  ['Langkah tersedikit', 'Jumat 23 Okt', `${num(10298)}`],
  ['Stres tertinggi', 'Senin 19 Okt', '41/100 (stressful)'],
  ['Stres terendah', 'Rabu 21 Okt', '32/100 (balanced)'],
]), '');
P('> Catatan: peringkat memakai hari penuh 19–24 Okt; 25 Okt parsial tidak diikutkan dalam perbandingan tidur/stres.', '');

// ---------- API coverage ----------
P('## Cakupan API & metodologi', '');
P('### Endpoint yang dipakai', '');
P(table(['Kategori','Endpoint','Status','Jumlah'], [
  ['Profil & setting','`/userprofile-service/userprofile/settings`','✅','1'],
  ['Zona HR','`/biometric-service/heartRateZones/v2`','✅','3'],
  ['Daily summary v2','`/usersummary-service/v2/dailysummaries`','✅','7 hari'],
  ['Daily summary legacy','`/usersummary-service/usersummary/daily`','✅','7'],
  ['Steps / stress / hidrasi','`/usersummary-service/stats/...`','✅ / ⚠️','7 / 7 / 0'],
  ['Tidur','`/sleep-service/sleep/dailySleepSummariesByDate`','✅','7'],
  ['Body Battery','`/wellness-service/wellness/bodyBattery/reports/daily`','✅','7'],
  ['HRV','`/hrv-service/hrv/daily/...`','✅','7'],
  ['Berat','`/weight-service/weight/...`','❌ 404/400','0'],
  ['Fitness Age','`/fitnessage-service/fitnessage/v2/...`','❌ 404','0'],
  ['Daftar aktivitas','`/activitylist-service/activities/search/activities`','✅','8'],
  ['Detail aktivitas','`/activity-service/activity/{id}`','✅','8'],
  ['File .FIT + lap','`/download-service/files/activity/{id}`','✅ 8 diunduh','128 lap + VO2/FTP/TIZ'],
  ['Wellness activity','`/wellnessactivity-service/activity/summary/range/...`','✅','6'],
  ['HR harian (raw)','`/wellness-service/wellness/dailyHeartRate`','✅','7 hari'],
  ['SpO2','`/wellness-service/wellness/daily/spo2acclimation/{date}`','✅','7'],
  ['Nutrisi','`/nutrition-service/food/logs/{date}`','⚠️ kosong','0'],
  ['Menstrual','`/periodichealth-service/menstrualcycle/...`','⚠️ kosong','0'],
]), '');
P('### Metodologi', '');
P('- **Zona HR harian** dihitung dari sampel `heartRateValues` (interval 2 menit) memakai batas zona profil: ' + zoneFloors.map((f,i) => `Z${i+1} ≥${f}`).join(', ') + '.');
P('- **Pace** = durasi / jarak; pace terbaik memakai `maxSpeed` dari Garmin.');
P('- **Zona HR sesi** memakai `hrTimeInZone_1..5` yang dihitung Garmin per aktivitas.');
P('- **VO2 max, recovery time, berat/tinggi/umur, FTP, zona power 7 tingkat** diambil dari pesan `user_metrics`, `activity_metrics`, `zones_target`, `time_in_zone` di file .FIT — bukan dari endpoint JSON. VO2 max ditampilkan mulai → akhir sesi; recovery time dalam menit.');
P('- **Segmen** memakai `splitSummaries` dari detail aktivitas. Personal API tidak menyediakan endpoint lap per-lap.');
P('- **Lap per lap** diambil dari pesan `lap` di 8 file .FIT, 19 kolom: waktu mulai, jarak, durasi, pace, kecepatan maks, HR avg/max, cadence avg/max (spm), power avg/max, NP, work kJ, VO, GCT, panjang langkah, VR, elevasi naik/turun, kalori, suhu, intensitas. Cadence FIT dikonversi ×2 (siklus kaki → langkah/menit); VO & langkah unit FIT dibagi 10 (mm → cm).');
P('- **Total work & sweat** dari pesan `session` .FIT (`total_work` J → kJ, `est_sweat_loss` ml). Rata-rata dinamika lari sesi tetap dari JSON Garmin; rentang antar lap dari `avg_vertical_oscillation` / `avg_stance_time` / `avg_step_length` / `avg_vertical_ratio` per lap (unit FIT dibagi 10 untuk cm).');
P('- **Records per detik** (~25.000 sampel) tersedia di .FIT tapi belum divisualisasikan mentah; dipakai lewat rata-rata per lap.');
P('- **Kalori masuk** hanya terisi kalau food log diisi; minggu ini kosong.');
P('- **Body Battery timeline** memakai event Garmin (sleep/activity/stress/recovery), waktu lokal UTC+7.', '');

// ---------- limitations ----------
P('## Keterbatasan data', '');
P('1. **25 Okt parsial** — data berhenti 09:57; total mingguan understated.');
P('2. **Tanpa data scale (berat terukur)** — endpoint weight 404/400; berat badan 56 kg, tinggi, umur, dan FTP tetap didapat dari pesan `user_metrics`/`zones_target` .FIT (profil watch, bukan timbangan).');
P('3. **Tanpa nutrisi & hidrasi** — food log kosong, hidrasi 0 ml tercatat.');
P('4. **Tanpa data siklus** — menstrual cycle kosong.');
P('5. **Lap per-lap hanya dari .FIT** — JSON Personal API cuma memberi `splitSummaries`; tabel lap di laporan ini berasal dari pesan `lap` file .FIT.');
P('6. **Performance condition, HRV sesi, dan tren VO2 max historis per hari** tidak ada di JSON/FIT aktivitas; VO2 max est. per sesi & recovery time berhasil diambil dari pesan FIT. Garmin juga men-strip sebagian field dari JSON API.');
P('7. **Personal API read-only** — tidak bisa push workout/route ke watch.');
P('8. **Perangkat** tidak menyediakan nama model di endpoint profil; hanya device type ID.');
P('', '---', '');

P('## Lampiran file', '');
P('- Laporan ringkas: `D:\\Garmin\\API-Key-Data-Fetch\\Garmin-Weekly-Report-2026-10-19_25.md`');
P('- Laporan detail ini: `D:\\Garmin\\API-Key-Data-Fetch\\Garmin-Weekly-Report-2026-10-19_25-DETAIL.md`');
P('- Data mentah: `D:\\Garmin\\API-Key-Data-Fetch\\data\\` (49 JSON)');
P('- File .FIT: `D:\\Garmin\\API-Key-Data-Fetch\\fit\\` (8 ZIP, 8 FIT, `fit-laps.json`)');
P('- Downloader .FIT: `D:\\Garmin\\API-Key-Data-Fetch\\scripts\\download-fit.ps1`');
P('- Parser lap: `D:\\Garmin\\API-Key-Data-Fetch\\scripts\\parse-fit.js`');
P('- Generator: `D:\\Garmin\\API-Key-Data-Fetch\\scripts\\generate-detail-report.js`');
P('', '*Dibuat otomatis dari Garmin Connect Personal API. Bukan nasihat medis.*');

fs.writeFileSync(OUT, md.join('\n'), 'utf8');
console.log('WROTE', OUT);
console.log('lines', md.join('\n').split('\n').length);
console.log('chars', md.join('\n').length);

