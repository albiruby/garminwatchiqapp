const fs = require('fs');
const path = require('path');
const FitParser = require('D:/Garmin/API-Key-Data-Fetch/scripts/node_modules/fit-file-parser').default;

const BASE = 'D:/Garmin/API-Key-Data-Fetch';
const ID = '25026059313';
const SESS = path.join(BASE, 'sessions', ID);
const FIT = path.join(SESS, `${ID}_ACTIVITY.fit`);
const DETAIL = path.join(SESS, `activity-detail-${ID}.json`);
const OUT = path.join(BASE, 'Garmin-Session-2026-11-10-Treadmill-5x5.md');

const nf = new Intl.NumberFormat('id-ID');
const num = x => (x === null || x === undefined || Number.isNaN(x)) ? '—' : nf.format(Math.round(x));
const dec = (x, d = 2) => (x === null || x === undefined || Number.isNaN(x)) ? '—' : x.toFixed(d).replace('.', ',');
const hm = sec => {
  if (sec === null || sec === undefined) return '—';
  sec = Math.round(sec);
  let h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60);
  if (m === 60) { h++; m = 0; }
  return h ? `${h}j ${String(m).padStart(2, '0')}m` : `${m}m`;
};
const hms = sec => {
  if (sec === null || sec === undefined) return '—';
  sec = Math.round(sec);
  const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
  return h ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}` : `${m}:${String(s).padStart(2, '0')}`;
};
const pace = s => {
  if (!isFinite(s) || s <= 0) return '—';
  let m = Math.floor(s / 60), r = Math.round(s % 60);
  if (r === 60) { m++; r = 0; }
  return `${m}:${String(r).padStart(2, '0')}/km`;
};
const table = (head, rows) => {
  const out = [];
  out.push('| ' + head.join(' | ') + ' |');
  out.push('|' + head.map((_, i) => i === 0 ? '---' : '---:').join('|') + '|');
  for (const r of rows) out.push('| ' + r.join(' | ') + ' |');
  return out.join('\n');
};
const wavg = (arr, w) => arr.reduce((a, v, i) => a + v * w[i], 0) / w.reduce((a, b) => a + b, 0);

function parseFit() {
  return new Promise((resolve, reject) => {
    const parser = new FitParser({ force: true, speedUnit: 'm/s', lengthUnit: 'm', temperatureUnit: 'C' });
    parser.parse(fs.readFileSync(FIT), (err, data) => err ? reject(err) : resolve(data));
  });
}

(async () => {
  const data = await parseFit();
  const detail = JSON.parse(fs.readFileSync(DETAIL, 'utf8').replace(/^﻿/, ''));
  const sum = detail.summaryDTO;
  const splits = detail.splitSummaries || [];
  const s = data.sessions[0];
  const laps = data.laps || [];
  const records = data.records || [];
  const tiz = (data.time_in_zone || []).find(t => t.reference_mesg === 'session');
  const um = (data.user_metrics || [])[0] || {};
  const zt = (Array.isArray(data.zones_target) ? data.zones_target[0] : data.zones_target) || {};

  const lapClock = iso => new Date(new Date(iso).getTime() + 7 * 3600e3).toISOString().slice(11, 19);
  const startLocal = new Date(new Date(s.start_time).getTime() + 7 * 3600e3).toISOString().slice(0, 19).replace('T', ' ');

  const norm = laps.map((l, i) => ({
    i: i + 1,
    start: lapClock(l.start_time),
    dist: l.total_distance ?? 0,
    timer: l.total_timer_time ?? 0,
    pace: (l.total_distance >= 50 && l.total_timer_time) ? l.total_timer_time / (l.total_distance / 1000) : null,
    hr: l.avg_heart_rate ?? null,
    hrMax: l.max_heart_rate ?? null,
    cad: l.avg_cadence != null ? (l.avg_cadence + (l.avg_fractional_cadence || 0)) * 2 : null,
    cadMax: l.max_cadence != null ? (l.max_cadence + (l.max_fractional_cadence || 0)) * 2 : null,
    pw: l.avg_power ?? null,
    pwMax: l.max_power ?? null,
    np: l.normalized_power ?? null,
    workKj: (l.avg_power ?? 0) * (l.total_timer_time ?? 0) / 1000,
    kcal: l.total_calories ?? null,
    vo: l.avg_vertical_oscillation != null ? l.avg_vertical_oscillation / 10 : null,
    gct: l.avg_stance_time ?? null,
    step: l.avg_step_length != null ? l.avg_step_length / 10 : null,
    vr: l.avg_vertical_ratio ?? null,
    temp: l.avg_temperature != null ? Math.round(l.avg_temperature) : null,
    kind: l.intensity ?? null,
    trigger: l.lap_trigger ?? null,
  }));

  // ---- kelompokkan blok ----
  const warm = norm.filter(x => x.kind === 'warmup');
  const pre = norm.filter(x => x.kind === 'recovery' && x.i < 5);   // jeda sebelum interval 1
  const recs = norm.filter(x => x.kind === 'recovery' && x.i >= 5); // recovery antar interval
  const cool = norm.filter(x => x.kind === 'cooldown');
  const actives = norm.filter(x => x.kind === 'active');

  const intervals = [];
  let cur = [];
  for (const x of norm) {
    if (x.kind === 'active') cur.push(x);
    else if (cur.length) { intervals.push(cur); cur = []; }
  }
  if (cur.length) intervals.push(cur);

  const agg = (rows, label) => {
    const dist = rows.reduce((a, b) => a + b.dist, 0);
    const timer = rows.reduce((a, b) => a + b.timer, 0);
    const w = rows.map(r => r.timer);
    return {
      label,
      laps: rows.map(r => r.i).join('+'),
      dist, timer,
      pace: dist >= 50 ? timer / (dist / 1000) : null,
      speed: dist > 0 && timer > 0 ? (dist / timer) * 3.6 : null,
      hr: wavg(rows.map(r => r.hr), w),
      hrMax: Math.max(...rows.map(r => r.hrMax)),
      cad: wavg(rows.map(r => r.cad), w),
      cadMax: Math.max(...rows.map(r => r.cadMax)),
      pw: wavg(rows.map(r => r.pw), w),
      pwMax: Math.max(...rows.map(r => r.pwMax)),
      np: wavg(rows.map(r => r.np), w),
      vo: wavg(rows.map(r => r.vo), w),
      gct: wavg(rows.map(r => r.gct), w),
      step: wavg(rows.map(r => r.step), w),
      vr: wavg(rows.map(r => r.vr), w),
      kcal: rows.reduce((a, b) => a + (b.kcal || 0), 0),
    };
  };

  const warmAgg = agg(warm, 'Warm-up');
  const preAgg = agg(pre, 'Jeda pra-interval');
  const intAggs = intervals.map((rows, i) => agg(rows, `Interval ${i + 1}`));
  const recAggs = recs.map(r => agg([r], 'Recovery'));
  const coolAgg = agg(cool, 'Cooldown');
  const intAll = agg(actives, 'Total interval');

  const mean = a => a.reduce((x, y) => x + y, 0) / a.length;
  const sd = a => { const m = mean(a); return Math.sqrt(mean(a.map(v => (v - m) ** 2))); };
  const paces = intAggs.map(g => g.pace);
  const fastest = intAggs[paces.indexOf(Math.min(...paces))];
  const slowest = intAggs[paces.indexOf(Math.max(...paces))];

  // ---- HR per menit ----
  const t0 = new Date(records[0].timestamp).getTime();
  const byMin = {};
  for (const r of records) {
    const m = Math.floor((new Date(r.timestamp).getTime() - t0) / 60000);
    (byMin[m] ||= []).push(r);
  }
  const minRows = [];
  for (let m = 0; m <= 65; m++) {
    if (!byMin[m]) continue;
    const rs = byMin[m];
    const a = k => rs.reduce((x, y) => x + (y[k] || 0), 0) / rs.length;
    minRows.push({ m, hr: Math.round(a('heart_rate')) });
  }
  const chart = minRows.map(r => {
    const blocks = '█'.repeat(Math.max(0, Math.round((r.hr - 90) / 4)));
    return `${String(r.m).padStart(2, ' ')}m ${String(r.hr).padStart(3)} ${blocks}`;
  }).join('\n');

  // ---- zona ----
  const hrBounds = tiz?.hr_zone_high_boundary || [];
  const pwBounds = tiz?.power_zone_high_boundary || [];
  const zoneRows = (times, bounds, unit) => (times || [])
    .map((v, i) => ({ v, i }))
    .filter(({ i }) => i < bounds.length && bounds[i] != null)
    .map(({ v, i }) => {
      const total = (times || []).reduce((a, b) => a + b, 0);
      return [zoneLabel(i, bounds, unit), `${dec(v / 60, 1)} mnt`, `${dec(total ? v / total * 100 : 0, 1)} %`];
    });
  function zoneLabel(i, b, unit) {
    const hi = b[i] != null && b[i] < 4000 ? b[i] : null;
    const lo = i > 0 ? b[i - 1] : null;
    if (i === 0) return `Z1 (< ${hi} ${unit})`;
    return hi == null ? `Z${i + 1} (> ${lo} ${unit})` : `Z${i + 1} (${lo}–${hi} ${unit})`;
  }

  // ---- dinamika ----
  const sessionCad = (s.avg_cadence + (s.avg_fractional_cadence || 0)) * 2;
  const sessionCadMax = s.max_cadence * 2;

  const md = [];
  const P = (...l) => md.push(...l);

  P('# Analisis Sesi — Treadmill Running 5×5\'', '');
  P('**Atlet:** Albireo  ');
  P('**Tanggal:** Selasa, 10 November 2026 · mulai **07:06:46 WIB**  ');
  P('**Lokasi:** Treadmill (indoor, tanpa GPS)  ');
  P('**Sumber:** file .FIT hasil unduh Garmin Connect + detail activity API, 22 lap, 3.901 record per detik  ');
  P('**Workout:** `5x5\'` di daftar aktivitas · tertanam di FIT: `5x5\'+ 1x5\'` (6 langkah)  ');
  P('**Dibuat:** 10 November 2026  ');
  P('**Perangkat:** Garmin · **Zona waktu:** Asia/Bangkok (UTC+7) · **Unit:** metrik', '');

  // ---- ringkasan ----
  P('## Ringkasan sesi', '');
  const grid = [
    ['Jarak', `${dec(s.total_distance / 1000, 2)} km`, 'Durasi', hms(s.total_timer_time)],
    ['Waktu bergerak', hms(sum.movingDuration), 'Waktu diam', hms(s.total_timer_time - sum.movingDuration)],
    ['Pace rata-rata (seluruh sesi)', pace(s.total_timer_time / (s.total_distance / 1000)), 'Pace saat bergerak', pace(sum.movingDuration / (s.total_distance / 1000))],
    ['Kecepatan rata-rata', `${dec(s.enhanced_avg_speed * 3.6, 1)} km/j`, 'Kecepatan maks', `${dec(s.enhanced_max_speed * 3.6, 1)} km/j`],
    ['Kalori (C)', `${num(s.total_calories)} kcal`, 'Kalori BMR', `${num(s.metabolic_calories)} kcal`],
    ['Total work (mekanis)', `${num(s.total_work / 1000)} kJ ≈ ${num((s.total_work / 1000) * 0.239)} kcal`, 'Estimasi keringat', `${num(sum.waterEstimated)} ml`],
    ['HR rata2 / maks / min', `${s.avg_heart_rate} / ${s.max_heart_rate} / ${sum.minHR} bpm`, 'Recovery HR (1 mnt setelah stop)', `${sum.recoveryHeartRate} bpm`],
    ['Cadence rata2 (seluruh sesi)', `${dec(sessionCad, 1)} spm`, 'Cadence maks', `${dec(sessionCadMax, 0)} spm*`],
    ['Langkah total', `${num(sum.steps)}`, 'Suhu rata2 (min–maks)', `${dec(sum.averageTemperature, 1)}°C (${sum.minTemperature}–${sum.maxTemperature}°C)`],
    ['Power rata2 / maks / NP', `${s.avg_power} / ${s.max_power} / ${s.normalized_power} W`, 'FTP (threshold)', `${zt.functional_threshold_power} W`],
    ['GCT / VO / VR', `${dec(s.avg_stance_time, 1)} ms · ${dec(s.avg_vertical_oscillation / 10, 2)} cm · ${dec(s.avg_vertical_ratio, 2)} %`, 'Panjang langkah', `${dec(s.avg_step_length / 10, 2)} cm`],
    ['VO2 max est.', `${dec(um.first_vo2_max, 2)} → ${dec(um.vo2_max, 2)}`, 'Recovery time', `${Math.floor(1106 / 60)}j ${1106 % 60}m`],
    ['Training Effect', `${dec(s.total_training_effect, 1)} aer (${sum.trainingEffectLabel}) / ${dec(s.total_anaerobic_training_effect, 1)} ana`, 'RPE / Feel (0–10)', `${dec(sum.directWorkoutRpe / 10, 1)} / ${dec(sum.directWorkoutFeel / 10, 1)}`],
    ['Intensity minutes', `${sum.moderateIntensityMinutes} sedang + ${sum.vigorousIntensityMinutes} keras`, 'Body Battery', `−${Math.abs(sum.differenceBodyBattery)}`],
  ];
  P(table(['Metrik', 'Nilai', 'Metrik', 'Nilai'], grid), '');
  P('> *Cadence maks 210 spm adalah spike 1 sampel di lap recovery 13; cadence interval 163–166 spm. Sesi treadmill tidak punya elevasi/GPS.', '');

  // ---- struktur ----
  P('## Struktur workout', '');
  P('```');
  P('07:06:46 ─┬─ Warm-up      2.469 m · 15:00 · 6:05/km · HR 127/135');
  P('          ├─ Jeda          31 m   ·  1:30 · diam/HR 121');
  P('          ├─ Interval 1    1.054 m ·  5:00 · 4:45/km · HR 147/158');
  P('          ├─ Recovery 1    30 m   ·  1:15 · jalan/HR 147');
  P('          ├─ Interval 2    1.061 m ·  5:00 · 4:43/km · HR 152/160');
  P('          ├─ Recovery 2    75 m   ·  1:15 · jalan/HR 150');
  P('          ├─ Interval 3    1.080 m ·  5:00 · 4:38/km · HR 156/164');
  P('          ├─ Recovery 3    73 m   ·  1:15 · jalan/HR 154');
  P('          ├─ Interval 4    1.078 m ·  5:00 · 4:38/km · HR 156/168');
  P('          ├─ Recovery 4    78 m   ·  1:15 · jalan/HR 155');
  P('          ├─ Interval 5    1.076 m ·  5:00 · 4:39/km · HR 159/169');
  P('          └─ Cooldown      3.223 m · 18:30 · 5:45/km · HR 143/171');
  P('08:11:46 ─┴─ TOTAL        11.328 m · 65:00 · 5:44/km · HR 144/171');
  P('```', '');
  P('Workout tertanam di FIT (`wkt_name: 5x5\'+ 1x5\'`, 6 langkah) dan terkonfirmasi `splitSummaries` API: `interval_warmup 2.469 m/900 s`, `interval_active 5.349 m/1.500 s` (5 × 300 s), `interval_recovery 287 m/390 s`, `interval_cooldown 3.223 m/1.110 s`. Langkah terakhir yang terekspor (index 5) ber-intensity `cooldown` dengan durasi 600 s — cooldown aktual berlangsung 18:30 (diperpanjang manual).', '');

  // ---- zones ----
  P('## Zona HR & power', '');
  P('**Zona HR (batas sesuai watch, %HRR):**', '');
  P(table(['Zona', 'Waktu', 'Persen'], zoneRows(tiz?.time_in_hr_zone, hrBounds, 'bpm')), '');
  P('**Zona power (FTP 265 W):**', '');
  P(table(['Zona', 'Waktu', 'Persen'], zoneRows(tiz?.time_in_power_zone, pwBounds, 'W')), '');
  P('> 46% waktu di Z2 HR, 32% di Z3, 14% di Z4 — sesi mayoritas aerobik; di sisi power 44% di Z5 (265–305 W) karena lima interval berjalan di sekitar FTP. Konsisten dengan TE 2,9 "AEROBIC BASE".', '');

  // ---- dinamika ----
  P('## Dinamika lari', '');
  P(table(['Metrik', 'Sesi', 'Warm-up', 'Interval (rata2 5×)', 'Recovery', 'Cooldown'], [
    ['Cadence', `${dec(sessionCad, 1)} spm`, `${dec(warmAgg.cad, 0)} spm`, `${dec(mean(intAggs.map(g => g.cad)), 0)} spm`, `${dec(recAggs.length ? mean(recAggs.map(g => g.cad)) : null, 0)} spm`, `${dec(coolAgg.cad, 0)} spm`],
    ['Panjang langkah', `${dec(s.avg_step_length / 10, 1)} cm`, `${dec(warmAgg.step, 1)} cm`, `${dec(mean(intAggs.map(g => g.step)), 1)} cm`, `${dec(recAggs.length ? mean(recAggs.map(g => g.step)) : null, 1)} cm`, `${dec(coolAgg.step, 1)} cm`],
    ['Ground contact time', `${dec(s.avg_stance_time, 1)} ms`, `${dec(warmAgg.gct, 1)} ms`, `${dec(mean(intAggs.map(g => g.gct)), 1)} ms`, `${dec(recAggs.length ? mean(recAggs.map(g => g.gct)) : null, 1)} ms`, `${dec(coolAgg.gct, 1)} ms`],
    ['Vertical oscillation', `${dec(s.avg_vertical_oscillation / 10, 2)} cm`, `${dec(warmAgg.vo, 1)} cm`, `${dec(mean(intAggs.map(g => g.vo)), 1)} cm`, `${dec(recAggs.length ? mean(recAggs.map(g => g.vo)) : null, 1)} cm`, `${dec(coolAgg.vo, 1)} cm`],
    ['Vertical ratio', `${dec(s.avg_vertical_ratio, 2)} %`, `${dec(warmAgg.vr, 2)} %`, `${dec(mean(intAggs.map(g => g.vr)), 2)} %`, `${dec(recAggs.length ? mean(recAggs.map(g => g.vr)) : null, 2)} %`, `${dec(coolAgg.vr, 2)} %`],
    ['Power rata2', `${s.avg_power} W`, `${dec(warmAgg.pw, 0)} W`, `${dec(mean(intAggs.map(g => g.pw)), 0)} W`, `${dec(recAggs.length ? mean(recAggs.map(g => g.pw)) : null, 0)} W`, `${dec(coolAgg.pw, 0)} W`],
  ]), '');
  P('> Kontras interval vs warm-up: langkah +24 cm (106,5 → 130,6), GCT −35 ms (286 → 252), VR turun 9,71% → 8,29% — pola ekonomi lari yang sama seperti sesi 3 Nov. Kolom recovery adalah angka saat jalan (cadence 72 spm), bukan lari.', '');

  // ---- blok ----
  P('## Blok per sesi', '');

  P('### Warm-up (3 lap · 15:00)', '');
  P(table(['Lap', 'Mulai', 'Jarak', 'Durasi', 'Pace', 'HR a/m', 'Cad a/m', 'Power a/m', 'GCT', 'VO', 'VR'],
    warm.map(l => [`${l.i}`, l.start, `${num(l.dist)} m`, hms(l.timer), pace(l.pace), `${l.hr}/${l.hrMax}`,
      `${dec(l.cad, 0)}/${dec(l.cadMax, 0)}`, `${l.pw}/${l.pwMax}`, `${dec(l.gct, 0)} ms`, `${dec(l.vo, 1)} cm`, `${dec(l.vr, 2)} %`])), '');
  P(`Total: **${num(warmAgg.dist)} m · ${hms(warmAgg.timer)} · ${pace(warmAgg.pace)} · HR ${dec(warmAgg.hr, 0)}/${warmAgg.hrMax} · power ${dec(warmAgg.pw, 0)} W · ${num(warmAgg.kcal)} kcal**. Pace melompat 6:22 → 5:47 → 6:04/km (lap 2 lebih cepat), HR naik bertahap 124 → 129 bpm.`, '');

  P('### Jeda pra-interval (1 lap · 1:30)', '');
  P(`Lap ${pre[0].i} · ${num(preAgg.dist)} m · ${hms(preAgg.timer)} · HR ${preAgg.hr}/${preAgg.hrMax} — berdiri/jalan sangat pelan (cadence ${dec(preAgg.cad, 0)} spm) menyiapkan interval pertama. HR turun dari 128 → 121 bpm.`, '');

  P('### Interval — 5 × 5 menit', '');
  P('**Rekap interval:**', '');
  P(table(['Interval', 'Lap', 'Jarak', 'Durasi', 'Pace', 'Kecepatan', 'HR a/m', 'Cad a/m', 'Power a/m', 'NP', 'GCT', 'Langkah', 'kcal'],
    intAggs.map(g => [g.label, g.laps, `${num(g.dist)} m`, hms(g.timer), pace(g.pace), `${dec(g.speed, 1)} km/j`,
      `${dec(g.hr, 0)}/${g.hrMax}`, `${dec(g.cad, 0)}/${dec(g.cadMax, 0)}`, `${dec(g.pw, 0)}/${g.pwMax}`,
      `${dec(g.np, 0)}`, `${dec(g.gct, 0)} ms`, `${dec(g.step, 1)} cm`, `${num(g.kcal)}`])), '');
  P(table(['Metrik', 'Nilai'], [
    ['Total interval', `${num(intAll.dist)} m · ${hms(intAll.timer)} · ${pace(intAll.pace)} · ${dec(intAll.speed, 1)} km/j`],
    ['Rata-rata pace 5 interval', `${pace(mean(paces))}`],
    ['Interval tercepat / terlambat', `${fastest.label} ${pace(fastest.pace)} / ${slowest.label} ${pace(slowest.pace)}`],
    ['Konsistensi (SD pace)', `${dec(sd(paces.map(p => p * 1)), 1)} s/km`],
    ['Progresi HR rata2', `${intAggs.map(g => dec(g.hr, 0)).join(' → ')} bpm`],
    ['Progresi power rata2', `${intAggs.map(g => dec(g.pw, 0)).join(' → ')} W`],
    ['Progresi cadence', `${intAggs.map(g => dec(g.cad, 0)).join(' → ')} spm`],
  ]), '');
  P(`**Progresif:** pace membaik dari ${pace(intAggs[0].pace)} ke ${pace(intAggs[2].pace)} (interval 3–5 stabil di 4:38–4:39/km), HR naik konsisten ${dec(intAggs[0].hr, 0)} → ${dec(intAggs[4].hr, 0)} bpm, power ${dec(intAggs[0].pw, 0)} → ${dec(intAggs[4].pw, 0)} W. Interval 1 paling lambat (masih membuka dari diam); HR tertinggi antar-interval ada di interval 5 (169 bpm), sedangkan HR maks sesi 171 bpm baru terjadi di awal cooldown.`, '');

  for (let i = 0; i < intervals.length; i++) {
    P(`#### Interval ${i + 1} — ${num(intAggs[i].dist)} m · ${hms(intAggs[i].timer)} · ${pace(intAggs[i].pace)}`, '');
    P(table(['Lap', 'Mulai', 'Jarak', 'Durasi', 'Pace', 'HR a/m', 'Cad a/m', 'Power a/m', 'NP', 'GCT', 'Langkah', 'VO', 'VR'],
      intervals[i].map(l => [`${l.i}`, l.start, `${num(l.dist)} m`, hms(l.timer), pace(l.pace), `${l.hr}/${l.hrMax}`,
        `${dec(l.cad, 0)}/${dec(l.cadMax, 0)}`, `${l.pw}/${l.pwMax}`, `${l.np}`, `${dec(l.gct, 0)} ms`,
        `${dec(l.step, 1)} cm`, `${dec(l.vo, 1)} cm`, `${dec(l.vr, 2)} %`])), '');
    const g = intAggs[i];
    P(`Rata-rata: **${pace(g.pace)} · ${dec(g.speed, 1)} km/j · HR ${dec(g.hr, 0)}/${g.hrMax} · cadence ${dec(g.cad, 0)} spm · power ${dec(g.pw, 0)} W (NP ${dec(g.np, 0)}) · GCT ${dec(g.gct, 0)} ms · langkah ${dec(g.step, 1)} cm**`, '');
    if (i < recAggs.length) {
      const r = recAggs[i];
      P(`**Recovery ${i + 1}:** lap ${r.laps} · ${num(r.dist)} m · ${hms(r.timer)} · HR ${dec(r.hr, 0)}/${r.hrMax} — jalan di treadmill, HR turun dari ${g.hrMax} ke rata-rata ${dec(r.hr, 0)} bpm.`, '');
    }
    P('');
  }

  P('### Cooldown (4 lap · 18:30)', '');
  P(table(['Lap', 'Mulai', 'Jarak', 'Durasi', 'Pace', 'HR a/m', 'Cad a/m', 'Power a/m', 'GCT', 'VO', 'VR'],
    cool.map(l => [`${l.i}`, l.start, `${num(l.dist)} m`, hms(l.timer), pace(l.pace), `${l.hr}/${l.hrMax}`,
      `${dec(l.cad, 0)}/${dec(l.cadMax, 0)}`, `${l.pw}/${l.pwMax}`, `${dec(l.gct, 0)} ms`, `${dec(l.vo, 1)} cm`, `${dec(l.vr, 2)} %`])), '');
  P(`Total: **${num(coolAgg.dist)} m · ${hms(coolAgg.timer)} · ${pace(coolAgg.pace)} · HR ${dec(coolAgg.hr, 0)}/${coolAgg.hrMax}**. HR maks cooldown 171 bpm terjadi di awal lap 19 (residu interval 5 — satu-satunya waktu sesi menyentuh 171), lalu turun stabil ke 139–140 bpm.`, '');

  // ---- HR chart ----
  P('## Tren HR per menit', '');
  P('```');
  P(chart);
  P('```', '');
  P('Pola: menit 0 mulai 109 bpm lalu 15 menit pertama 124–130 bpm (warm-up), jeda menit 15–16 turun ke 114–125 bpm, lalu lima blok interval (menit 17–46) dengan puncak naik bertahap 156 → 159 → 162 → 164 → 167 bpm dan celah recovery 75 detik di antaranya, diikuti cooldown menit 47–65 yang turun ke 138–141 bpm.', '');

  // ---- lap table ----
  P('## Tabel lap lengkap (22 lap)', '');
  const lapTable = table(
    ['#', 'Mulai', 'Jarak', 'Durasi', 'Pace', 'HR a/m', 'Cad a/m', 'Power a/m', 'NP', 'kJ', 'VO', 'GCT', 'Langkah', 'VR', 'Suhu', 'kcal', 'Tipe'],
    norm.map(l => [
      `${l.i}`, l.start, `${num(l.dist)} m`, hms(l.timer), l.pace ? pace(l.pace) : '—',
      `${l.hr ?? '—'}/${l.hrMax ?? '—'}`,
      `${l.cad != null ? dec(l.cad, 0) : '—'}/${l.cadMax != null ? dec(l.cadMax, 0) : '—'}`,
      `${l.pw != null ? l.pw : '—'}/${l.pwMax != null ? l.pwMax : '—'}`,
      l.np != null ? l.np : '—', num(l.workKj), l.vo != null ? dec(l.vo, 1) : '—', l.gct != null ? dec(l.gct, 1) : '—',
      l.step != null ? dec(l.step, 1) : '—', l.vr != null ? dec(l.vr, 2) : '—',
      l.temp != null ? `${l.temp}°C` : '—', l.kcal != null ? l.kcal : '—',
      l.kind === 'warmup' ? 'Warm-up' : l.kind === 'cooldown' ? 'Cool-down' : l.kind === 'recovery' ? 'Recovery' : l.kind === 'active' ? 'Interval' : (l.kind || '—'),
    ])
  );
  P('<details>', `<summary>22 lap — klik untuk buka</summary>`, '', '> Legenda: HR a/m = avg/max · Cad spm · Power W · NP W · kJ (estimasi = avg power × durasi) · VO cm · GCT ms · Langkah cm · VR % · Suhu °C.', '', lapTable, '', '</details>', '');

  // ---- validasi ----
  P('## Validasi & konsistensi', '');
  const isIv = x => String(x.splitType || '').toUpperCase().startsWith('INTERVAL');
  const ivDist = splits.filter(isIv).reduce((a, x) => a + (x.distance || 0), 0);
  const ivTime = splits.filter(isIv).reduce((a, x) => a + (x.duration || 0), 0);
  const rwdDist = splits.filter(x => String(x.splitType || '').toUpperCase().startsWith('RWD')).reduce((a, x) => a + (x.distance || 0), 0);
  const rwdTime = splits.filter(x => String(x.splitType || '').toUpperCase().startsWith('RWD')).reduce((a, x) => a + (x.duration || 0), 0);
  P(table(['Sumber', 'Lap/split', 'Sampel', 'Jarak', 'Durasi', 'Mulai', 'Catatan'], [
    ['FIT (file unduh)', `${laps.length} lap`, `${num(records.length)} record`, `${dec(s.total_distance / 1000, 2)} km`, hms(s.total_timer_time), startLocal, 'sumber utama'],
    ['API detail (summaryDTO)', `${splits.length} split`, '—', `${dec(sum.distance / 1000, 2)} km`, hms(sum.duration), '07:06:46', 'aktivitas'],
    ['API split — taxonomi `interval_*`', `${splits.filter(isIv).length} split`, '—', `${dec(ivDist / 1000, 2)} km`, hms(ivTime), '—', 'warmup+active+recovery+cooldown'],
    ['API split — taxonomi `rwd_*`', `${splits.filter(x => !isIv(x)).length} split`, '—', `${dec(rwdDist / 1000, 2)} km`, hms(rwdTime), '—', 'run+stand+walk'],
  ]), '');
  P('> Empat sumber cocok: **11,33 km / 65:00 / mulai 07:06:46**. `splitSummaries` punya dua taksonomi saling menimpa (`interval_*` dan `rwd_*` masing-masing menjumlah tepat 3.900 s) — dihitung terpisah, bukan dijumlahkan. Selisih jarak < 1 m.', '');

  // ---- metodologi ----
  P('## Metodologi', '');
  P('- **Parser:** `fit-file-parser` (Node) membaca pesan `session`, `lap`, `record`, `time_in_zone`, `user_metrics`, `workout`. Blok interval dikelompokkan dari lap ber-intensitas `active` yang berurutan (dipisah lap `recovery`/`cooldown`).');
  P('- **Struktur 5×5′:** durasi tiap interval tepat 300 detik (5:00) — tervalidasi 5× dari `lap_trigger` dan `splitSummaries` `interval_active` 1.500 s. Tiap interval = lap 1 km + lap ekor 30–80 m (tombol lap ditekan tepat di batas waktu).');
  P('- **Cadence:** FIT menyimpan siklus (×2 → langkah/mnt). **VO & panjang langkah:** dibagi 10 (unit FIT → cm). **GCT** dari `stance_time` (ms), **VR** dari `vertical_ratio` (%).');
  P('- **Zona:** `time_in_zone` referensi `session`. **Catatan:** batas HR sesi ini [126, 144, 161, 176, 192, 208] bpm — bergeser 1 bpm dari sesi 3 Nov [125, 143, …] karena %HRR dihitung ulang watch. Batas power tetap [173, 212, 238, 265, 305] W (FTP 265 W).');
  P('- **Agregasi per blok:** rata-rata berbobot durasi lap (HR/cadence/power/GCT/dst.), kecuali maksimum yang diambil dari maks lap.');
  P('- **HR per menit:** rerata 3.901 sampel 1 Hz per menit kalender sesi.');
  P('');

  P('## Keterbatasan', '');
  P('1. **Treadmill tanpa GPS** — jarak berasal dari sensor treadmill/watch; pace bisa selisih ±1–2% dari kecepatan treadmill yang diatur.');
  P('2. **Cadence maks 210 spm** spike 1 sampel di lap recovery 13 — pakai cadence rata-rata interval (163–166 spm).');
  P('3. **Suhu 29–32°C** dari sensor unit, bukan suhu ruangan sebenarnya.');
  P('4. **Power lari** dihitung watch (bukan load cell) — berguna untuk relatif antar-blok, bukan absolut.');
  P('5. **Lap ekor interval** (15–22 detik) adalah sisa waktu setelah 1 km pertama — pace lap ini bervariasi 4:32–4:44/km karena durasinya sangat pendek; pace interval yang benar adalah gabungan 2 lap.');
  P('6. **RPE/Feel** dari input watch; VO2 max est. adalah estimasi Garmin, bukan uji laboratorium.');
  P('', '---', '');

  P('## Lampiran file', '');
  P('- Laporan ini: `D:\\Garmin\\API-Key-Data-Fetch\\Garmin-Session-2026-11-10-Treadmill-5x5.md`');
  P('- File asli: `D:\\Garmin\\API-Key-Data-Fetch\\sessions\\25026059313\\25026059313_ACTIVITY.fit`');
  P('- Detail API: `sessions\\25026059313\\activity-detail-25026059313.json` · daftar aktivitas: `data\\activitylist-2026-11-10.json`');
  P('- Script: `scripts\\fetch-session.ps1 -Id 25026059313` (tarik) · `scripts\\build-session-report-25026059313.js` (generator)');
  P('');
  P('*Dibuat otomatis dari file .FIT & Garmin Connect Personal API. Bukan nasihat medis.*');

  fs.writeFileSync(OUT, md.join('\n'), 'utf8');

  const summaryJson = {
    activityId: Number(ID),
    name: "5x5'",
    startLocal,
    distanceM: s.total_distance,
    timerSec: s.total_timer_time,
    movingSec: sum.movingDuration,
    avgHR: s.avg_heart_rate,
    maxHR: s.max_heart_rate,
    minHR: sum.minHR,
    calories: s.total_calories,
    steps: sum.steps,
    avgPower: s.avg_power,
    np: s.normalized_power,
    ftp: zt.functional_threshold_power,
    te: s.total_training_effect,
    anaerobicTE: s.total_anaerobic_training_effect,
    vo2: { first: um.first_vo2_max, final: um.vo2_max },
    recoveryTimeMin: 1106,
    intervals: intAggs.map(g => ({ laps: g.laps, dist: g.dist, timer: g.timer, paceSecPerKm: g.pace, hr: g.hr, hrMax: g.hrMax, cadence: g.cad, power: g.pw, np: g.np, gct: g.gct, step: g.step, vr: g.vr })),
    warmup: { dist: warmAgg.dist, timer: warmAgg.timer, pace: warmAgg.pace, hr: warmAgg.hr },
    cooldown: { dist: coolAgg.dist, timer: coolAgg.timer, pace: coolAgg.pace, hr: coolAgg.hr },
    zonesHr: tiz?.time_in_hr_zone ?? null,
    zonesPower: tiz?.time_in_power_zone ?? null,
    zonesHrBounds: hrBounds,
    zonesPowerBounds: pwBounds,
    laps: norm,
  };
  fs.writeFileSync(path.join(SESS, `session-${ID}.json`), JSON.stringify(summaryJson, null, 2), 'utf8');

  console.log('WROTE', OUT);
  console.log('lines', md.join('\n').split('\n').length);
  console.log('intervals', intAggs.map(g => `${Math.round(g.dist)}m ${g.timer}s ${Math.round(g.pace)}s/km HR${Math.round(g.hr)}/${g.hrMax} P${Math.round(g.pw)}`).join(' | '));
  console.log('warm', Math.round(warmAgg.dist), warmAgg.timer, 'cool', Math.round(coolAgg.dist), coolAgg.timer, 'nInt', intervals.length, 'rec', recAggs.length);
})().catch(e => { console.error(e); process.exit(1); });
