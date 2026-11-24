const fs = require('fs');
const path = require('path');
const FitParser = require('./node_modules/fit-file-parser').default;

const FIT_DIR = 'D:/Garmin/API-Key-Data-Fetch/fit';
const OUT = path.join(FIT_DIR, 'fit-laps.json');

const files = [];
for (const entry of fs.readdirSync(FIT_DIR, { withFileTypes: true })) {
  if (!entry.isDirectory()) continue;
  const dir = path.join(FIT_DIR, entry.name);
  for (const f of fs.readdirSync(dir)) {
    if (f.toLowerCase().endsWith('.fit')) files.push({ id: entry.name, file: path.join(dir, f) });
  }
}

function parseFile(file) {
  return new Promise((resolve, reject) => {
    const parser = new FitParser({ force: true, speedUnit: 'm/s', lengthUnit: 'm', temperatureUnit: 'C' });
    parser.parse(fs.readFileSync(file), (err, data) => err ? reject(err) : resolve(data));
  });
}

(async () => {
  const out = {};
  for (const { id, file } of files) {
    const data = await parseFile(file);
    const s = (data.sessions || [])[0] || {};
    const laps = (data.laps || []).map((l, i) => {
      return {
        i: i + 1,
        startUtc: l.start_time ? new Date(l.start_time).toISOString() : null,
        timerSec: l.total_timer_time ?? null,
        elapsedSec: l.total_elapsed_time ?? null,
        distanceM: l.total_distance ?? null,
        paceSecPerKm: (l.total_distance >= 50 && l.total_timer_time) ? l.total_timer_time / (l.total_distance / 1000) : null,
        avgSpeedMs: l.enhanced_avg_speed ?? null,
        maxSpeedMs: l.enhanced_max_speed ?? null,
        avgHR: l.avg_heart_rate ?? null,
        maxHR: l.max_heart_rate ?? null,
        cadenceSpm: l.avg_cadence != null ? Math.round((l.avg_cadence + (l.avg_fractional_cadence || 0)) * 2) : null,
        maxCadenceSpm: l.max_cadence != null ? Math.round((l.max_cadence + (l.max_fractional_cadence || 0)) * 2) : null,
        ascent: l.total_ascent ?? null,
        descent: l.total_descent ?? null,
        avgPower: l.avg_power ?? null,
        maxPower: l.max_power ?? null,
        normPower: l.normalized_power ?? null,
        totalWorkKj: l.total_work != null ? l.total_work / 1000 : null,
        calories: l.total_calories ?? null,
        metabolicCal: l.metabolic_calories ?? null,
        intensity: l.intensity ?? null,
        trigger: l.lap_trigger ?? null,
        avgTemp: l.avg_temperature != null ? Math.round(l.avg_temperature) : null,
        minTemp: l.min_temperature != null ? Math.round(l.min_temperature) : null,
        maxTemp: l.max_temperature != null ? Math.round(l.max_temperature) : null,
        // dinamika lari per lap (parser tidak konversi -> VO & step dalam mm, stance ms, VR %)
        avgVOcm: l.avg_vertical_oscillation != null ? l.avg_vertical_oscillation / 10 : null,
        avgGctMs: l.avg_stance_time ?? null,
        avgStepCm: l.avg_step_length != null ? l.avg_step_length / 10 : null,
        avgVR: l.avg_vertical_ratio ?? null,
      };
    });

    const runLaps = laps.filter(l => l.avgVOcm != null || l.avgGctMs != null);
    const rangeOf = (k) => {
      const vals = runLaps.map(l => l[k]).filter(v => v != null);
      return vals.length ? { min: Math.min(...vals), max: Math.max(...vals) } : null;
    };

    const tizArr = data.time_in_zone || [];
    const tizS = tizArr.find(t => t.reference_mesg === 'session');
    const ztRaw = data.zones_target;
    const zt = Array.isArray(ztRaw) ? ztRaw[0] : (ztRaw || {});
    const umRaw = data.user_metrics;
    const um = Array.isArray(umRaw) ? umRaw[0] : (umRaw || {});
    const amRaw = data.activity_metrics;
    const am = Array.isArray(amRaw) ? amRaw[0] : (amRaw || {});

    out[id] = {
      file: path.basename(file),
      sport: s.sport ?? null,
      subSport: s.sub_sport ?? null,
      athlete: um.weight != null ? {
        weightKg: um.weight,
        heightM: um.height ?? null,
        age: um.age ?? null,
        gender: um.gender ?? null,
        maxHR: um.max_heart_rate ?? null,
      } : null,
      ftp: zt.functional_threshold_power ?? null,
      vo2Max: um.vo2_max != null || am.vo2_max != null ? {
        first: um.first_vo2_max ?? null,
        final: (am.vo2_max != null && am.vo2_max > 0) ? am.vo2_max : (um.vo2_max ?? null),
      } : null,
      recoveryTimeMin: am.recovery_time ?? null,
      hrZones: tizS?.time_in_hr_zone ? { bounds: tizS.hr_zone_high_boundary, sec: tizS.time_in_hr_zone } : null,
      pwrZones: (tizS?.time_in_power_zone && (tizS.power_zone_high_boundary || []).some(b => b != null)) ? { bounds: tizS.power_zone_high_boundary, sec: tizS.time_in_power_zone } : null,
      splitSummaries: (data.split_summaries || []).map(x => ({
        type: x.split_type ?? null,
        distanceM: x.total_distance ?? null,
        timerSec: x.total_timer_time ?? null,
        paceSecPerKm: (x.total_distance >= 50 && x.total_timer_time) ? x.total_timer_time / (x.total_distance / 1000) : null,
        avgHR: x.avg_heart_rate ?? null,
        maxHR: x.max_heart_rate ?? null,
        maxSpeed: x.max_speed ?? null,
        avgVertSpeed: x.avg_vert_speed ?? null,
        calories: x.total_calories ?? null,
        ascent: x.total_ascent ?? null,
        descent: x.total_descent ?? null,
        numSplits: x.num_splits ?? null,
      })),
      session: {
        startUtc: s.start_time ? new Date(s.start_time).toISOString() : null,
        timerSec: s.total_timer_time ?? null,
        elapsedSec: s.total_elapsed_time ?? null,
        distanceM: s.total_distance ?? null,
        avgHR: s.avg_heart_rate ?? null,
        maxHR: s.max_heart_rate ?? null,
        calories: s.total_calories ?? null,
        metabolicCalories: s.metabolic_calories ?? null,
        trainingEffect: s.total_training_effect ?? null,
        anaerobicTrainingEffect: s.total_anaerobic_training_effect ?? null,
        primaryBenefit: s.primary_benefit ?? null,
        workoutFeel: s.workout_feel ?? null,
        workoutRpe: s.workout_rpe != null ? s.workout_rpe / 10 : null,
        ascent: s.total_ascent ?? null,
        descent: s.total_descent ?? null,
        numLaps: s.num_laps ?? null,
        avgPower: s.avg_power ?? null,
        maxPower: s.max_power ?? null,
        normPower: s.normalized_power ?? null,
        totalWorkKj: s.total_work != null ? s.total_work / 1000 : null,
        avgCadenceSpm: s.avg_cadence != null ? (s.avg_cadence + (s.avg_fractional_cadence || 0)) * 2 : null,
        maxCadenceSpm: s.max_cadence != null ? (s.max_cadence + (s.max_fractional_cadence || 0)) * 2 : null,
        avgVOcm: s.avg_vertical_oscillation != null ? s.avg_vertical_oscillation / 10 : null,
        avgGctMs: s.avg_stance_time ?? null,
        avgVR: s.avg_vertical_ratio ?? null,
        avgStepCm: s.avg_step_length != null ? s.avg_step_length / 10 : null,
        estSweatLoss: s.est_sweat_loss ?? null,
        avgGradeAdjSpeed: s.avg_grade_adjusted_speed ?? null,
        avgTemp: s.avg_temperature != null ? Math.round(s.avg_temperature) : null,
        maxTemp: s.max_temperature != null ? Math.round(s.max_temperature) : null,
        minTemp: s.min_temperature != null ? Math.round(s.min_temperature) : null,
      },
      dynRange: {
        voCm: rangeOf('avgVOcm'),
        gctMs: rangeOf('avgGctMs'),
        stepCm: runLaps.length ? {
          min: Math.min(...runLaps.map(l => l.avgStepCm).filter(v => v != null)),
          max: Math.max(...runLaps.map(l => l.avgStepCm).filter(v => v != null)),
        } : null,
        vr: rangeOf('avgVR'),
        cadenceSpm: rangeOf('cadenceSpm'),
      },
      laps,
    };
    console.log(`${id}: ${laps.length} laps, ${data.records?.length || 0} records, ${s.sport}/${s.sub_sport}`);
  }
  fs.writeFileSync(OUT, JSON.stringify(out, null, 2), 'utf8');
  console.log('WROTE', OUT);
})().catch(e => { console.error(e); process.exit(1); });
