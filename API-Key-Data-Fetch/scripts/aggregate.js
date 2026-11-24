const fs = require('fs');
const dir = 'D:/Garmin/API-Key-Data-Fetch/data/';
const read = f => JSON.parse(fs.readFileSync(dir + f, 'utf8').replace(/^\uFEFF/, ''));

const v2 = read('daily-summaries-v2.json').data;
const sleep = read('sleep-summaries.json');
const hrv = read('hrv-daily.json').hrvSummaries;
const acts = read('activities.json');
const wellness = read('wellness-activities.json');

const sleepByDate = Object.fromEntries(sleep.map(s => [s.calendarDate, s]));
const hrvByDate = Object.fromEntries(hrv.map(h => [h.calendarDate, h]));

const round = (n, d = 0) => n == null ? null : Number(Number(n).toFixed(d));
const mins = s => s == null ? null : round(s / 60, 0);
const km = m => m == null ? null : round(m / 1000, 2);
const dow = d => new Date(d + 'T12:00:00').toLocaleDateString('en-US', { weekday: 'short' });

const rows = v2.map(d => {
  const s = sleepByDate[d.calendarDate] || {};
  const h = hrvByDate[d.calendarDate] || {};
  const dayActs = acts.filter(a => a.startTimeLocal.startsWith(d.calendarDate));
  return {
    date: d.calendarDate,
    dow: dow(d.calendarDate),
    steps: d.movement?.steps?.value ?? null,
    stepGoal: d.movement?.steps?.goal ?? null,
    distKm: km(d.movement?.steps?.distanceInMeters),
    floorsUp: d.movement?.floorsAscended?.value ?? null,
    floorsDown: d.movement?.floorsDescended?.value ?? null,
    calTotal: d.calories?.burnedTotal ?? null,
    calActive: d.calories?.burnedActive ?? null,
    calResting: d.calories?.burnedResting ?? null,
    calConsumed: d.calories?.consumedValue ?? null,
    hrMin: d.heartRate?.minValue ?? null,
    hrMax: d.heartRate?.maxValue ?? null,
    hrRest: d.heartRate?.restingValue ?? null,
    modMin: d.intensityMinutes?.moderate ?? null,
    vigMin: d.intensityMinutes?.vigorous ?? null,
    stressAvg: d.stress?.avgLevel ?? null,
    stressMax: d.stress?.maxLevel ?? null,
    stressQual: d.stress?.qualifier ?? null,
    bbMin: d.bodyBattery?.minValue ?? null,
    bbMax: d.bodyBattery?.maxValue ?? null,
    bbCharged: d.bodyBattery?.chargedValue ?? null,
    bbDrained: d.bodyBattery?.drainedValue ?? null,
    bbLatest: d.bodyBattery?.latestValue ?? null,
    respAvg: d.respiration?.avgValue ?? null,
    respMin: d.respiration?.minValue ?? null,
    respMax: d.respiration?.maxValue ?? null,
    spo2Avg: d.pulseOx?.avgValue ?? null,
    spo2Min: d.pulseOx?.minValue ?? null,
    hydration: d.hydration?.consumedInFractionalMl ?? null,
    hydrationGoal: d.hydration?.goalInMl ?? null,
    sleepMin: mins(s.sleepTimeSeconds),
    deepMin: mins(s.deepSleepSeconds),
    lightMin: mins(s.lightSleepSeconds),
    remMin: mins(s.remSleepSeconds),
    awakeMin: mins(s.awakeSleepSeconds),
    sleepScore: s.sleepScores?.overall?.value ?? null,
    sleepHR: s.avgHeartRate ?? null,
    sleepStress: s.avgSleepStress ?? null,
    sleepSpo2: s.averageSpO2Value ?? null,
    awakeCount: s.awakeCount ?? null,
    hrvLast: h.lastNightAvg ?? null,
    hrvWeekly: h.weeklyAvg ?? null,
    hrvStatus: h.status ?? null,
    actCount: dayActs.length,
    actKm: km(dayActs.reduce((x, a) => x + (a.distance || 0), 0)),
    actMin: round(dayActs.reduce((x, a) => x + (a.duration || 0), 0) / 60, 0),
    actCal: dayActs.reduce((x, a) => x + (a.calories || 0), 0),
  };
});

const sum = k => rows.reduce((x, r) => x + (r[k] || 0), 0);
const avg = k => { const v = rows.map(r => r[k]).filter(x => x != null); return v.length ? round(v.reduce((a, b) => a + b, 0) / v.length, 1) : null; };

const totals = {
  days: rows.length,
  stepsTotal: sum('steps'),
  stepsAvg: avg('steps'),
  stepsGoalHit: rows.filter(r => r.steps >= r.stepGoal).length,
  distKm: round(sum('distKm'), 1),
  calTotal: sum('calTotal'),
  calActive: sum('calActive'),
  calResting: sum('calResting'),
  hrRestAvg: avg('hrRest'),
  hrMax: Math.max(...rows.map(r => r.hrMax || 0)),
  modMin: sum('modMin'),
  vigMin: sum('vigMin'),
  stressAvg: avg('stressAvg'),
  stressMax: Math.max(...rows.map(r => r.stressMax || 0)),
  bbMinLowest: Math.min(...rows.map(r => r.bbMin ?? 999)),
  bbMaxHighest: Math.max(...rows.map(r => r.bbMax || 0)),
  respAvg: avg('respAvg'),
  spo2Avg: avg('spo2Avg'),
  spo2Min: Math.min(...rows.map(r => r.spo2Min ?? 999)),
  sleepAvgMin: avg('sleepMin'),
  sleepScoreAvg: avg('sleepScore'),
  sleepTotalMin: sum('sleepMin'),
  hrvAvg: avg('hrvLast'),
  actCount: acts.length,
  actKm: round(acts.reduce((x, a) => x + (a.distance || 0), 0) / 1000, 2),
  actMin: round(acts.reduce((x, a) => x + (a.duration || 0), 0) / 60, 0),
  actCal: acts.reduce((x, a) => x + (a.calories || 0), 0),
};

console.log(JSON.stringify({ rows, totals }, null, 1));
