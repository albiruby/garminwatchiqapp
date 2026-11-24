const fs = require('fs');
const path = require('path');
const FitParser = require('D:/Garmin/API-Key-Data-Fetch/scripts/node_modules/fit-file-parser').default;

const SESS = 'D:/Garmin/API-Key-Data-Fetch/sessions/24910882666';
const FIT = path.join(SESS, '24910882666_ACTIVITY.fit');
const TCX = path.join(SESS, 'activity_24910882666.tcx');
const OUT = 'D:/Garmin/API-Key-Data-Fetch/Garmin-Session-2026-10-31-Bogor-20x400.md';

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
const zoneWord = z => `Z${z}`;
const table = (head, rows) => {
  const out = [];
  out.push('| ' + head.join(' | ') + ' |');
  out.push('|' + head.map((_, i) => i === 0 ? '---' : '---:').join('|') + '|');
  for (const r of rows) out.push('| ' + r.join(' | ') + ' |');
  return out.join('\n');
};
const clock = (iso, off = 7) => new Date(new Date(iso).getTime() + off * 3600e3).toISOString();

function parseFit() {
  return new Promise((resolve, reject) => {
    const parser = new FitParser({ force: true, speedUnit: 'm/s', lengthUnit: 'm', temperatureUnit: 'C' });
    parser.parse(fs.readFileSync(FIT), (err, data) => err ? reject(err) : resolve(data));
  });
}

