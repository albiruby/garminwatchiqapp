const fs = require('fs');
const path = require('path');
const FitParser = require('D:/Garmin/API-Key-Data-Fetch/scripts/node_modules/fit-file-parser').default;

const BASE = 'D:/Garmin/API-Key-Data-Fetch';
const ID = '25070193425';
const SESS = path.join(BASE, 'sessions', ID);
const FIT = path.join(SESS, `${ID}_ACTIVITY.fit`);
const DETAIL = path.join(SESS, `activity-detail-${ID}.json`);
const OUT = path.join(BASE, 'Garmin-Session-2026-11-14-Bogor-16x600.md');

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
function zoneLabel(i, b, unit) {
  const hi = b[i] != null && b[i] < 4000 ? b[i] : null;
  const lo = i > 0 ? b[i - 1] : null;
  if (i === 0) return `Z1 (< ${hi} ${unit})`;
  return hi == null ? `Z${i + 1} (> ${lo} ${unit})` : `Z${i + 1} (${lo}–${hi} ${unit})`;
}

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
  const am = (data.activity_metrics || [])[0] || {};
  const zt = (Array.isArray(data.zones_target) ? data.zones_target[0] : data.zones_target) || {};

  const lapClock = iso => new Date(new Date(iso).getTime() + 7 * 3600e3).toISOString().slice(11, 19);
  const startLocal = new Date(new Date(s.start_time).getTime() + 7 * 3600e3).toISOString().slice(0, 19).replace('T', ' ');

  const norm = laps.map((l, i) => ({
    i: i + 1,
    start: lapClock(l.start_time),
    startMs: new Date(l.start_time).getTime(),
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
    asc: l.total_ascent ?? 0,
    desc: l.total_descent ?? 0,
    temp: l.avg_temperature != null ? Math.round(l.avg_temperature) : null,
    kind: l.intensity ?? null,
    trigger: l.lap_trigger ?? null,
    artifact: (l.total_distance ?? 0) < 5 && (l.total_timer_time ?? 0) <= 5 && i + 1 >= 29,
  }));

  // ---- klasifikasi ----
  const warm = norm.filter(x => x.kind === 'warmup');
  const cool = norm.filter(x => x.kind === 'cooldown');
  const artifacts = norm.filter(x => x.artifact);
  const actives = norm.filter(x => x.kind === 'active' && !x.artifact);
  const reps = actives.filter(x => x.dist >= 500);                  // 600 m
  const strides = actives.filter(x => x.dist >= 30 && x.dist < 200); // strides 20 s
  const recoveries = norm.filter(x => x.kind === 'recovery' && !x.artifact);

  const recoveryAfter = (idx) => {
    for (let j = idx + 1; j < norm.length; j++) {
      if (norm[j].artifact) continue;
      if (norm[j].kind === 'recovery') return norm[j];
      if (norm[j].kind === 'active' && !norm[j].artifact) return null;
    }
    return null;
  };

  const agg = (rows, label) => {
    const dist = rows.reduce((a, b) => a + b.dist, 0);
    const timer = rows.reduce((a, b) => a + b.timer, 0);
    const w = rows.map(r => r.timer);
    return {
      label, laps: rows.map(r => r.i).join('+'), dist, timer,
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
      asc: rows.reduce((a, b) => a + (b.asc || 0), 0),
      kcal: rows.reduce((a, b) => a + (b.kcal || 0), 0),
    };
  };

  const warmAgg = agg(warm, 'Warm-up');
  const coolAgg = agg(cool, 'Cooldown');
  const repAggs = reps.map((r, ix) => agg([r], `Rep ${ix + 1}`));
  const repAll = agg(reps, 'Total rep');
  const strideAggs = strides.map((r, ix) => agg([r], `Stride ${ix + 1}`));
  const repRecovs = reps.map(r => recoveryAfter(norm.indexOf(r))).filter(Boolean);
  const recovAll = recoveries.length ? agg(recoveries, 'Total recovery') : null;

  const mean = a => a.reduce((x, y) => x + y, 0) / a.length;
  const sd = a => { const m = mean(a); return Math.sqrt(mean(a.map(v => (v - m) ** 2))); };
  const repPaces = repAggs.map(g => g.pace);
  const fastest = repAggs[repPaces.indexOf(Math.min(...repPaces))];
  const slowest = repAggs[repPaces.indexOf(Math.max(...repPaces))];

  // ---- gap antar lap ----
  const gaps = [];
  for (let k = 0; k < norm.length - 1; k++) {
    const end = norm[k].startMs + norm[k].timer * 1000;
    const g = (norm[k + 1].startMs - end) / 1000;
    if (g >= 30) gaps.push({ after: norm[k].i, before: norm[k + 1].i, sec: g, at: norm[k].start });
  }
  const bigGap = gaps.reduce((a, b) => (b.sec > (a?.sec || 0) ? b : a), null);

  // ---- HR per menit ----
  const t0 = new Date(records[0].timestamp).getTime();
  const byMin = {};
  for (const r of records) {
    const m = Math.floor((new Date(r.timestamp).getTime() - t0) / 60000);
    (byMin[m] ||= []).push(r);
  }
  const minRows = [];
  for (let m = 0; m <= 87; m++) {
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
    .map((v, ix) => ({ v, i: ix }))
    .filter(({ i: ix }) => ix < bounds.length && bounds[ix] != null)
    .map(({ v, i: ix }) => {
      const total = (times || []).reduce((a, b) => a + b, 0);
      return [zoneLabel(ix, bounds, unit), `${dec(v / 60, 1)} mnt`, `${dec(total ? v / total * 100 : 0, 1)} %`];
    });

  const sessionCad = (s.avg_cadence + (s.avg_fractional_cadence || 0)) * 2;
  const sessionCadMax = s.max_cadence * 2;
  const workKj = s.avg_power * s.total_timer_time / 1000;
  const pauseSec = s.total_elapsed_time - s.total_timer_time;

  const lapType = l => {
    if (l.kind === 'warmup') return 'Warm-up';
    if (l.kind === 'cooldown') return 'Cool-down';
    if (l.artifact) return 'Artefak';
    if (l.kind === 'active' && l.dist >= 500) return 'Rep 600m';
    if (l.kind === 'active') return 'Stride';
    if (l.kind === 'recovery') return repRecovs.includes(l) ? 'Recovery rep' : (strides.some(st => norm.indexOf(st) < norm.indexOf(l) && repRecovs.length === 0) ? 'Recovery' : 'Recovery');
    return l.kind || '—';
  };

  const md = [];
  const P = (...l) => md.push(...l);

  P('# Full Audit + Laporan Lengkap — Bogor - 16x600', '');
  P('**Atlet:** Albireo  ');
  P('**Tanggal:** Jumat, 14 November 2026 · mulai **04:58:56 WIB**  ');
  P('**Lokasi:** Bogor (GPS start −6,5571 / 106,7335) · elevasi 192–203 m  ');
  P('**Sumber:** file .FIT hasil unduh Garmin Connect + detail activity API, 46 lap, 4.324 record per detik  ');
  P('**Workout:** `16x600` (daftar aktivitas) · tertanam di FIT: `16x600dy + Stability | Strengt` (22 langkah)  ');
  P('**Dibuat:** 14 November 2026  ');
  P('**Perangkat:** Garmin · **Zona waktu:** Asia/Bangkok (UTC+7) · **Unit:** metrik', '');

  // ---- ringkasan ----
  P('## Ringkasan sesi', '');
  const grid = [
    ['Jarak', `${dec(s.total_distance / 1000, 2)} km`, 'Durasi timer', hms(s.total_timer_time)],
    ['Elapsed total', hms(s.total_elapsed_time), 'Auto-pause (elapsed − timer)', hms(pauseSec)],
    ['Waktu bergerak', hms(sum.movingDuration), 'Waktu diam (non-moving)', hms(s.total_timer_time - sum.movingDuration)],
    ['Pace rata-rata (timer)', pace(s.total_timer_time / (s.total_distance / 1000)), 'Pace saat bergerak', pace(sum.movingDuration / (s.total_distance / 1000))],
    ['GAP (grade-adjusted)', sum.avgGradeAdjustedSpeed ? pace(1000 / sum.avgGradeAdjustedSpeed) : '—', 'Kecepatan rata2 / maks', `${dec(s.enhanced_avg_speed * 3.6, 1)} / ${dec(s.enhanced_max_speed * 3.6, 1)} km/j`],
    ['Elevasi naik / turun', `+${num(s.total_ascent)} / −${num(s.total_descent)} m`, 'Elevasi min–maks (rata2)', `${dec(sum.minElevation, 0)}–${dec(sum.maxElevation, 0)} m (${dec(sum.avgElevation, 1)})`],
    ['Kalori (C)', `${num(s.total_calories)} kcal`, 'Kalori BMR', `${num(s.metabolic_calories)} kcal`],
    ['Total work (mekanis)', `${num(workKj)} kJ ≈ ${num(workKj * 0.239)} kcal`, 'Estimasi keringat', `${num(sum.waterEstimated)} ml`],
    ['HR rata2 / maks / min', `${s.avg_heart_rate} / ${s.max_heart_rate} / ${sum.minHR} bpm`, 'Recovery HR (1 mnt setelah stop)', `${sum.recoveryHeartRate} bpm*`],
    ['Cadence rata2 (seluruh sesi)', `${dec(sessionCad, 1)} spm`, 'Cadence maks', `${dec(sessionCadMax, 0)} spm*`],
    ['Langkah total', `${num(sum.steps)}`, 'Suhu rata2 (min–maks)', `${dec(sum.averageTemperature, 1)}°C (${sum.minTemperature}–${sum.maxTemperature}°C)`],
    ['Power rata2 / maks / NP', `${s.avg_power} / ${s.max_power} / ${s.normalized_power} W`, 'FTP (threshold)', `${zt.functional_threshold_power} W`],
    ['GCT / VO / VR', `${dec(s.avg_stance_time, 1)} ms · ${dec(s.avg_vertical_oscillation / 10, 2)} cm · ${dec(s.avg_vertical_ratio, 2)} %`, 'Panjang langkah', `${dec(s.avg_step_length / 10, 2)} cm`],
    ['VO2 max est.', `${dec(um.first_vo2_max, 2)} → ${dec(am.vo2_max, 2)}`, 'Recovery time', `${Math.floor(am.recovery_time / 60)}j ${am.recovery_time % 60}m`],
    ['Training Effect', `${dec(s.total_training_effect, 1)} aer (${sum.trainingEffectLabel}) / ${dec(s.total_anaerobic_training_effect, 1)} ana`, 'RPE / Feel (0–10)', `${dec(sum.directWorkoutRpe / 10, 1)} / ${dec(sum.directWorkoutFeel / 10, 1)}`],
    ['Intensity minutes', `${sum.moderateIntensityMinutes} sedang + ${sum.vigorousIntensityMinutes} keras`, 'Body Battery', `−${Math.abs(sum.differenceBodyBattery)}`],
  ];
  P(table(['Metrik', 'Nilai', 'Metrik', 'Nilai'], grid), '');
  P('> *Recovery HR 6 bpm bacaan sangat rendah dibanding sesi lain (23–28) — kemungkinan sampling saat berhenti; jangan dipakai sebagai indikator pemulihan. Cadence maks 222 spm spike 1 sampel (lap 20); cadence rep 171–177 spm.', '');

  // ---- struktur ----
  P('## Struktur sesi', '');
  P('```');
  P('04:58:56 ─┬─ Warm-up      2.063 m · 15:00 · 7:16/km · HR 144/154');
  P('          ├─ Jeda          115 m  ·  1:30 · HR 138/155');
  P(`          ├─ [GAP]         ${bigGap ? hms(bigGap.sec) : '—'} tidak tercatat lap (auto-pause)`);
  P('          ├─ Stride 1–4    267 m  ·  4×0:20 + recovery 60/60/61 s + 2:00');
  P('          ├─ Rep 1         600 m  ·  2:56 · 4:53/km · HR 170/182');
  P('          ├─ Rep 2         600 m  ·  2:58 · 4:57/km · HR 171/179');
  P('          ├─ Rep 3         600 m  ·  2:59 · 4:59/km · HR 173/179');
  P('          ├─ Rep 4         600 m  ·  2:56 · 4:53/km · HR 176/180');
  P('          ├─ [jeda 2:30]');
  P('          ├─ Rep 5         600 m  ·  2:58 · 4:57/km · HR 171/180');
  P('          ├─ Rep 6         600 m  ·  2:57 · 4:55/km · HR 173/181');
  P('          ├─ Rep 7         600 m  ·  2:57 · 4:55/km · HR 176/183');
  P('          ├─ Rep 8         600 m  ·  2:58 · 4:57/km · HR 177/189 ← maks sesi');
  P('          ├─ [15 lap artefak 1–3 dtk · 0:14]');
  P('          └─ Cooldown      2.266 m · 15:10 · 6:41/km · HR 161/165');
  P('06:21:25 \u2500\u2510\u2500 TOTAL        10.191 m \u00b7 1:12:02 timer \u00b7 1:26:12 elapsed');
  P('```', '');

  // ---- AUDIT ----
  P('## Audit: rencana vs aktual', '');
  P(table(['Aspek', 'Rencana (nama workout)', 'Aktual (data .FIT)', 'Status'], [
    ['Jumlah rep 600 m', '16×', `${reps.length}× (lap ${reps.map(r => r.i).join(', ')})`, '⚠ tidak cocok'],
    ['Jarak total rep', '±9.600 m', `${num(repAll.dist)} m`, '⚠ 50% rencana'],
    ['Durasi set utama (aktif)', '±46 mnt', hms(repAll.timer), '—'],
    ['Struktur recovery', '—', `${repRecovs.length} recovery: 6× 50 s + 2× ±2:30 (setelah rep 4 & 8)`, 'tersusun rapi'],
    ['Lap bersih', '46 lap', `${artifacts.length} lap artefak 1–3 detik (lap ${artifacts.map(a => a.i).join(', ')})`, '⚠ perlu dibersihkan'],
    ['Gap tanpa lap', '—', bigGap ? `${hms(bigGap.sec)} (setelah lap ${bigGap.after}, sebelum lap ${bigGap.before})` : '—', '⚠ auto-pause'],
    ['Auto-pause total', '—', `${hms(pauseSec)} (elapsed − timer)`, 'informatif'],
    ['Durasi total', '—', `${hms(s.total_timer_time)} timer / ${hms(s.total_elapsed_time)} elapsed`, '—'],
  ]), '');
  P('**Temuan utama:**', '');
  P('1. **Hanya 8 rep 600 m yang terekam** — separuh dari nama "16x600". Hitungan waktu: struktur penuh 16 rep (16 × ±177 dtk + 15 recovery ±50–150 dtk + warm-up 15\' + strides/jeda 7\' + cooldown 15\') akan membutuhkan timer ±103 menit — sesi ini hanya 72 menit, jadi **secara fisik hanya muat 8 rep** pada struktur yang berjalan. Alternatif lain: 8 rep pertama dikerjakan tanpa menekan lap (tidak ada bukti lap 600 m lain di file).');
  P(`2. **${artifacts.length} lap artefak** (lap ${artifacts[0].i}–${artifacts[artifacts.length - 1].i}, total 0:14, jarak 3 m, durasi 1–3 detik per lap) pada 06:05:52–06:06:15 — pola tombol lap tertekan berulang (kemungkinan gerakan tangan saat recovery akhir). Artefak ini menambah ±12 detik ke \`interval_active\` API.`);
  if (bigGap) {
    const gapEndMs = norm[bigGap.after - 1].startMs + norm[bigGap.after - 1].timer * 1000;
    const fmtClock = ms => new Date(ms + 7 * 3600e3).toISOString().slice(11, 19);
    P(`3. **Gap ${hms(bigGap.sec)} tanpa lap** (${fmtClock(gapEndMs)} \u2192 ${norm[bigGap.before - 1].start}, setelah jeda pra-strides, sebelum stride pertama) \u2014 sesi berhenti di luar lap (istirahat/penyesuaian). Total auto-pause ${hms(pauseSec)}.`);
  }
  P('4. **HR maks 189 bpm** di rep terakhir (lap 27) — HR tertinggi di antara semua sesi 31 Okt–14 Nov (sesi lain 155–184). Dalam riwayat 12 bulan (372 aktivitas s/d 27 Okt 2026), **46 sesi menyentuh ≥189** (top: 208 bpm) — sesi interval Bogor rutin menekan zona atas.');
  P('5. **VO2 max est. naik ke 53,01** (sesi sebelumnya hanya 52,08–52,18) dan TE **3,8 LACTATE_THRESHOLD** — beban tertinggi di antara 4 sesi terakhir (2,9–3,1).');
  P('6. **Konsistensi rep sangat tinggi:** rentang pace hanya 4:53–4:59/km (SD 1,7 s/km) meski HR naik 170 → 177 bpm (drift +7) — sinyal sesi threshold yang terkontrol.');
  P('');

  // ---- zones ----
  P('## Zona HR & power', '');
  P('**Zona HR (batas sesuai watch, %HRR):**', '');
  P(table(['Zona', 'Waktu', 'Persen'], zoneRows(tiz?.time_in_hr_zone, hrBounds, 'bpm')), '');
  P('**Zona power (FTP 265 W):**', '');
  P(table(['Zona', 'Waktu', 'Persen'], zoneRows(tiz?.time_in_power_zone, pwBounds, 'W')), '');
  P('> **55% waktu di Z4–Z5 HR** (161–192 bpm) dan 29% di Z5 power — distribusi khas sesi threshold; konsisten dengan TE 3,8 "LACTATE_THRESHOLD". Zona rendah (Z1–Z2) tersisa 15% karena warm-up langsung, gap, dan cooldown yang tetap 158–163 bpm.', '');

  // ---- dinamika ----
  const dyn = k => {
    const warmV = warmAgg[k], repV = repAll[k], coolV = coolAgg[k];
    return [warmV, repV, coolV];
  };
  P('## Dinamika lari', '');
  P(table(['Metrik', 'Sesi', 'Warm-up', 'Rep 600 m (rata2 8×)', 'Cooldown'], [
    ['Cadence', `${dec(sessionCad, 1)} spm`, `${dec(warmAgg.cad, 0)} spm`, `${dec(repAll.cad, 0)} spm`, `${dec(coolAgg.cad, 0)} spm`],
    ['Panjang langkah', `${dec(s.avg_step_length / 10, 1)} cm`, `${dec(warmAgg.step, 1)} cm`, `${dec(repAll.step, 1)} cm`, `${dec(coolAgg.step, 1)} cm`],
    ['Ground contact time', `${dec(s.avg_stance_time, 1)} ms`, `${dec(warmAgg.gct, 1)} ms`, `${dec(repAll.gct, 1)} ms`, `${dec(coolAgg.gct, 1)} ms`],
    ['Vertical oscillation', `${dec(s.avg_vertical_oscillation / 10, 2)} cm`, `${dec(warmAgg.vo, 1)} cm`, `${dec(repAll.vo, 1)} cm`, `${dec(coolAgg.vo, 1)} cm`],
    ['Vertical ratio', `${dec(s.avg_vertical_ratio, 2)} %`, `${dec(warmAgg.vr, 2)} %`, `${dec(repAll.vr, 2)} %`, `${dec(coolAgg.vr, 2)} %`],
    ['Power rata2', `${s.avg_power} W`, `${dec(warmAgg.pw, 0)} W`, `${dec(repAll.pw, 0)} W`, `${dec(coolAgg.pw, 0)} W`],
    ['Elevasi (blok)', '—', `+${num(warmAgg.asc)} m`, `+${num(repAll.asc)} m`, `+${num(coolAgg.asc)} m`],
  ]), '');
  P(`> Kontras rep vs warm-up: langkah ${dec(warmAgg.step, 1)} → ${dec(repAll.step, 1)} cm (+${dec(repAll.step - warmAgg.step, 1)}), GCT ${dec(warmAgg.gct, 0)} → ${dec(repAll.gct, 0)} ms, VR ${dec(warmAgg.vr, 2)}% → ${dec(repAll.vr, 2)}%. Elevasi bertambah +${num(repAll.asc)} m selama set rep (naik-turun per lintasan lapangan).`, '');

  // ---- audit 16x600: tabel rep ----
  P('## Audit set 600 m', '');
  P('**Rekap 8 rep tercatat:**', '');
  P(table(['Rep', 'Lap', 'Mulai', 'Durasi', 'Pace', 'HR a/m', 'Cad a/m', 'Power a/m', 'NP', 'GCT', 'Langkah', 'VR', 'Elev +', 'Recovery setelah'],
    repAggs.map((g, ix) => {
      const l = reps[ix];
      const rec = repRecovs[ix];
      return [`${ix + 1}`, `${l.i}`, l.start, hms(l.timer), pace(g.pace), `${g.hr}/${g.hrMax}`,
        `${dec(g.cad, 0)}/${dec(g.cadMax, 0)}`, `${dec(g.pw, 0)}/${g.pwMax}`, `${dec(g.np, 0)}`,
        `${dec(g.gct, 0)} ms`, `${dec(g.step, 1)} cm`, `${dec(g.vr, 2)} %`, `+${l.asc} m`,
        rec ? `${dec(rec.timer, 0)} s · HR ${rec.hr}/${rec.hrMax}` : '—'];
    })), '');
  P(table(['Metrik', 'Nilai'], [
    ['Total rep', `${reps.length} × 600 m = ${num(repAll.dist)} m · ${hms(repAll.timer)}`],
    ['Pace rata-rata', `${pace(mean(repPaces))} (SD ${dec(sd(repPaces), 1)} s/km)`],
    ['Rep tercepat / terlambat', `${fastest.label} ${pace(fastest.pace)} / ${slowest.label} ${pace(slowest.pace)}`],
    ['Progresi HR rata2', `${repAggs.map(g => dec(g.hr, 0)).join(' → ')} bpm (drift +${dec(repAggs[repAggs.length - 1].hr - repAggs[0].hr, 0)})`],
    ['Progresi HR maks', `${repAggs.map(g => g.hrMax).join(' → ')} bpm`],
    ['Progresi pace', `${repAggs.map(g => pace(g.pace)).join(' · ')}`],
    ['Progresi cadence', `${repAggs.map(g => dec(g.cad, 0)).join(' → ')} spm`],
    ['Progresi power', `${repAggs.map(g => dec(g.pw, 0)).join(' → ')} W (NP ${repAggs.map(g => dec(g.np, 0)).join('/')})`],
    ['GCT rata2', `${dec(repAll.gct, 1)} ms (rentang ${dec(Math.min(...repAggs.map(g => g.gct)), 0)}–${dec(Math.max(...repAggs.map(g => g.gct)), 0)})`],
    ['Pola recovery', `6× 50 s antar rep + 150 s setelah rep 4 + 148 s setelah rep 8 (total ${hms(repRecovs.reduce((a, b) => a + b.timer, 0))})`],
  ]), '');
  P('**Pola:** dua set 4 rep dengan jeda 2:30 di antaranya (seperti sesi 20x400). Pace terkunci rapat (4:53–4:59), sementara HR naik konsisten tiap rep (+7 bpm rata-rata, maks +14 ke 189) — drift klasik sesi threshold pagi. Recovery 50 s cukup untuk HR turun ~7–10 bpm tapi tidak penuh (rep berikutnya mulai di 170–173).', '');

  // ---- blok ----
  P('## Blok per sesi', '');

  P('### Warm-up (3 lap · 15:00)', '');
  P(table(['Lap', 'Mulai', 'Jarak', 'Durasi', 'Pace', 'HR a/m', 'Cad a/m', 'Power a/m', 'GCT', 'Langkah', 'VR'],
    warm.map(l => [`${l.i}`, l.start, `${num(l.dist)} m`, hms(l.timer), pace(l.pace), `${l.hr}/${l.hrMax}`,
      `${dec(l.cad, 0)}/${dec(l.cadMax, 0)}`, `${l.pw}/${l.pwMax}`, `${dec(l.gct, 0)} ms`, `${dec(l.step, 1)} cm`, `${dec(l.vr, 2)} %`])), '');
  P(`Total: **${num(warmAgg.dist)} m · ${hms(warmAgg.timer)} · ${pace(warmAgg.pace)} · HR ${dec(warmAgg.hr, 0)}/${warmAgg.hrMax} · power ${dec(warmAgg.pw, 0)} W**.`, '');

  P('### Jeda & strides (lap 4–12)', '');
  P(table(['Lap', 'Mulai', 'Tipe', 'Jarak', 'Durasi', 'Pace', 'HR a/m', 'Cad a/m', 'Power a/m', 'Catatan'],
    norm.filter(l => l.i >= 4 && l.i <= 12).map(l => [
      `${l.i}`, l.start, lapType(l), `${num(l.dist)} m`, hms(l.timer), l.pace ? pace(l.pace) : '—',
      `${l.hr}/${l.hrMax}`, `${dec(l.cad, 0)}/${dec(l.cadMax, 0)}`, `${l.pw}/${l.pwMax}`,
      l.i === 4 ? 'jeda pra-strides' : l.i === 12 ? 'jeda pra-set (2:00)' : l.kind === 'active' ? 'stride 20 dtk' : 'recovery stride',
    ])), '');
  P(`4 strides 20 detik (65–68 m, pace 4:55–5:06/km) dengan recovery 60/60/61 s + jeda 2:00 sebelum set. Catatan: ${bigGap ? `ada **gap ${hms(bigGap.sec)}** antara lap 4 dan lap 5 (05:15:27 → 05:25:53) yang tidak terekam lap.` : 'tidak ada gap besar.'}`, '');

  P('### Recovery antar rep', '');
  P(table(['Setelah rep', 'Lap', 'Durasi', 'Jarak', 'HR awal → akhir (rata2)', 'Catatan'],
    repAggs.map((g, ix) => {
      const rec = repRecovs[ix];
      if (!rec) return [`${ix + 1}`, '—', '—', '—', '—', '—'];
      return [`${ix + 1}`, `${rec.i}`, `${dec(rec.timer, 0)} s`, `${num(rec.dist)} m`,
        `${g.hrMax} → ${dec(rec.hr, 0)} bpm`, ix === 3 || ix === 7 ? 'jeda panjang set (2:30)' : 'recovery singkat'];
    })), '');
  P('');

  P('### Cooldown (3 lap · 15:10)', '');
  P(table(['Lap', 'Mulai', 'Jarak', 'Durasi', 'Pace', 'HR a/m', 'Cad a/m', 'Power a/m', 'GCT', 'Langkah', 'VR'],
    cool.map(l => [`${l.i}`, l.start, `${num(l.dist)} m`, hms(l.timer), pace(l.pace), `${l.hr}/${l.hrMax}`,
      `${dec(l.cad, 0)}/${dec(l.cadMax, 0)}`, `${l.pw}/${l.pwMax}`, `${dec(l.gct, 0)} ms`, `${dec(l.step, 1)} cm`, `${dec(l.vr, 2)} %`])), '');
  P(`Total: **${num(coolAgg.dist)} m \u00b7 ${hms(coolAgg.timer)} \u00b7 ${pace(coolAgg.pace)} \u00b7 HR ${dec(coolAgg.hr, 0)}/${coolAgg.hrMax}** \u2014 HR cooldown tetap tinggi 158\u2013163 bpm (rata2 161, maks 165): residu set yang belum turun sampai akhir sesi.`, '');

  // ---- HR chart ----
  P('## Tren HR per menit', '');
  P('```');
  P(chart);
  P('```', '');
  P('Pola: warm-up menit 0\u201316 naik 115 \u2192 152 bpm; **data hilang menit 17\u201325** (gap auto-pause 10:26 \u2014 record berhenti saat sesi berhenti); strides & jeda menit 26\u201332 di 122\u2013144; set 600 m menit 33\u201364 bergelombang 161\u2013184 dengan lembah 142 (jeda 2:30 menit 49) dan puncak 184 (menit 63); recovery akhir + artefak menit 65\u201367 di 141\u2013155; cooldown menit 68\u201382 justru bertahan tinggi 156\u2013164 (residu set) lalu menit 86 turun ke 117 saat berhenti.', '');

  // ---- lap table ----
  P('## Tabel lap lengkap (46 lap)', '');
  const lapTable = table(
    ['#', 'Mulai', 'Jarak', 'Durasi', 'Pace', 'HR a/m', 'Cad a/m', 'Power a/m', 'NP', 'kJ', 'VO', 'GCT', 'Langkah', 'VR', 'Elev ±', 'kcal', 'Tipe'],
    norm.map(l => [
      `${l.i}`, l.start, `${num(l.dist)} m`, hms(l.timer), l.pace ? pace(l.pace) : '—',
      `${l.hr ?? '—'}/${l.hrMax ?? '—'}`,
      `${l.cad != null ? dec(l.cad, 0) : '—'}/${l.cadMax != null ? dec(l.cadMax, 0) : '—'}`,
      `${l.pw != null ? l.pw : '—'}/${l.pwMax != null ? l.pwMax : '—'}`,
      l.np != null ? l.np : '—', num(l.workKj), l.vo != null ? dec(l.vo, 1) : '—', l.gct != null ? dec(l.gct, 1) : '—',
      l.step != null ? dec(l.step, 1) : '—', l.vr != null ? dec(l.vr, 2) : '—',
      `+${l.asc}/−${l.desc}`, l.kcal != null ? l.kcal : '—', lapType(l),
    ])
  );
  P('<details>', `<summary>46 lap — klik untuk buka</summary>`, '', '> Legenda: HR a/m = avg/max · Cad spm · Power W · NP W · kJ (estimasi = avg power × durasi) · VO cm · GCT ms · Langkah cm · VR % · Elev +/− m. Lap artefak (0–2 m, 1–3 dtk) tetap ditampilkan untuk audit.', '', lapTable, '', '</details>', '');

  // ---- validasi ----
  P('## Validasi & konsistensi', '');
  const isIv = x => String(x.splitType || '').toUpperCase().startsWith('INTERVAL');
  const ivDist = splits.filter(isIv).reduce((a, x) => a + (x.distance || 0), 0);
  const ivTime = splits.filter(isIv).reduce((a, x) => a + (x.duration || 0), 0);
  const rwdDist = splits.filter(x => String(x.splitType || '').toUpperCase().startsWith('RWD')).reduce((a, x) => a + (x.distance || 0), 0);
  const rwdTime = splits.filter(x => String(x.splitType || '').toUpperCase().startsWith('RWD')).reduce((a, x) => a + (x.duration || 0), 0);
  const lapDist = norm.reduce((a, l) => a + l.dist, 0);
  const lapTime = norm.reduce((a, l) => a + l.timer, 0);
  P(table(['Sumber', 'Lap/split', 'Sampel', 'Jarak', 'Durasi', 'Mulai', 'Catatan'], [
    ['FIT (file unduh)', `${laps.length} lap`, `${num(records.length)} record`, `${dec(s.total_distance / 1000, 2)} km`, hms(s.total_timer_time), startLocal, 'sumber utama'],
    ['FIT (jumlah lap)', `${laps.length} lap`, '\u2014', `${dec(lapDist / 1000, 2)} km`, hms(lapTime), '\u2014', Math.abs(lapDist - s.total_distance) < 5 ? 'jumlah lap identik dengan session (<5 m)' : `selisih ${dec(Math.abs(lapDist - s.total_distance), 1)} m vs session`],
    ['API detail (summaryDTO)', `${splits.length} split`, '—', `${dec(sum.distance / 1000, 2)} km`, hms(sum.duration), '04:58:56', `elapsed ${hms(sum.elapsedDuration)}`],
    ['API split — taxonomi `interval_*`', `${splits.filter(isIv).length} split`, '—', `${dec(ivDist / 1000, 2)} km`, hms(ivTime), '—', 'warmup+active+recovery+cooldown'],
    ['API split — taxonomi `rwd_*`', `${splits.filter(x => !isIv(x)).length} split`, '—', `${dec(rwdDist / 1000, 2)} km`, hms(rwdTime), '—', 'run+stand+walk'],
  ]), '');
  P('> Semua sumber sepakat **10,19 km / mulai 04:58:56**; timer FIT 1:12:02 vs API 1:12:00 (selisih 2 dtk stop terakhir). Jumlah lap melebihi jumlah blok nyata karena 15 lap artefak.', '');

  // ---- metodologi ----
  P('## Metodologi', '');
  P('- **Parser:** `fit-file-parser` (Node): pesan `session`, `lap`, `record`, `time_in_zone`, `user_metrics`, `activity_metrics`, `workout`.');
  P('- **Identifikasi blok:** rep = lap `active` jarak ≥500 m (8 lap × 600 m); stride = lap `active` 30–200 m (4 lap, 20 dtk); artefak = jarak <5 m & durasi ≤5 dtk pada lap 29–43; recovery = lap `recovery` (non-artefak).');
  P('- **Gap antar lap:** selisih `start[i+1] − (start[i] + timer[i])`; gap ≥30 dtk dilaporkan (1 gap besar).');
  P('- **Cadence:** siklus FIT ×2 → langkah/mnt. **VO & langkah:** ÷10 → cm. **GCT** `stance_time` (ms), **VR** `vertical_ratio` (%).');
  P('- **Zona:** `time_in_zone` referensi `session`; batas HR [125, 143, 161, 176, 192, 208] bpm, power [173, 212, 238, 265, 305] W (FTP 265 W).');
  P('- **Agregasi:** rata-rata berbobot durasi lap; maksimum dari maks lap. **Konteks HR:** `data\\hr-history\\activities-2025-10-27_2026-10-27.json` (372 aktivitas).');
  P('- **HR per menit:** rerata 4.324 sampel 1 Hz per menit kalender sesi.');
  P('');

  P('## Keterbatasan', '');
  P('1. **Jumlah rep sebenarnya** (8 vs 16) tidak bisa dipastikan dari file — data hanya berisi 8 lap 600 m; sisa 16 tidak muncul sebagai lap aktif mana pun.');
  P('2. **GPS pagi Bogor** — akurasi jarak 600 m ±1–3%; elevasi dari barometer/GPS (31 m naik, +1–6 m per rep).');
  P('3. **Cadence maks 222 spm** spike 1 sampel (lap 20); **HR min 97** dan **recovery HR 6** bacaan anomali awal/akhir — jangan dipakai untuk kesimpulan.');
  P('4. **Power lari** dihitung watch; NP per rep berbasis lap 176\u2013179 dtk \u2014 cukup andal untuk perbandingan relatif antar rep, bukan absolut.');
  P('5. **Gap 10:26** tidak terekam dalam data lap — isi aktivitas di rentang itu (istirahat vs lari tanpa lap) tidak diketahui.');
  P('6. **RPE/Feel 5** input watch; VO2 max & TE estimasi Garmin, bukan uji laboratorium.');
  P('', '---', '');

  P('## Lampiran file', '');
  P('- Laporan ini: `D:\\Garmin\\API-Key-Data-Fetch\\Garmin-Session-2026-11-14-Bogor-16x600.md`');
  P('- File asli: `D:\\Garmin\\API-Key-Data-Fetch\\sessions\\25070193425\\25070193425_ACTIVITY.fit`');
  P('- Detail API: `sessions\\25070193425\\activity-detail-25070193425.json` · daftar aktivitas: `data\\activitylist-2026-11-14.json`');
  P('- Script: `scripts\\fetch-session.ps1 -Id 25070193425` (tarik) · `scripts\\build-session-report-25070193425.js` (generator)');
  P('');
  P('*Dibuat otomatis dari file .FIT & Garmin Connect Personal API. Bukan nasihat medis.*');

  fs.writeFileSync(OUT, md.join('\n'), 'utf8');

  const summaryJson = {
    activityId: Number(ID),
    name: 'Bogor - 16x600',
    startLocal,
    distanceM: s.total_distance,
    timerSec: s.total_timer_time,
    elapsedSec: s.total_elapsed_time,
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
    vo2: { first: um.first_vo2_max, final: am.vo2_max },
    recoveryTimeMin: am.recovery_time,
    elevationGain: s.total_ascent,
    reps: repAggs.map((g, ix) => ({ rep: ix + 1, lap: reps[ix].i, timer: g.timer, paceSecPerKm: g.pace, hr: g.hr, hrMax: g.hrMax, cadence: g.cad, power: g.pw, np: g.np, gct: g.gct, step: g.step, vr: g.vr, elev: reps[ix].asc, recoverySec: repRecovs[ix]?.timer ?? null })),
    plannedReps: 16,
    recordedReps: reps.length,
    artifactLaps: artifacts.map(a => a.i),
    gaps: gaps.map(g => ({ afterLap: g.after, beforeLap: g.before, sec: g.sec })),
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
  console.log('reps', reps.length, repAggs.map(g => `${Math.round(g.pace)}s/km HR${Math.round(g.hr)}/${g.hrMax}`).join(' | '));
  console.log('strides', strides.length, 'artifacts', artifacts.length, 'gaps', JSON.stringify(gaps.map(g => `${g.after}->${g.before}:${g.sec}s`)));
  console.log('warm', Math.round(warmAgg.dist), warmAgg.timer, 'cool', Math.round(coolAgg.dist), coolAgg.timer, 'repDist', Math.round(repAll.dist), repAll.timer);
})().catch(e => { console.error(e); process.exit(1); });
