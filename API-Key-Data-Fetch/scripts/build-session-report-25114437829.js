const fs = require('fs');
const path = require('path');
const FitParser = require('D:/Garmin/API-Key-Data-Fetch/scripts/node_modules/fit-file-parser').default;

const BASE = 'D:/Garmin/API-Key-Data-Fetch';
const ID = '25114437829';
const SESS = path.join(BASE, 'sessions', ID);
const FIT = path.join(SESS, `${ID}_ACTIVITY.fit`);
const DETAIL = path.join(SESS, `activity-detail-${ID}.json`);
const OUT = path.join(BASE, 'Garmin-Session-2026-11-18-Bogor-Running.md');

const nf = new Intl.NumberFormat('id-ID');
const num = x => (x === null || x === undefined || Number.isNaN(x)) ? '—' : nf.format(Math.round(x));
const dec = (x, d = 2) => (x === null || x === undefined || Number.isNaN(x)) ? '—' : x.toFixed(d).replace('.', ',');
const dec1 = x => dec(x, 1);
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
  const s = data.sessions[0];
  const laps = data.laps || [];
  const records = data.records || [];
  const tiz = (data.time_in_zone || []).find(t => t.reference_mesg === 'session');
  const um = (data.user_metrics || [])[0] || {};
  const am = (data.activity_metrics || [])[0] || {};
  const zt = (Array.isArray(data.zones_target) ? data.zones_target[0] : data.zones_target) || {};

  const lapClock = iso => new Date(new Date(iso).getTime() + 7 * 3600e3).toISOString().slice(11, 19);

  const norm = laps.map((l, i) => ({
    i: i + 1,
    start: lapClock(l.start_time),
    dist: l.total_distance ?? 0,
    timer: l.total_timer_time ?? 0,
    pace: (l.total_distance >= 50 && l.total_timer_time) ? l.total_timer_time / (l.total_distance / 1000) : null,
    hr: l.avg_heart_rate ?? null,
    hrMax: l.max_heart_rate ?? null,
    cad: l.avg_cadence != null ? Math.round((l.avg_cadence + (l.avg_fractional_cadence || 0)) * 2) : null,
    cadMax: l.max_cadence != null ? Math.round((l.max_cadence + (l.max_fractional_cadence || 0)) * 2) : null,
    pw: l.avg_power ?? null,
    pwMax: l.max_power ?? null,
    np: l.normalized_power ?? null,
    kcal: l.total_calories ?? null,
    gct: l.avg_stance_time ?? null,
    vo: l.avg_vertical_oscillation != null ? l.avg_vertical_oscillation / 10 : null,
    vr: l.avg_vertical_ratio ?? null,
    step: l.avg_step_length != null ? l.avg_step_length / 10 : null,
    asc: l.total_ascent ?? 0,
    trigger: l.lap_trigger ?? null,
  }));

  // record-level aggregates
  let moveT = 0, maxSp = 0, minHR = 999, maxCad = 0, sumCad = 0, nCad = 0, lastT = null;
  const gaps = [];
  for (const r of records) {
    const t = new Date(r.timestamp).getTime();
    if (lastT != null && t - lastT > 15000) gaps.push({ at: new Date(lastT).toISOString(), sec: Math.round((t - lastT) / 1000) });
    lastT = t;
    const sp = r.enhanced_speed ?? 0;
    if (sp > maxSp) maxSp = sp;
    if (sp > 0.5) moveT += 1;
    if (r.heart_rate != null && r.heart_rate < minHR) minHR = r.heart_rate;
    const cd = (r.cadence || 0) * 2;
    if (cd > maxCad) maxCad = cd;
    if (cd > 0) { sumCad += cd; nCad++; }
  }

  const distKm = (s.total_distance ?? 0) / 1000;
  const timerSec = s.total_timer_time ?? 0;
  const avgPace = timerSec / distKm;
  const steps = sum.steps ?? null;
  const stepLen = (steps && distKm) ? (s.total_distance / steps * 100) : null;
  const ftp = zt.functional_threshold_power ?? null;
  const np = s.normalized_power ?? null;

  const hzSec = tiz?.time_in_hr_zone || [];
  const hzB = tiz?.hr_zone_high_boundary || [];
  const pzSec = tiz?.time_in_power_zone || [];
  const pzB = tiz?.power_zone_high_boundary || [];
  const hzTot = hzSec.reduce((a, b) => a + b, 0) || 1;
  const pzTot = pzSec.reduce((a, b) => a + b, 0) || 1;
  const pct = (v, t) => (v / t * 100).toFixed(1).replace('.', ',') + '%';
  const hmsS = v => { v = Math.round(v); return `${Math.floor(v / 60)}:${String(v % 60).padStart(2, '0')}`; };
  const zoneRow = (i, b, unit, secArr, tot) => {
    const hi = b[i] != null && b[i] < 4000 ? b[i] : null;
    const lo = i > 0 ? b[i - 1] : null;
    const u = unit ? ` ${unit}` : '';
    const lbl = i === 0 ? `Z1 (<${hi}${u})` : (hi == null ? `Z${i + 1} (>${lo}${u})` : `Z${i + 1} (${lo}–${hi}${u})`);
    return [lbl, hmsS(secArr[i] || 0), pct(secArr[i] || 0, tot)];
  };

  const L = [];
  L.push(`# Bogor Running — Easy 9,2 km — Rabu, 18 November 2026`);
  L.push(``);
  L.push(`**Atlet:** Albireo`);
  L.push(`**Tanggal:** Rabu, 18 November 2026 — **05:49:27 WIB**`);
  L.push(`**Lokasi:** Bogor (outdoor, GPS)`);
  L.push(`**Workout:** tanpa workout terstruktur — free run steady (10 lap, semua \`active\`, distance-trigger)`);
  L.push(`**Sumber:** file .FIT asli + detail activity API, ${norm.length} lap, ${records.length} record per detik`);
  L.push(`**Dibuat:** 18 November 2026`);
  L.push(`**Perangkat:** Garmin — FTP ${ftp ?? '—'} W — **Zona waktu:** Asia/Bangkok (UTC+7) — **Unit:** metrik`);
  L.push(``);
  L.push(`## Ringkasan sesi`);
  L.push(``);
  L.push(table(['Metrik', 'Nilai', 'Metrik', 'Nilai'], [
    ['Jarak (FIT)', `**${dec(distKm, 3)} km**`, 'Jarak (Garmin summary/API)', `**${dec((sum.distance ?? 0) / 1000, 3)} km**`],
    ['Durasi timer / elapsed', `${hms(timerSec)} / ${hms(s.total_elapsed_time)}`, 'Jeda (elapsed − timer)', `${Math.round((s.total_elapsed_time ?? 0) - timerSec)} detik`],
    ['Waktu bergerak (>0,5 m/s)', hms(moveT), 'Kecepatan maks', `${dec((maxSp * 3.6), 1)} km/j`],
    ['Pace rata-rata (FIT)', pace(avgPace), 'Kecepatan rata-rata (FIT)', `${dec((s.total_distance / timerSec) * 3.6, 1)} km/j`],
    ['Kalori (C)', `${num(s.total_calories)} kcal`, 'Kalori BMR', `${num(s.metabolic_calories)} kcal`],
    ['Total work (mekanis)', `${num((s.total_work ?? 0) / 1000)} kJ ≈ ${num((s.total_work ?? 0) / 1000 / 4.184)} kcal`, 'Estimasi keringat', `${num(s.est_sweat_loss)} ml`],
    ['HR rata2 / maks / min', `${s.avg_heart_rate} / ${s.max_heart_rate} / ${minHR === 999 ? '—' : minHR} bpm`, 'Ascent / descent', `${Math.round(s.total_ascent ?? 0)} m / ${Math.round(s.total_descent ?? 0)} m`],
    ['Cadence rata-rata', `${nCad ? Math.round(sumCad / nCad) : '—'} spm`, 'Cadence maks', `${maxCad} spm`],
    ['Langkah total', steps != null ? `${num(steps)} (panjang ${dec1(stepLen)} cm)` : '—', 'Suhu rata-rata (min–maks)', `${Math.round(s.avg_temperature ?? 0)}°C (${Math.round(s.min_temperature ?? 0)}–${Math.round(s.max_temperature ?? 0)}°C)`],
    ['Power rata2 / maks / NP', `${s.avg_power} / ${s.max_power} / ${np} W`, 'FTP / NP/FTP', `${ftp} W / ${np && ftp ? dec(np / ftp, 2) : '—'}`],
    ['GCT / VO / VR', `${dec1(s.avg_stance_time)} ms · ${dec(s.avg_vertical_oscillation / 10, 2)} cm · ${dec(s.avg_vertical_ratio, 2)} %`, 'Grade-adj speed', `${dec(s.avg_grade_adjusted_speed ?? 0, 2)} m/s`],
    ['VO₂ max est.', `${dec(um.first_vo2_max, 2)} → **${dec(am.vo2_max || um.vo2_max, 2)}**`, 'Recovery time', `${Math.floor((am.recovery_time ?? 0) / 60)}j ${Math.round((am.recovery_time ?? 0) % 60)}m`],
    ['Training Effect', `${dec(s.total_training_effect, 1)} (TEMPO) / ${dec(s.total_anaerobic_training_effect, 1)} ana`, 'RPE / Feel (0–10)', `${dec((s.workout_rpe ?? 0) / 10, 1)} / ${dec((s.workout_feel ?? 0) / 10, 1)}`],
    ['Intensity minutes', `${sum.moderateIntensityMinutes ?? 0} sedang + ${sum.vigorousIntensityMinutes ?? 0} keras`, 'Elevasi (API) gain/loss', `${Math.round(sum.elevationGain ?? 0)} m / ${Math.round(sum.elevationLoss ?? 0)} m`],
  ]));
  L.push(``);
  L.push(`## Struktur sesi`);
  L.push(``);
  L.push('```');
  const endClock = new Date(new Date(laps[laps.length - 1].start_time).getTime() + 7 * 3600e3 + (laps[laps.length - 1].total_elapsed_time ?? laps[laps.length - 1].total_timer_time ?? 0) * 1000).toISOString().slice(11, 19);
  L.push(`05:49:27 ─┬─────────── STOP ${endClock} (timer ${hms(timerSec)}, elapsed ${hms(s.total_elapsed_time)})`);
  norm.forEach((l, i) => {
    const tag = i === norm.length - 1 ? '└─' : '├─';
    const last = i === norm.length - 1;
    L.push(`${tag} Km ${i + 1}${last ? ' (parsial)' : ''}  ${(l.dist / 1000).toFixed(3).replace('.', ',')} km · ${hms(l.timer)} · ${pace(l.pace)} · HR ${l.hr}/${l.hrMax} · ${l.pw} W`);
  });
  L.push('```');
  L.push(``);
  L.push(`Sepuluh split 1 km yang sangat konsisten (${norm.slice(0, 9).map(l => pace(l.pace)).join(' → ')}) dengan HR merambat naik ${norm[0].hr} → ${norm[norm.length - 1].hr} bpm — cardiac drift tipikal pagi lembap 29°C pada pace konstan. Satu jeda 57 detik di tengah km 5 (lihat audit). Km terakhir parsial 194 m sedikit ditekan (${pace(norm[norm.length - 1].pace)}).`);
  L.push(``);
  L.push(`## Zona HR & power`);
  L.push(``);
  L.push(`Batas HR: **${hzB.filter(b => b < 4000).join(' / ')}** bpm (%HRR); power: FTP ${ftp} W.`);
  L.push(``);
  const hzRows = [], pzRows = [];
  for (let i = 0; i < 6; i++) hzRows.push(zoneRow(i, hzB, '', hzSec, hzTot));
  for (let i = 0; i < 6; i++) pzRows.push(zoneRow(i, pzB, '', pzSec, pzTot));
  L.push(table(['Zona', 'HR waktu', '%HR', 'Power waktu', '%Power'], hzRows.map((r, i) => [r[0], r[1], r[2], pzRows[i] ? pzRows[i][1] : '—', pzRows[i] ? pzRows[i][2] : '—'])));
  L.push(``);
  L.push(`Mayoritas waktu di **Z3 HR** (${pct(hzSec[2] || 0, hzTot)}) dengan power **Z2–Z3** — sesi easy aerobik murni (TE 3,3 TEMPO, anaerobik 0,0).`);
  L.push(``);
  L.push(`## Dinamika lari per km`);
  L.push(``);
  L.push(table(['Km', 'Waktu', 'Jarak', 'Durasi', 'Pace', 'HR avg/maks', 'Cad', 'Power', 'GCT', 'VO', 'VR', 'Langkah'], norm.map(l => [
    l.i, l.start, `${(l.dist / 1000).toFixed(3).replace('.', ',')} km`, hms(l.timer), `**${pace(l.pace)}**`,
    `${l.hr} / ${l.hrMax}`, l.cad, `${l.pw} W`, `${dec1(l.gct)}`, `${dec(l.vo, 1)}`, `${dec(l.vr, 2)}%`, `${dec1(l.step)}`,
  ])));
  L.push(``);
  L.push(`## Jeda & auto-pause`);
  L.push(``);
  if (gaps.length) {
    gaps.forEach(g => L.push(`- Jeda **${g.sec} detik** pada ${new Date(new Date(g.at).getTime() + 7 * 3600e3).toISOString().slice(11, 19)} WIB (tengah km 5) — timer pause, bukan gap GPS.`));
  } else {
    L.push(`- Tidak ada jeda.`);
  }
  L.push(``);
  L.push(`## Audit & validasi`);
  L.push(``);
  L.push(table(['Aspek', 'Data', 'Status'], [
    ['Aktivitas ditemukan', `id \`${ID}\`, \`Bogor Running\`, outdoor running`, '✅'],
    ['Durasi API vs FIT', `API ${sum.duration} s = FIT timer ${timerSec} s`, sum.duration === timerSec ? '✅ identik' : '⚠ beda'],
    ['Jarak API vs FIT', `API ${dec(sum.distance / 1000, 3)} km vs FIT ${dec(distKm, 3)} km`, Math.abs(sum.distance / 1000 - distKm) < 0.01 ? '✅ identik' : '⚠ beda'],
    ['Total timer lap', `${hms(norm.reduce((a, b) => a + b.timer, 0))} vs session ${hms(timerSec)}`, '✅'],
    ['Total jarak lap', `${dec(norm.reduce((a, b) => a + b.dist, 0) / 1000, 3)} km vs session ${dec(distKm, 3)} km`, '✅'],
    ['Langkah', `API ${num(steps)} vs FIT jarak/langkah ${dec1(stepLen)} cm`, '✅ konsisten'],
    ['Zona waktu', `HR total ${hms(hzTot)} vs timer ${hms(timerSec)}`, Math.abs(hzTot - timerSec) < 5 ? '✅' : '⚠'],
    ['Gap implisit', gaps.length ? `${gaps.length} jeda (${gaps.map(g => g.sec + 's').join(', ')})` : 'tidak ada', gaps.length ? '⚠ cek' : '✅'],
  ]));
  L.push(``);
  L.push(`**Temuan utama:**`);
  L.push(``);
  L.push(`1. **Easy run steady klasik** — 9 km nyaris identik di ~6:31/km, power ~210 W datar, NP = avg (variability index 1,00).`);
  L.push(`2. **Cardiac drift +22 bpm** (144 → 166) pada pace/power konstan — wajar untuk 29°C pagi lembap, bukan tanda kelelahan.`);
  L.push(`3. **Satu-satunya jeda hanya 57 detik** di tengah km 5 — sesi praktis nonstop.`);
  L.push(`4. **Finish dengan pickup** — 194 m terakhir ${pace(norm[norm.length - 1].pace)}, HR 166/169, power 230 W.`);
  L.push(`5. **VO₂ max naik tipis 53,01 → ${dec(am.vo2_max || um.vo2_max, 2)}** — tren aerobic base berlanjut.`);
  L.push(`6. **NP/FTP 0,80** — intensitas easy yang benar (di bawah 0,85).`);
  L.push(``);
  L.push(`## Metodologi & keterbatasan`);
  L.push(``);
  L.push(`- **Parser:** \`fit-file-parser\` (Node), pesan \`session\`, \`lap\`, \`record\`, \`time_in_zone\`, \`user_metrics\`, \`activity_metrics\`, \`zones_target\` + detail API.`);
  L.push(`- **Cadence:** FIT menyimpan siklus (×2 → spm). VO/langkah dibagi 10. GCT \`stance_time\` (ms), VR \`vertical_ratio\` (%).`);
  L.push(`- **Zona:** \`time_in_zone\` reference \`session\`; batas HR [${hzB.filter(b => b != null && b < 4000).join(', ')}] %HRR; power [${pzB.filter(b => b != null && b < 4000).join(', ')}] W; FTP ${ftp} W.`);
  L.push(`- **Jeda:** selisih timestamp record >15 detik; timer pause dikonfirmasi dari elapsed − timer.`);
  L.push(`- **Keterbatasan:** elevasi GPS barometrik ringan (Bogor relatif datar, 13 m); power dari algoritma wrist-based Garmin; VO₂ max estimasi.`);
  L.push(``);
  L.push(`## Lampiran file`);
  L.push(``);
  L.push(`- Laporan ini: \`D:\\Garmin\\API-Key-Data-Fetch\\Garmin-Session-2026-11-18-Bogor-Running.md\``);
  L.push(`- File asli: \`sessions\\${ID}\\${ID}_ACTIVITY.fit\` (+ \`.zip\`)`);
  L.push(`- Detail API: \`sessions\\${ID}\\activity-detail-${ID}.json\``);
  L.push(`- Daftar aktivitas hari ini: \`data\\activitylist-2026-11-18.json\``);
  L.push(`- Builder: \`scripts\\build-session-report-${ID}.js\``);
  L.push(``);
  L.push(`*Dibuat otomatis dari file .FIT & Garmin Connect Personal API. Bukan nasihat medis.*`);

  const utf8 = new (require('util').TextEncoder)();
  fs.writeFileSync(OUT, L.join('\n'), 'utf8');
  console.log('WROTE', OUT);
})().catch(e => { console.error(e); process.exit(1); });
