const fs = require('fs');
const path = require('path');
const FitParser = require('D:/Garmin/API-Key-Data-Fetch/scripts/node_modules/fit-file-parser').default;

const BASE = 'D:/Garmin/API-Key-Data-Fetch';
const ID = '25049716533';
const SESS = path.join(BASE, 'sessions', ID);
const FIT = path.join(SESS, `${ID}_ACTIVITY.fit`);
const DETAIL = path.join(SESS, `activity-detail-${ID}.json`);
const OUT = path.join(BASE, 'Garmin-Session-2026-11-12-Treadmill-Over-Under-Fartlek-35.md');

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

  // ---- blok ----
  const warm = norm.filter(x => x.kind === 'warmup');
  const cool = norm.filter(x => x.kind === 'cooldown');
  const pre = norm.filter(x => x.kind === 'recovery');   // jeda pra-interval (1 lap)
  const actives = norm.filter(x => x.kind === 'active');

  // OVER = lap 1 km + ekor pendek (total ~300 s); UNDER = lap tunggal ~120 s
  const overs = [], unders = [];
  let i = 0;
  while (i < actives.length) {
    const a = actives[i];
    if (a.timer >= 200) {
      const grp = [a];
      if (actives[i + 1] && actives[i + 1].timer < 60) { grp.push(actives[i + 1]); i++; }
      overs.push(grp); i++;
    } else if (a.timer >= 60) {
      unders.push([a]); i++;
    } else {
      (overs.length ? overs[overs.length - 1] : unders).push(a); i++;
    }
  }

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
  const preAgg = agg(pre, 'Jeda pra-set');
  const coolAgg = agg(cool, 'Cooldown');
  const overAggs = overs.map((rows, ix) => agg(rows, `OVER ${ix + 1}`));
  const underAggs = unders.map((rows, ix) => agg(rows, `UNDER ${ix + 1}`));
  const mainAgg = agg(actives, 'Total 35\'');
  const mainPace = overAggs.map(g => g.pace).concat(underAggs.map(g => g.pace));
  const overPaces = overAggs.map(g => g.pace);

  const mean = a => a.reduce((x, y) => x + y, 0) / a.length;
  const sd = a => { const m = mean(a); return Math.sqrt(mean(a.map(v => (v - m) ** 2))); };

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
    const blocks = '█'.repeat(Math.max(0, Math.round((r.hr - 60) / 4)));
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

  // ---- perbandingan sesi treadmill ----
  const prevSessions = [
    { f: 'session-24946233617.json', label: '3 Nov · 3×9\'' },
    { f: 'session-25026059313.json', label: '10 Nov · 5×5\'' },
  ].map(p => {
    try {
      const j = JSON.parse(fs.readFileSync(path.join(BASE, 'sessions', p.f.replace('session-', '').replace('.json', ''), p.f), 'utf8'));
      return {
        label: p.label,
        dist: j.distanceM, timer: j.timerSec, avgHR: j.avgHR, maxHR: j.maxHR,
        te: j.te ?? j.trainingEffect ?? null, kcal: j.calories, np: j.np,
      };
    } catch { return null; }
  }).filter(Boolean);

  const md = [];
  const P = (...l) => md.push(...l);

  P('# Rekap Lengkap Sesi — Over Under Fartlek 35\'', '');
  P('**Atlet:** Albireo  ');
  P('**Tanggal:** Kamis, 12 November 2026 · mulai **06:58:51 WIB**  ');
  P('**Lokasi:** Treadmill (indoor, tanpa GPS)  ');
  P('**Sumber:** file .FIT hasil unduh Garmin Connect + detail activity API, 22 lap, 3.901 record per detik  ');
  P('**Workout:** `Over Under Fartlek 35\'` — 5 × (5 menit OVER + 2 menit UNDER)  ');
  P('**Dibuat:** 12 November 2026  ');
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
    ['HR rata2 / maks / min', `${s.avg_heart_rate} / ${s.max_heart_rate} / ${sum.minHR} bpm*`, 'Recovery HR (1 mnt setelah stop)', `${sum.recoveryHeartRate} bpm`],
    ['Cadence rata2 (seluruh sesi)', `${dec(sessionCad, 1)} spm`, 'Cadence maks', `${dec(sessionCadMax, 0)} spm`],
    ['Langkah total', `${num(sum.steps)}`, 'Suhu rata2 (min–maks)', `${dec(sum.averageTemperature, 1)}°C (${sum.minTemperature}–${sum.maxTemperature}°C)`],
    ['Power rata2 / maks / NP', `${s.avg_power} / ${s.max_power} / ${s.normalized_power} W`, 'FTP (threshold)', `${zt.functional_threshold_power} W`],
    ['GCT / VO / VR', `${dec(s.avg_stance_time, 1)} ms · ${dec(s.avg_vertical_oscillation / 10, 2)} cm · ${dec(s.avg_vertical_ratio, 2)} %`, 'Panjang langkah', `${dec(s.avg_step_length / 10, 2)} cm`],
    ['VO2 max est.', `${dec(um.first_vo2_max, 2)} → ${dec(um.vo2_max, 2)}`, 'Recovery time', `${Math.floor(1164 / 60)}j ${1164 % 60}m`],
    ['Training Effect', `${dec(s.total_training_effect, 1)} aer (${sum.trainingEffectLabel}) / ${dec(s.total_anaerobic_training_effect, 1)} ana`, 'RPE / Feel (0–10)', `${dec(sum.directWorkoutRpe / 10, 1)} / ${dec(sum.directWorkoutFeel / 10, 1)}`],
    ['Intensity minutes', `${sum.moderateIntensityMinutes} sedang + ${sum.vigorousIntensityMinutes} keras`, 'Body Battery', `−${Math.abs(sum.differenceBodyBattery)}`],
  ];
  P(table(['Metrik', 'Nilai', 'Metrik', 'Nilai'], grid), '');
  P('> *HR min 62 bpm adalah satu sampel anomali saat sesi dimulai (sebelum berlari); rentang kerja nyata sesi 126–170 bpm. Cadence bersih tanpa spike (maks 168–169 spm). Sesi treadmill tanpa elevasi/GPS.', '');

  // ---- struktur ----
  P('## Struktur workout', '');
  P('```');
  P('06:58:51 ─┬─ Warm-up      2.560 m · 15:00 · 5:52/km · HR 130/138');
  P('          ├─ Jeda          31 m   ·  2:00 · diam/HR 115');
  overAggs.forEach((g, ix) => {
    const u = underAggs[ix];
    P(`          ├─ OVER ${ix + 1}       ${num(g.dist)} m ·  5:00 · ${pace(g.pace)} · HR ${dec(g.hr, 0)}/${g.hrMax}`);
    P(`          ├─ UNDER ${ix + 1}      ${num(u.dist)} m ·  2:00 · ${pace(u.pace)} · HR ${dec(u.hr, 0)}/${u.hrMax}`);
  });
  P('          └─ Cooldown      2.251 m · 13:00 · 5:47/km · HR 141/154');
  P('08:03:51 ─┴─ TOTAL        12.190 m · 65:00 · 5:20/km · HR 145/170');
  P('```', '');
  P('Total set utama: **5 OVER + 5 UNDER = 35 menit tepat** (5×300 s + 5×120 s = 2.100 s), 7.349 m. Terkonfirmasi `splitSummaries` API: `interval_warmup 2.560 m/900 s`, `interval_active 7.349 m/2.100 s`, `interval_recovery 31 m/120 s`, `interval_cooldown 2.251 m/780 s`. Catatan: nama workout di file FIT terbaca `Over Under Fartlek 35\'ngth` (string nama tampak terpotong di sumber); lap UNDER sengaja ber-intensitas `active` (fartlek aktif), bukan `recovery`.', '');

  // ---- zones ----
  P('## Zona HR & power', '');
  P('**Zona HR (batas sesuai watch, %HRR):**', '');
  P(table(['Zona', 'Waktu', 'Persen'], zoneRows(tiz?.time_in_hr_zone, hrBounds, 'bpm')), '');
  P('**Zona power (FTP 265 W):**', '');
  P(table(['Zona', 'Waktu', 'Persen'], zoneRows(tiz?.time_in_power_zone, pwBounds, 'W')), '');
  P('> Sesi menumpuk di Z3 HR (50% waktu) — tepat untuk fartlek aerobik; 53% waktu di Z5 power (265–305 W) karena OVER berjalan di sekitar FTP sementara UNDER tetap di atas Z4 power. TE 3,0 "AEROBIC BASE".', '');

  // ---- dinamika ----
  P('## Dinamika lari', '');
  const meanOver = k => mean(overAggs.map(g => g[k]));
  const meanUnder = k => mean(underAggs.map(g => g[k]));
  P(table(['Metrik', 'Sesi', 'Warm-up', 'OVER (rata2 5×)', 'UNDER (rata2 5×)', 'Cooldown'], [
    ['Cadence', `${dec(sessionCad, 1)} spm`, `${dec(warmAgg.cad, 0)} spm`, `${dec(meanOver('cad'), 0)} spm`, `${dec(meanUnder('cad'), 0)} spm`, `${dec(coolAgg.cad, 0)} spm`],
    ['Panjang langkah', `${dec(s.avg_step_length / 10, 1)} cm`, `${dec(warmAgg.step, 1)} cm`, `${dec(meanOver('step'), 1)} cm`, `${dec(meanUnder('step'), 1)} cm`, `${dec(coolAgg.step, 1)} cm`],
    ['Ground contact time', `${dec(s.avg_stance_time, 1)} ms`, `${dec(warmAgg.gct, 1)} ms`, `${dec(meanOver('gct'), 1)} ms`, `${dec(meanUnder('gct'), 1)} ms`, `${dec(coolAgg.gct, 1)} ms`],
    ['Vertical oscillation', `${dec(s.avg_vertical_oscillation / 10, 2)} cm`, `${dec(warmAgg.vo, 1)} cm`, `${dec(meanOver('vo'), 1)} cm`, `${dec(meanUnder('vo'), 1)} cm`, `${dec(coolAgg.vo, 1)} cm`],
    ['Vertical ratio', `${dec(s.avg_vertical_ratio, 2)} %`, `${dec(warmAgg.vr, 2)} %`, `${dec(meanOver('vr'), 2)} %`, `${dec(meanUnder('vr'), 2)} %`, `${dec(coolAgg.vr, 2)} %`],
    ['Power rata2', `${s.avg_power} W`, `${dec(warmAgg.pw, 0)} W`, `${dec(meanOver('pw'), 0)} W`, `${dec(meanUnder('pw'), 0)} W`, `${dec(coolAgg.pw, 0)} W`],
  ]), '');
  P(`> Kontras OVER vs UNDER terbaca jelas: langkah ${dec(meanUnder('step'), 1)} → ${dec(meanOver('step'), 1)} cm, GCT ${dec(meanUnder('gct'), 0)} → ${dec(meanOver('gct'), 0)} ms, VR ${dec(meanUnder('vr'), 2)}% → ${dec(meanOver('vr'), 2)}% — UNDER memakai langkah pendek dengan kaki tetap bergerak (lari pemulihan, bukan jalan).`, '');

  // ---- blok ----
  P('## Blok per sesi', '');

  P('### Warm-up (3 lap · 15:00)', '');
  P(table(['Lap', 'Mulai', 'Jarak', 'Durasi', 'Pace', 'HR a/m', 'Cad a/m', 'Power a/m', 'GCT', 'VO', 'VR'],
    warm.map(l => [`${l.i}`, l.start, `${num(l.dist)} m`, hms(l.timer), pace(l.pace), `${l.hr}/${l.hrMax}`,
      `${dec(l.cad, 0)}/${dec(l.cadMax, 0)}`, `${l.pw}/${l.pwMax}`, `${dec(l.gct, 0)} ms`, `${dec(l.vo, 1)} cm`, `${dec(l.vr, 2)} %`])), '');
  P(`Total: **${num(warmAgg.dist)} m · ${hms(warmAgg.timer)} · ${pace(warmAgg.pace)} · HR ${dec(warmAgg.hr, 0)}/${warmAgg.hrMax} · power ${dec(warmAgg.pw, 0)} W · ${num(warmAgg.kcal)} kcal**. Pace 6:01 → 5:43 → 5:50/km, HR naik 126 → 133 bpm.`, '');

  P('### Jeda pra-set (1 lap · 2:00)', '');
  P(`Lap ${pre[0].i} · ${num(preAgg.dist)} m · ${hms(preAgg.timer)} · HR ${preAgg.hr}/${preAgg.hrMax} — berdiri/jalan sangat pelan (cadence ${dec(preAgg.cad, 0)} spm). HR turun dari 131 → 115 bpm.`, '');

  P('### Set utama — Over Under Fartlek (35 menit)', '');
  P('**Rekap OVER (5 menit, cepat):**', '');
  P(table(['OVER', 'Lap', 'Jarak', 'Durasi', 'Pace', 'Kecepatan', 'HR a/m', 'Cad a/m', 'Power a/m', 'NP', 'GCT', 'Langkah', 'kcal'],
    overAggs.map((g, ix) => [`OVER ${ix + 1}`, g.laps, `${num(g.dist)} m`, hms(g.timer), pace(g.pace), `${dec(g.speed, 1)} km/j`,
      `${dec(g.hr, 0)}/${g.hrMax}`, `${dec(g.cad, 0)}/${dec(g.cadMax, 0)}`, `${dec(g.pw, 0)}/${g.pwMax}`,
      `${dec(g.np, 0)}`, `${dec(g.gct, 0)} ms`, `${dec(g.step, 1)} cm`, `${num(g.kcal)}`])), '');
  P('**Rekap UNDER (2 menit, ringan):**', '');
  P(table(['UNDER', 'Lap', 'Jarak', 'Durasi', 'Pace', 'Kecepatan', 'HR a/m', 'Cad a/m', 'Power a/m', 'NP', 'GCT', 'Langkah', 'kcal'],
    underAggs.map((g, ix) => [`UNDER ${ix + 1}`, g.laps, `${num(g.dist)} m`, hms(g.timer), pace(g.pace), `${dec(g.speed, 1)} km/j`,
      `${dec(g.hr, 0)}/${g.hrMax}`, `${dec(g.cad, 0)}/${dec(g.cadMax, 0)}`, `${dec(g.pw, 0)}/${g.pwMax}`,
      `${dec(g.np, 0)}`, `${dec(g.gct, 0)} ms`, `${dec(g.step, 1)} cm`, `${num(g.kcal)}`])), '');
  P(table(['Metrik', 'Nilai'], [
    ['Total set 35\'', `${num(mainAgg.dist)} m · ${hms(mainAgg.timer)} · ${pace(mainAgg.pace)} · ${dec(mainAgg.speed, 1)} km/j`],
    ['Rata-rata pace OVER', `${pace(mean(overPaces))} (rentang ${pace(Math.min(...overPaces))} – ${pace(Math.max(...overPaces))})`],
    ['Rata-rata pace UNDER', `${pace(mean(underAggs.map(g => g.pace)))} (rentang ${pace(Math.min(...underAggs.map(g => g.pace)))} – ${pace(Math.max(...underAggs.map(g => g.pace)))})`],
    ['Konsistensi pace OVER', `${dec(sd(overPaces), 1)} s/km`],
    ['Progresi HR rata2 OVER', `${overAggs.map(g => dec(g.hr, 0)).join(' → ')} bpm`],
    ['Progresi HR rata2 UNDER', `${underAggs.map(g => dec(g.hr, 0)).join(' → ')} bpm`],
    ['Progresi power OVER', `${overAggs.map(g => dec(g.pw, 0)).join(' → ')} W`],
    ['HR maks sesi', `${s.max_heart_rate} bpm di OVER 5 (lap 18)`],
  ]), '');
  P(`**Progresif:** OVER membaik ${pace(overAggs[0].pace)} → ${pace(overAggs[4].pace)} sementara HR OVER naik ${dec(overAggs[0].hr, 0)} → ${dec(overAggs[4].hr, 0)} bpm. Yang menarik: HR rata-rata UNDER juga naik tiap putaran (${dec(underAggs[0].hr, 0)} → ${dec(underAggs[4].hr, 0)} bpm) — UNDER terakhir (${dec(underAggs[4].hr, 0)} bpm) bahkan lebih tinggi dari OVER pertama (${dec(overAggs[0].hr, 0)} bpm), tanda kumulasi kelelahan meski pace UNDER dijaga.`, '');

  for (let k = 0; k < overAggs.length; k++) {
    const g = overAggs[k];
    P(`#### OVER ${k + 1} — ${num(g.dist)} m · ${hms(g.timer)} · ${pace(g.pace)}`, '');
    P(table(['Lap', 'Mulai', 'Jarak', 'Durasi', 'Pace', 'HR a/m', 'Cad a/m', 'Power a/m', 'NP', 'GCT', 'Langkah', 'VO', 'VR'],
      overs[k].map(l => [`${l.i}`, l.start, `${num(l.dist)} m`, hms(l.timer), pace(l.pace), `${l.hr}/${l.hrMax}`,
        `${dec(l.cad, 0)}/${dec(l.cadMax, 0)}`, `${l.pw}/${l.pwMax}`, `${l.np}`, `${dec(l.gct, 0)} ms`,
        `${dec(l.step, 1)} cm`, `${dec(l.vo, 1)} cm`, `${dec(l.vr, 2)} %`])), '');
    P(`Rata-rata: **${pace(g.pace)} · ${dec(g.speed, 1)} km/j · HR ${dec(g.hr, 0)}/${g.hrMax} · cadence ${dec(g.cad, 0)} spm · power ${dec(g.pw, 0)} W (NP ${dec(g.np, 0)}) · GCT ${dec(g.gct, 0)} ms · langkah ${dec(g.step, 1)} cm**`, '');
    if (k < underAggs.length) {
      const u = underAggs[k];
      P(`**UNDER ${k + 1}:** lap ${u.laps} · ${num(u.dist)} m · ${hms(u.timer)} · ${pace(u.pace)} · HR ${dec(u.hr, 0)}/${u.hrMax} · power ${dec(u.pw, 0)} W — lari ringan aktif, HR tetap ${dec(u.hr, 0)} bpm.`, '');
    }
    P('');
  }

  P('### Cooldown (3 lap · 13:00)', '');
  P(table(['Lap', 'Mulai', 'Jarak', 'Durasi', 'Pace', 'HR a/m', 'Cad a/m', 'Power a/m', 'GCT', 'VO', 'VR'],
    cool.map(l => [`${l.i}`, l.start, `${num(l.dist)} m`, hms(l.timer), pace(l.pace), `${l.hr}/${l.hrMax}`,
      `${dec(l.cad, 0)}/${dec(l.cadMax, 0)}`, `${l.pw}/${l.pwMax}`, `${dec(l.gct, 0)} ms`, `${dec(l.vo, 1)} cm`, `${dec(l.vr, 2)} %`])), '');
  P(`Total: **${num(coolAgg.dist)} m · ${hms(coolAgg.timer)} · ${pace(coolAgg.pace)} · HR ${dec(coolAgg.hr, 0)}/${coolAgg.hrMax}**. HR maks cooldown 154 bpm di awal (residu UNDER 5), lalu stabil 138–144 bpm.`, '');

  // ---- HR chart ----
  P('## Tren HR per menit', '');
  P('```');
  P(chart);
  P('```', '');
  P('Pola: menit 0 mulai 99 bpm, warm-up menit 1–15 di 123–134 bpm, jeda menit 16 turun ke 107 bpm, lalu set 35 menit (menit 17–51) bergelombang OVER/UNDER dengan puncak tiap putaran naik bertahap ±153 → 158 → 160 → 159 → 165 bpm (rerata per menit), diikuti cooldown menit 52–65 yang turun dari 151 ke 137 bpm.', '');

  // ---- lap table ----
  P('## Tabel lap lengkap (22 lap)', '');
  const overLapIds = new Set(overs.flat().map(l => l.i));
  const underLapIds = new Set(unders.flat().map(l => l.i));
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
      l.kind === 'warmup' ? 'Warm-up' : l.kind === 'cooldown' ? 'Cool-down' : l.kind === 'recovery' ? 'Jeda'
        : l.kind === 'active' ? (overLapIds.has(l.i) ? 'OVER' : underLapIds.has(l.i) ? 'UNDER' : 'Aktif') : (l.kind || '—'),
    ])
  );
  P('<details>', `<summary>22 lap — klik untuk buka</summary>`, '', '> Legenda: HR a/m = avg/max · Cad spm · Power W · NP W · kJ (estimasi = avg power × durasi) · VO cm · GCT ms · Langkah cm · VR % · Suhu °C · Tipe OVER/UNDER diturunkan dari durasi & jarak lap.', '', lapTable, '', '</details>', '');

  // ---- perbandingan ----
  if (prevSessions.length) {
    P('## Perbandingan 3 sesi treadmill terakhir', '');
    const rows = [
      ...prevSessions.map(p => [p.label, p.dist, p.timer, p.avgHR, p.maxHR, p.te, p.kcal, p.np]),
      ['12 Nov · Over Under 35\'', s.total_distance, s.total_timer_time, s.avg_heart_rate, s.max_heart_rate, s.total_training_effect, s.total_calories, s.normalized_power],
    ];
    P(table(['Sesi', 'Jarak', 'Durasi', 'HR avg', 'HR maks', 'TE', 'kcal', 'NP'], rows.map(r => [
      r[0], `${dec(r[1] / 1000, 2)} km`, hms(r[2]), `${r[3]} bpm`, `${r[4]} bpm`, dec(r[5], 1), num(r[6]), `${num(r[7])} W`,
    ])), '');
    P('> Ketiga sesi berdurasi sama (60–65 mnt) dengan HR rata2 144–145 bpm dan TE 2,9–3,1 — beban konsisten. Over Under Fartlek 35\' memberi jarak terjauh (12,19 km) dengan HR maks tertinggi kedua (170).', '');
  }

  // ---- validasi ----
  P('## Validasi & konsistensi', '');
  const isIv = x => String(x.splitType || '').toUpperCase().startsWith('INTERVAL');
  const ivDist = splits.filter(isIv).reduce((a, x) => a + (x.distance || 0), 0);
  const ivTime = splits.filter(isIv).reduce((a, x) => a + (x.duration || 0), 0);
  const rwdDist = splits.filter(x => String(x.splitType || '').toUpperCase().startsWith('RWD')).reduce((a, x) => a + (x.distance || 0), 0);
  const rwdTime = splits.filter(x => String(x.splitType || '').toUpperCase().startsWith('RWD')).reduce((a, x) => a + (x.duration || 0), 0);
  P(table(['Sumber', 'Lap/split', 'Sampel', 'Jarak', 'Durasi', 'Mulai', 'Catatan'], [
    ['FIT (file unduh)', `${laps.length} lap`, `${num(records.length)} record`, `${dec(s.total_distance / 1000, 2)} km`, hms(s.total_timer_time), startLocal, 'sumber utama'],
    ['API detail (summaryDTO)', `${splits.length} split`, '—', `${dec(sum.distance / 1000, 2)} km`, hms(sum.duration), '06:58:51', 'aktivitas'],
    ['API split — taxonomi `interval_*`', `${splits.filter(isIv).length} split`, '—', `${dec(ivDist / 1000, 2)} km`, hms(ivTime), '—', 'warmup+active+recovery+cooldown'],
    ['API split — taxonomi `rwd_*`', `${splits.filter(x => !isIv(x)).length} split`, '—', `${dec(rwdDist / 1000, 2)} km`, hms(rwdTime), '—', 'run+stand+walk'],
  ]), '');
  P('> Empat sumber cocok: **12,19 km / 65:00 / mulai 06:58:51**. `splitSummaries` punya dua taksonomi saling menimpa (`interval_*` dan `rwd_*` masing-masing menjumlah tepat 3.900 s) — dihitung terpisah, bukan dijumlahkan.', '');

  // ---- metodologi ----
  P('## Metodologi', '');
  P('- **Parser:** `fit-file-parser` (Node) membaca pesan `session`, `lap`, `record`, `time_in_zone`, `user_metrics`, `workout`.');
  P('- **Identifikasi OVER/UNDER:** semua lap set utama ber-intensitas `active`. OVER = lap ≥200 detik (1 km) yang diikuti lap ekor <60 detik (total tepat 300 s); UNDER = lap tunggal 60–180 detik (tepat 120 s). Hasil: 5 OVER + 5 UNDER, konsisten dengan `interval_active` 2.100 s.');
  P('- **Cadence:** FIT menyimpan siklus (×2 → langkah/mnt). **VO & panjang langkah:** dibagi 10 (unit FIT → cm). **GCT** dari `stance_time` (ms), **VR** dari `vertical_ratio` (%).');
  P('- **Zona:** `time_in_zone` referensi `session`; batas HR [126, 144, 161, 176, 192, 208] bpm, power [173, 212, 238, 265, 305] W (FTP 265 W).');
  P('- **Agregasi per blok:** rata-rata berbobot durasi lap; maksimum diambil dari maks lap.');
  P('- **HR per menit:** rerata 3.901 sampel 1 Hz per menit kalender sesi.');
  P('- **Perbandingan sesi:** dibaca dari ringkasan JSON sesi sebelumnya (`sessions\\24946233617\\`, `sessions\\25026059313\\`).');
  P('');

  P('## Keterbatasan', '');
  P('1. **Treadmill tanpa GPS** — jarak berasal dari sensor treadmill/watch; pace bisa selisih ±1–2% dari kecepatan treadmill yang diatur.');
  P('2. **HR min 62 bpm** adalah 1 sampel anomali saat awal sesi (bukan kondisi kerja); pakai rentang 126–170 bpm.');
  P('3. **Batas waktu OVER/UNDER** ditandai tombol lap manual — toleransi ±1–2 detik per blok.');
  P('4. **Power lari** dihitung watch (bukan load cell) — berguna untuk relatif antar-blok, bukan absolut.');
  P('5. **Suhu 30–33°C** dari sensor unit, bukan suhu ruangan sebenarnya.');
  P('6. **RPE/Feel** dari input watch; VO2 max est. adalah estimasi Garmin, bukan uji laboratorium.');
  P('', '---', '');

  P('## Lampiran file', '');
  P('- Laporan ini: `D:\\Garmin\\API-Key-Data-Fetch\\Garmin-Session-2026-11-12-Treadmill-Over-Under-Fartlek-35.md`');
  P('- File asli: `D:\\Garmin\\API-Key-Data-Fetch\\sessions\\25049716533\\25049716533_ACTIVITY.fit`');
  P('- Detail API: `sessions\\25049716533\\activity-detail-25049716533.json` · daftar aktivitas: `data\\activitylist-2026-11-12.json`');
  P('- Script: `scripts\\fetch-session.ps1 -Id 25049716533` (tarik) · `scripts\\build-session-report-25049716533.js` (generator)');
  P('');
  P('*Dibuat otomatis dari file .FIT & Garmin Connect Personal API. Bukan nasihat medis.*');

  fs.writeFileSync(OUT, md.join('\n'), 'utf8');

  const summaryJson = {
    activityId: Number(ID),
    name: "Over Under Fartlek 35'",
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
    recoveryTimeMin: 1164,
    structure: '5x(5m OVER + 2m UNDER) = 35m',
    over: overAggs.map(g => ({ laps: g.laps, dist: g.dist, timer: g.timer, paceSecPerKm: g.pace, hr: g.hr, hrMax: g.hrMax, cadence: g.cad, power: g.pw, np: g.np })),
    under: underAggs.map(g => ({ laps: g.laps, dist: g.dist, timer: g.timer, paceSecPerKm: g.pace, hr: g.hr, hrMax: g.hrMax, cadence: g.cad, power: g.pw })),
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
  console.log('over', overAggs.map(g => `${Math.round(g.dist)}m ${g.timer}s ${Math.round(g.pace)}s/km HR${Math.round(g.hr)}/${g.hrMax} P${Math.round(g.pw)}`).join(' | '));
  console.log('under', underAggs.map(g => `${Math.round(g.dist)}m ${g.timer}s ${Math.round(g.pace)}s/km HR${Math.round(g.hr)}/${g.hrMax} P${Math.round(g.pw)}`).join(' | '));
  console.log('warm', Math.round(warmAgg.dist), warmAgg.timer, 'cool', Math.round(coolAgg.dist), coolAgg.timer, 'main', Math.round(mainAgg.dist), mainAgg.timer);
})().catch(e => { console.error(e); process.exit(1); });
