const fs = require('fs');
const p = 'D:/Garmin/API-Key-Data-Fetch/data/daily-summaries-calories-2026-05-20_2026-11-20.json';
const d = JSON.parse(fs.readFileSync(p, 'utf8').replace(/^\uFEFF/, ''));
console.log('n=', d.length);
const sum = (a) => a.reduce((x, y) => x + y, 0);
const avg = (a) => a.length ? sum(a) / a.length : 0;
const round = (x, n = 1) => Math.round(x * 10 ** n) / 10 ** n;
const valid = d.filter(x => x.calories && x.calories.burnedTotal != null);
console.log('valid=', valid.length, 'first=', valid[0].calendarDate, 'last=', valid[valid.length - 1].calendarDate);
const total = valid.map(x => x.calories.burnedTotal);
const active = valid.map(x => x.calories.burnedActive || 0);
const rest = valid.map(x => x.calories.burnedResting || 0);
console.log('avg total', round(avg(total)), 'median', round([...total].sort((a,b)=>a-b)[Math.floor(total.length/2)]), 'min', Math.min(...total), 'max', Math.max(...total));
console.log('avg active', round(avg(active)), 'median', round([...active].sort((a,b)=>a-b)[Math.floor(active.length/2)]), 'max', Math.max(...active));
console.log('avg rest', round(avg(rest)), 'min', Math.min(...rest), 'max', Math.max(...rest));
console.log('total burned', sum(total), 'total active', sum(active), 'total rest', sum(rest));
console.log('zero active days', active.filter(x => x === 0).length, 'pct', round(active.filter(x => x === 0).length/active.length*100));
const months = {};
for (const x of valid) {
  const m = x.calendarDate.slice(0, 7);
  (months[m] ||= []).push(x);
}
for (const m of Object.keys(months).sort()) {
  const arr = months[m];
  console.log('MONTH', m, 'days', arr.length, 'avgTotal', round(avg(arr.map(x=>x.calories.burnedTotal))), 'avgActive', round(avg(arr.map(x=>x.calories.burnedActive||0))), 'avgRest', round(avg(arr.map(x=>x.calories.burnedResting||0))), 'activeSum', sum(arr.map(x=>x.calories.burnedActive||0)));
}
const top = [...valid].sort((a,b)=>(b.calories.burnedActive||0)-(a.calories.burnedActive||0)).slice(0,10);
console.log('TOP ACTIVE:');
for (const x of top) console.log(x.calendarDate, 'active', x.calories.burnedActive, 'rest', x.calories.burnedResting, 'total', x.calories.burnedTotal, 'steps', x.movement?.steps?.value, 'intenseMin', x.intensityMinutes?.totalMinutes);
const nonAct = valid.filter(x => !x.calories.burnedActive);
console.log('ZERO ACTIVE sample:', nonAct.slice(0,5).map(x=>({d:x.calendarDate,total:x.calories.burnedTotal,steps:x.movement?.steps?.value})));
const stepArr = valid.map(x => x.movement?.steps?.value).filter(x => x != null);
console.log('steps avg', round(avg(stepArr)), 'days', stepArr.length);
const im = valid.map(x => x.intensityMinutes?.totalMinutes).filter(x => x != null);
console.log('intensity avg', round(avg(im)), 'days', im.length);
// correlation active vs steps & intensity
function corr(a, b) {
  const n = Math.min(a.length, b.length);
  const ma = avg(a), mb = avg(b);
  let num=0, da=0, db=0;
  for (let i=0;i<n;i++){const x=a[i]-ma,y=b[i]-mb;num+=x*y;da+=x*x;db+=y*y;}
  return num/Math.sqrt(da*db);
}
const pairs = valid.filter(x => x.movement?.steps?.value != null && x.calories.burnedActive != null);
console.log('corr active-steps', round(corr(pairs.map(x=>x.calories.burnedActive), pairs.map(x=>x.movement.steps.value)),3));
const pairs2 = valid.filter(x => x.intensityMinutes?.totalMinutes != null && x.calories.burnedActive != null);
console.log('corr active-intensity', round(corr(pairs2.map(x=>x.calories.burnedActive), pairs2.map(x=>x.intensityMinutes.totalMinutes)),3));