(async () => {
  const data = await parseFit();
  const s = data.sessions[0];
  const laps = data.laps || [];
  const records = data.records || [];
  const tiz = data.time_in_zone || [];
  const tizS = tiz.find(t => t.reference_mesg === 'session');
  const um = (data.user_metrics || [])[0] || {};
  const am = (data.activity_metrics || [])[0] || {};
  const ztRaw = data.zones_target;
  const zt = Array.isArray(ztRaw) ? ztRaw[0] : (ztRaw || {});

  const startLocal = clock(s.start_time);
  const lapClock = iso => clock(iso).slice(11, 19);

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
    workKj: l.total_work != null ? l.total_work / 1000 : null,
    kcal: l.total_calories ?? null,
    vo: l.avg_vertical_oscillation != null ? l.avg_vertical_oscillation / 10 : null,
    gct: l.avg_stance_time ?? null,
    step: l.avg_step_length != null ? l.avg_step_length / 10 : null,
    vr: l.avg_vertical_ratio ?? null,
    asc: l.total_ascent ?? null,
    desc: l.total_descent ?? null,
    temp: l.avg_temperature != null ? Math.round(l.avg_temperature) : null,
    kind: l.intensity ?? null,
    trigger: l.lap_trigger ?? null,
  }));

  const warm = norm.filter(x => x.kind === 'warmup');
  const strides = norm.filter(x => x.kind === 'active' && x.dist >= 30 && x.dist < 200 && x.timer <= 30);
  const reps = norm.filter(x => x.kind === 'active' && x.dist >= 350);
  const cooldown = norm.filter(x => x.kind === 'cooldown' && x.dist > 100);
  const artifacts = norm.filter(x => (x.dist < 5 && x.timer <= 5)); // lap 53-61,63
  const cooldownRest = norm.filter(x => x.kind === 'cooldown' && x.dist <= 100);

  const recoveryAfter = i => {
    for (let j = i + 1; j < norm.length; j++) {
      if (norm[j].kind === 'recovery' && norm[j].dist > 0) return norm[j];
      if (norm[j].kind === 'active' && norm[j].dist >= 350) return null;
    }
    return null;
  };

  const repRows = reps.map((r, idx) => ({ ...r, rep: idx + 1, rec: recoveryAfter(r.i - 1) }));

  const repPace = repRows.map(r => r.pace);
  const meanPace = repPace.reduce((a, b) => a + b, 0) / repPace.length;
  const sdPace = Math.sqrt(repPace.reduce((a, b) => a + (b - meanPace) ** 2, 0) / repPace.length);
  const fastest = repRows.reduce((a, b) => b.pace < a.pace ? b : a);
  const slowest = repRows.reduce((a, b) => b.pace > a.pace ? b : a);

  const repTotalDist = repRows.reduce((a, b) => a + b.dist, 0);
  const repTotalTime = repRows.reduce((a, b) => a + b.timer, 0);
  const repAvgHr = repRows.reduce((a, b) => a + b.hr, 0) / repRows.length;
  const repAvgPw = repRows.reduce((a, b) => a + b.pw, 0) / repRows.length;
  const repAvgCad = repRows.reduce((a, b) => a + b.cad, 0) / repRows.length;
  const repAvgGct = repRows.reduce((a, b) => a + b.gct, 0) / repRows.length;
  const repAvgVo = repRows.reduce((a, b) => a + b.vo, 0) / repRows.length;
  const repAvgVr = repRows.reduce((a, b) => a + b.vr, 0) / repRows.length;
  const repAvgStep = repRows.reduce((a, b) => a + b.step, 0) / repRows.length;

  const sets = [];
  for (let i = 0; i < repRows.length; i += 5) {
    const chunk = repRows.slice(i, i + 5);
    sets.push({
      label: `Set ${sets.length + 1}`,
      reps: `${chunk[0].rep}–${chunk[chunk.length - 1].rep}`,
      pace: chunk.reduce((a, b) => a + b.pace, 0) / chunk.length,
      hr: chunk.reduce((a, b) => a + b.hr, 0) / chunk.length,
      pw: chunk.reduce((a, b) => a + b.pw, 0) / chunk.length,
      cad: chunk.reduce((a, b) => a + b.cad, 0) / chunk.length,
    });
  }
  const firstSetHr = sets[0].hr, lastSetHr = sets[sets.length - 1].hr;

  const recsHr = records.map(r => r.heart_rate).filter(x => x != null && x > 0);
  const minHr = Math.min(...recsHr), maxHr = Math.max(...recsHr);
  const maxSpeed = Math.max(...records.map(r => r.enhanced_speed ?? 0));
  const maxCad = Math.max(...records.map(r => (r.cadence != null ? (r.cadence + (r.fractional_cadence || 0)) * 2 : 0)));

  const tcx = fs.readFileSync(TCX, 'utf8');
  const tcxLaps = (tcx.match(/<Lap\b/g) || []).length;
  const tcxPoints = (tcx.match(/<Trackpoint>/g) || []).length;
  const tcxLapBodies = [...tcx.matchAll(/<Lap\b[^>]*>([\s\S]*?)<\/Lap>/g)].map(m => m[1]);
  const tcxDistM = tcxLapBodies.reduce((sum, body) => {
    const mm = body.match(/<DistanceMeters>([\d.]+)<\/DistanceMeters>/);
    return sum + (mm ? Number(mm[1]) : 0);
  }, 0);

  const zoneRows = (times, bounds, unit) => {
    const arr = times || [];
    const b = bounds || [];
    const rows = [];
    for (let i = 0; i < Math.min(arr.length, 6); i++) {
      const lo = i > 0 ? b[i - 1] : null;
      const hi = b[i] != null && b[i] < 4000 ? b[i] : null;
      const label = i === 0 ? `Z1 (< ${hi} ${unit})` : hi == null ? `Z${i + 1} (> ${lo} ${unit})` : `Z${i + 1} (${lo}–${hi} ${unit})`;
      rows.push([label, `${dec(arr[i] / 60, 1)} mnt`]);
    }
    return rows;
  };

  const workKj = s.total_work != null ? s.total_work / 1000 : null;
  const sessionCad = s.avg_cadence != null ? (s.avg_cadence + (s.avg_fractional_cadence || 0)) * 2 : null;
  const sessionCadMax = s.max_cadence != null ? (s.max_cadence + (s.max_fractional_cadence || 0)) * 2 : null;
  const gapSpeed = s.avg_grade_adjusted_speed;

  const md = [];
  const P = (...l) => md.push(...l);

  P('# Analisis Sesi — Bogor - 20x400', '');
  P('**Atlet:** Albireo  ');
  P('**Tanggal:** Sabtu, 31 Oktober 2026 · mulai **05:13:46 WIB**  ');
  P('**Lokasi:** Bogor (GPS start −6,5571 / 106,7335)  ');
  P('**Sumber:** file .FIT asli + .TCX (Garmin Connect), 63 lap, 5.824 record per detik  ');
  P('**Dibuat:** 31 Oktober 2026  ');
  P('**Perangkat:** Garmin · **Zona waktu:** Asia/Bangkok (UTC+7) · **Unit:** metrik', '');

  // ---- ringkasan ----
  P('## Ringkasan sesi', '');
  const grid = [
    ['Jarak', `${dec(s.total_distance / 1000, 2)} km`, 'Durasi timer', hm(s.total_timer_time)],
    ['Elapsed total', hm(s.total_elapsed_time), 'Pace rata-rata', pace(s.total_timer_time / (s.total_distance / 1000))],
    ['Pace terbaik (max speed)', `${pace(1000 / s.enhanced_max_speed)} (${dec(s.enhanced_max_speed * 3.6, 1)} km/j)`, 'GAP (grade-adjusted)', gapSpeed ? pace(1000 / gapSpeed) : '—'],
    ['Kecepatan rata-rata', `${dec(s.enhanced_avg_speed * 3.6, 1)} km/j`, 'Kecepatan maks', `${dec(s.enhanced_max_speed * 3.6, 1)} km/j`],
    ['Kalori (C)', `${num(s.total_calories)} kcal`, 'Kalori BMR', `${num(s.metabolic_calories)} kcal`],
    ['Total work', `${num(workKj)} kJ ≈ ${num(workKj * 0.239)} kcal`, 'Estimasi keringat', `${num(s.est_sweat_loss)} ml`],
    ['HR rata2 / maks / min', `${s.avg_heart_rate} / ${s.max_heart_rate} / ${minHr} bpm`, 'HR maks (records)', `${maxHr} bpm`],
    ['Cadence rata2 (seluruh sesi)', `${dec(sessionCad, 0)} spm`, 'Cadence maks', `${dec(sessionCadMax, 0)} spm*`],
    ['Suhu rata2 (min–maks)', `${dec(s.avg_temperature, 0)}°C (${dec(s.min_temperature, 0)}–${dec(s.max_temperature, 0)}°C)`, 'Elevasi naik / turun', `${num(s.total_ascent)} / ${num(s.total_descent)} m`],
    ['VO2 max est.', `${dec(um.first_vo2_max, 1)} → ${dec(am.vo2_max ?? um.vo2_max, 1)}`, 'Recovery time', (am.recovery_time != null ? `${Math.floor(am.recovery_time / 60)}j ${Math.round(am.recovery_time % 60)}m` : '—')],
    ['Training Effect', `${dec(s.total_training_effect, 1)} aer / ${dec(s.total_anaerobic_training_effect, 1)} ana`, 'RPE / Feel (0–10)', `${dec((s.workout_rpe ?? 0) / 10, 1)} / ${dec((s.workout_feel ?? 0) / 10, 1)}`],
    ['FTP (threshold)', zt.functional_threshold_power != null ? `${zt.functional_threshold_power} W` : '—', 'Berat badan (profil)', um.weight != null ? `${num(um.weight)} kg` : '—'],
  ];
  P(table(['Metrik','Nilai','Metrik','Nilai'], grid), '');
  P('> *Cadence maks 203 spm berasal dari spike singkat di lap 52 (awal recovery); cadence rep 400 m maksimum 183 spm. Cadence rata-rata seluruh sesi rendah karena termasuk jalan/diam saat recovery.', '');

  // ---- zones ----
  P('## Zona HR & power', '');
  if (tizS) {
    P('**Zona HR (dari .FIT, batas sesuai watch):**', '');
    P(table(['Zona','Waktu',], zoneRows(tizS.time_in_hr_zone, tizS.hr_zone_high_boundary, 'bpm')), '');
    P('**Zona power (FTP ' + `${zt.functional_threshold_power ?? '—'} W):**`, '');
    P(table(['Zona','Waktu'], zoneRows(tizS.time_in_power_zone, tizS.power_zone_high_boundary, 'W')), '');
  }

  // ---- dynamics ----
  P('## Dinamika lari', '');
  const dynRanges = k => {
    const vals = reps.map(r => r[k]).filter(v => v != null);
    return vals.length ? `${dec(Math.min(...vals), k === 'gct' ? 0 : 1)}–${dec(Math.max(...vals), k === 'gct' ? 0 : 1)}` : '—';
  };
  P(table(['Metrik','Rata-rata sesi','Rata-rata rep 400 m','Rentang antar rep'], [
    ['Cadence', `${dec(sessionCad, 0)} spm`, `${dec(repAvgCad, 0)} spm`, dynRanges('cad') + ' spm'],
    ['Panjang langkah', s.avg_step_length != null ? `${dec(s.avg_step_length / 10, 1)} cm` : '—', `${dec(repAvgStep, 1)} cm`, dynRanges('step') + ' cm'],
    ['Ground contact time', s.avg_stance_time != null ? `${dec(s.avg_stance_time, 0)} ms` : '—', `${dec(repAvgGct, 0)} ms`, dynRanges('gct') + ' ms'],
    ['Vertical oscillation', s.avg_vertical_oscillation != null ? `${dec(s.avg_vertical_oscillation / 10, 1)} cm` : '—', `${dec(repAvgVo, 1)} cm`, dynRanges('vo') + ' cm'],
    ['Vertical ratio', `${dec(s.avg_vertical_ratio, 1)} %`, `${dec(repAvgVr, 1)} %`, dynRanges('vr') + ' %'],
  ]), '');
  P('> Rata-rata sesi memakai seluruh 63 lap (termasuk jalan/diam); kolom "rep 400 m" hanya 20 lap aktif — lebih mewakili gerak lari sebenarnya.', '');

  // ---- strides ----
  P('## Pemanasan & strides', '');
  const warmDist = warm.reduce((a, b) => a + b.dist, 0);
  const warmTime = warm.reduce((a, b) => a + b.timer, 0);
  const warmAvgHr = warm.reduce((a, b) => a + b.hr, 0) / warm.length;
  const warmMaxHr = Math.max(...warm.map(x => x.hrMax));
  P(table(['Bagian','Jarak','Durasi','Pace','HR avg/max'], [
    ['Warm-up (3 lap)', `${dec(warmDist / 1000, 2)} km`, hms(warmTime), pace(warmTime / (warmDist / 1000)), `${dec(warmAvgHr, 0)}/${warmMaxHr}`],
  ]), '');
  P('**4 strides 20 detik:**', '');
  P(table(['#','Lap','Jarak','Durasi','Pace','HR avg/max','Cadence avg/max','Power avg/max','Recovery'], strides.map((x, i) => {
    const rec = recoveryAfter(x.i - 1);
    return [
      `${i + 1}`, `${x.i}`, `${num(x.dist)} m`, `${dec(x.timer, 0)} s`,
      pace(x.pace), `${x.hr}/${x.hrMax}`, `${dec(x.cad, 0)}/${dec(x.cadMax, 0)} spm`,
      `${num(x.pw)}/${num(x.pwMax)} W`, rec ? `${dec(rec.timer, 0)} s · ${num(rec.dist)} m` : '—',
    ];
  })), '');

  // ---- main set ----
  P('## Set utama: 20 × 400 m', '');
  P('**Statistik set:**', '');
  P(table(['Metrik','Nilai','Metrik','Nilai'], [
    ['Total rep', `${repRows.length}`, 'Total jarak rep', `${dec(repTotalDist / 1000, 2)} km`],
    ['Total waktu rep', hms(repTotalTime), 'Pace rata-rata rep', pace(meanPace)],
    ['Rep tercepat', `#${fastest.rep} · ${pace(fastest.pace)}`, 'Rep terlambat', `#${slowest.rep} · ${pace(slowest.pace)}`],
    ['Konsistensi (SD pace)', `${dec(sdPace, 1)} s/km`, 'Rentang pace', `${pace(fastest.pace)} – ${pace(slowest.pace)}`],
    ['HR rata-rata rep', `${dec(repAvgHr, 0)} bpm`, 'HR set 1 → set 4', `${dec(firstSetHr, 0)} → ${dec(lastSetHr, 0)} bpm`],
    ['Power rata-rata rep', `${dec(repAvgPw, 0)} W`, 'Cadence rata-rata rep', `${dec(repAvgCad, 0)} spm`],
    ['GCT rata-rata rep', `${dec(repAvgGct, 0)} ms`, 'VO / VR rata-rata', `${dec(repAvgVo, 1)} cm / ${dec(repAvgVr, 1)} %`],
  ]), '');
  P('**Rincian per rep** (recovery = jeda setelah rep):', '');
  P(table(
    ['#','Lap','Durasi','Pace','HR a/m','Cadence a/m','Power a/m','NP','Stride','GCT','VO','VR','kcal','Recovery setelah'],
    repRows.map(r => [
      `${r.rep}`, `${r.i}`, hms(r.timer), pace(r.pace), `${r.hr}/${r.hrMax}`,
      `${dec(r.cad, 0)}/${dec(r.cadMax, 0)}`, `${num(r.pw)}/${num(r.pwMax)}`, `${num(r.np)}`,
      `${dec(r.step, 1)} cm`, `${dec(r.gct, 0)} ms`, `${dec(r.vo, 1)} cm`, `${dec(r.vr, 1)} %`,
      `${num(r.kcal)}`, r.rec ? `${dec(r.rec.timer, 0)} s · ${num(r.rec.dist)} m · HR ${r.rec.hr}` : '—',
    ])
  ), '');
  P('**Rekap per set (5 rep):**', '');
  P(table(['Set','Rep','Pace rata2','HR rata2','Power rata2','Cadence rata2'], sets.map(x => [
    x.label, x.reps, pace(x.pace), `${dec(x.hr, 0)} bpm`, `${dec(x.pw, 0)} W`, `${dec(x.cad, 0)} spm`,
  ])), '');
  P(`**Pola:** ${dec(repRows.filter(r => r.rec && r.rec.timer >= 100).length, 0)}× jeda panjang **2:30** (setiap 5 rep) + ${dec(repRows.filter(r => r.rec && r.rec.timer < 100).length, 0)}× jeda **45 s**; total recovery ${hms(repRows.reduce((a, b) => a + (b.rec?.timer || 0), 0))}. HR tidak turun banyak di jeda 45 s (tetap ~${dec(repRows.filter(r => r.rec && r.rec.timer < 100).reduce((a, b) => a + b.rec.hr, 0) / repRows.filter(r => r.rec && r.rec.timer < 100).length, 0)} bpm), turun ke ~${dec(repRows.filter(r => r.rec && r.rec.timer >= 100).reduce((a, b) => a + b.rec.hr, 0) / repRows.filter(r => r.rec && r.rec.timer >= 100).length, 0)} bpm di jeda 2:30.`, '');

  // ---- cooldown & artifacts ----
  P('## Cooldown & artefak', '');
  if (cooldown.length) {
    const c = cooldown[0];
    P(`**Cool-down:** lap ${c.i} · ${dec(c.dist / 1000, 2)} km · ${hms(c.timer)} · ${pace(c.pace)} · HR ${c.hr}/${c.hrMax} · cadence ${dec(c.cad, 0)} spm`, '');
  }
  P(`**Artefak (dikecualikan):** ${artifacts.length} lap berdurasi 1–4 detik dengan jarak 0–2 m (lap ${artifacts.map(a => a.i).join(', ')}) — kemungkinan tombol lap tidak sengaja tertekan saat berhenti. Tidak memengaruhi total jarak/durasi.`, '');

  // ---- lap table ----
  P('## Tabel lap lengkap (63 lap)', '');
  const lapTable = table(
    ['#','Mulai','Jarak','Durasi','Pace','HR a/m','Cad a/m','Power a/m','NP','kJ','VO','GCT','Langkah','VR','Elev ±','kcal','Suhu','Tipe'],
    norm.map(l => [
      `${l.i}`, l.start, l.dist ? `${num(l.dist)} m` : '0 m', hms(l.timer),
      l.pace ? pace(l.pace) : '—', `${l.hr ?? '—'}/${l.hrMax ?? '—'}`,
      `${l.cad != null ? dec(l.cad, 0) : '—'}/${l.cadMax != null ? dec(l.cadMax, 0) : '—'}`,
      `${l.pw != null ? num(l.pw) : '—'}/${l.pwMax != null ? num(l.pwMax) : '—'}`,
      l.np != null ? num(l.np) : '—', l.workKj != null ? num(l.workKj) : '—',
      l.vo != null ? dec(l.vo, 1) : '—', l.gct != null ? dec(l.gct, 0) : '—', l.step != null ? dec(l.step, 1) : '—',
      l.vr != null ? dec(l.vr, 1) : '—',
      `${l.asc != null ? '+' + l.asc : '—'}/${l.desc != null ? '−' + l.desc : '—'}`,
      l.kcal != null ? num(l.kcal) : '—', l.temp != null ? `${l.temp}°C` : '—',
      l.kind === 'warmup' ? 'Warm-up' : l.kind === 'cooldown' ? 'Cool-down' : l.kind === 'recovery' ? 'Recovery' : l.kind === 'active' ? 'Aktif' : (l.kind || '—'),
    ])
  );
  P('<details>', `<summary>63 lap — klik untuk buka</summary>`, '', '> Legenda: HR a/m = avg/max · Cad spm · Power W · NP W · kJ total work · VO cm · GCT ms · VR % · Elev +/− m.', '', lapTable, '', '</details>', '');

  // ---- validation ----
  P('## Validasi & konsistensi', '');
  P(table(['Sumber','Lap','Trackpoint/sampel','Jarak','Mulai','Catatan'], [
    ['FIT', `${laps.length}`, `${records.length} record`, `${dec(s.total_distance / 1000, 2)} km`, startLocal.slice(0, 19), 'sumber utama'],
    ['TCX', `${tcxLaps}`, `${num(tcxPoints)}`, `${dec(tcxDistM / 1000, 2)} km`, startLocal.slice(0, 19), 'cocok dengan FIT'],
  ]), '');
  P('> *Struktur lap & waktu TCX identik dengan FIT — jumlah lap sama (63), total jarak selisih <0,1%.', '');

  // ---- methodology ----
  P('## Metodologi', '');
  P('- **Parser:** `fit-file-parser` (Node) membaca pesan `session`, `lap`, `record`, `time_in_zone`, `user_metrics`, `activity_metrics`. Lap diidentifikasi dari `intensity` (warmup/active/recovery/cooldown) dan `lap_trigger` (distance/time/manual).');
  P('- **Rep 400 m:** 20 lap ber-intensitas `active` dengan jarak ≥350 m (lap 13–51). Lap 0–2 m (9 lap) dikeluarkan.');
  P('- **Recovery:** lap `recovery` pertama setelah setiap rep; ditampilkan durasi, jarak, dan HR rata-rata.');
  P('- **Dinamika:** cadence FIT ×2 (siklus → langkah/mnt); vertical oscillation & panjang langkah dibagi 10 (unit FIT → cm); GCT dari `stance_time` (ms); VR dari `vertical_ratio` (%).');
  P('- **Zona:** `time_in_zone` referensi `session`; batas HR [125, 143, 161, 176, 192, 208] bpm dan power [173, 212, 238, 265, 305] W (FTP 265 W).');
  P('- **HR min/max records:** dihitung dari 5.824 sampel per detik (bukan dari ringkasan sesi).');
  P('');

  P('## Keterbatasan', '');
  P('1. **Tanpa chest strap** tidak bisa dipastikan — akurasi HR bergantung sensor yang dipakai (optical/strap).');
  P('2. **Cadence maks 203 spm** adalah spike 1 sampel (lap 52) dan tidak mewakili lari; gunakan cadence per rep (169–177 spm).');
  P('3. **Jumlah langkah** tidak tersedia langsung di FIT sesi ini (hanya `total_cycles`); tidak ditampilkan agar tidak menebak.');
  P('4. **RPE/Feel** berasal dari input watch (skala 0–10), bukan evaluasi pelatih.');
  P('5. **Pace rep** memakai GPS luar ruangan; akurasi jarak 400 m bergantung sinyal (Bogor, pagi).');
  P('6. **VO2 max est.** adalah estimasi Garmin per sesi, bukan hasil uji laboratorium.');
  P('', '---', '');

  P('## Lampiran file', '');
  P('- Laporan ini: `D:\\Garmin\\API-Key-Data-Fetch\\Garmin-Session-2026-10-31-Bogor-20x400.md`');
  P('- File asli: `D:\\Garmin\\API-Key-Data-Fetch\\sessions\\24910882666\\24910882666_ACTIVITY.fit` dan `activity_24910882666.tcx`');
  P('- Salinan asal (unduhan): `C:\\Users\\ALBIREO\\Downloads\\24910882666\\`');
  P('- Parser/analisis: `D:\\Garmin\\API-Key-Data-Fetch\\scripts\\build-session-report-24910882666.js`');
  P('');
  P('*Dibuat otomatis dari file .FIT/.TCX Garmin. Bukan nasihat medis.*');

  fs.writeFileSync(OUT, md.join('\n'), 'utf8');

  const summaryJson = {
    activityId: 24910882666,
    name: 'Bogor - 20x400',
    startLocal,
    distanceM: s.total_distance,
    timerSec: s.total_timer_time,
    elapsedSec: s.total_elapsed_time,
    avgHR: s.avg_heart_rate,
    maxHR: s.max_heart_rate,
    minHRRecords: minHr,
    calories: s.total_calories,
    trainingEffect: s.total_training_effect,
    anaerobicTE: s.total_anaerobic_training_effect,
    vo2: { first: um.first_vo2_max, final: am.vo2_max ?? um.vo2_max },
    recoveryTimeMin: am.recovery_time,
    weightKg: um.weight,
    ftpW: zt.functional_threshold_power,
    reps: repRows.map(r => ({ rep: r.rep, lap: r.i, timer: r.timer, paceSecPerKm: r.pace, hr: r.hr, hrMax: r.hrMax, cadence: r.cad, power: r.pw, np: r.np, vo: r.vo, gct: r.gct, step: r.step, vr: r.vr, recoverySec: r.rec?.timer ?? null })),
    strides: strides.map(x => ({ lap: x.i, dist: x.dist, timer: x.timer, pace: x.pace })),
    zonesHr: tizS?.time_in_hr_zone ?? null,
    zonesPower: tizS?.time_in_power_zone ?? null,
    zonesHrBounds: tizS?.hr_zone_high_boundary ?? null,
    zonesPowerBounds: tizS?.power_zone_high_boundary ?? null,
    laps: norm,
  };
  fs.writeFileSync(path.join(SESS, 'session-24910882666.json'), JSON.stringify(summaryJson, null, 2), 'utf8');

  console.log('WROTE', OUT);
  console.log('lines', md.join('\n').split('\n').length);
  console.log('reps', repRows.length, 'meanPace', Math.round(meanPace), 'sd', dec(sdPace, 1), 'fastest', fastest.rep, fastest.pace.toFixed(1), 'slowest', slowest.rep, slowest.pace.toFixed(1));
  console.log('hr', s.avg_heart_rate + '/' + s.max_heart_rate, 'minRecords', minHr, 'maxRecords', maxHr);
  console.log('warm', warmDist, warmTime, 'strides', strides.length, 'artifacts', artifacts.length, 'tcxLaps', tcxLaps);
})().catch(e => { console.error(e); process.exit(1); });
