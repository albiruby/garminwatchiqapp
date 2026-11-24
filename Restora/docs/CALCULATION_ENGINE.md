# RESTORA Calculation Engine

Sensor-independent analytics. Every session produces data the engine can analyse; Garmin sensor values only enrich it when available.

## Rules

1. **Source labels.** Every value is a `Metric` with a `source`:
   - `MEASURED` – read from a Garmin API (shown as "Garmin")
   - `CALCULATED` – derived by RESTORA (shown as "RESTORA calc")
   - `USER` – configured or entered by the user
2. **No fake data.** Missing or out-of-range input gives `null`, which the UI shows as `--`. Values are never estimated, clamped or back-filled.
3. **No health scores.** No "recovery quality", "lymphatic score" or "drainage efficiency". Metrics describe practice (time, frequency, consistency) and observed changes only.
4. **Pure functions.** `source/Calculation/*` never touches Storage, UI or sensors, so all of it is unit-tested (`source/Tests/CalculationTests.mc`).

## Data levels

| Level | Source | Examples |
|---|---|---|
| 1 | Garmin measured | HR before/after (optional setting, off by default) |
| 2 | RESTORA calculated | HR change, breathing cycles, practice volume, streak |
| 3 | User-configured | breathing patterns, planned sessions, countdown |

## Session record (Application.Storage)

`id, cat, start (UTC epoch s), dur (active s, without countdown/pause), plan, st (0 completed / 1 cancelled), done, skip, tot, cyc, t {tag: seconds}, hrB?, hrA?, hrAv?, hrMn?, hvS?, hvE?`

`hrAv`/`hrMn` are the mean and lowest Garmin HR samples taken once a second while the session runs. `hvS`/`hvE` are HRV values (below). All of them are absent, never zero, when the sensor gave nothing.

Tags: `br` breathing, `mi` meditation, `el` leg elevation, `an` ankle movement, `mv` gentle movement, `st` stretching, `rs` rest, `tr` transition, `L`/`R` side seconds.
History keeps the newest 100 records. A cancelled session shorter than 10 s is not saved.

## Metrics

All integer percentages are rounded: `(part*100 + whole/2) / whole`, and are `null` when `whole = 0`.
Days are **local** days: `dayIndex = (epoch + tzOffset) / 86400`.

### Heart rate (`HeartRateCalculator`)
| Metric | Formula | Null when |
|---|---|---|
| Observed HR change | `HR_before − HR_after` (85 → 74 = 11 bpm) | either reading missing or outside 25–250 |
| Average / min / max | over valid samples | no valid sample |

Shown as "observed HR change". It is not presented as proof of recovery.

### Breathing (`BreathingCalculator`)
| Metric | Formula |
|---|---|
| Cycle length | `inhale + hold + exhale + pause` (4-2-6-0 = 12 s) |
| Planned cycles | `floor(duration / cycle)` (300 / 12 = 25) |
| Completed cycles | `floor(elapsed_ms / cycle_ms)` per breathing step |
| Exhale/inhale ratio | `exhale / inhale` (4-6 = 1.5) |
| Average cycle | mean of consecutive cycle timestamps (≥ 2) |
| Cycle consistency | std-dev of cycle durations, ms (≥ 3 timestamps) |

### Movement & circulation (`MovementCalculator`, `CirculationCalculator`)
| Metric | Formula |
|---|---|
| Leg elevation time | `t.el` |
| Ankle movement time | `t.an` |
| Restorative position time | `t.el + t.rs` |
| Movement : rest ratio | `(t.an + t.mv + t.st) / (t.el + t.rs)`, null if no rest time |
| Left share | `L / (L + R) × 100` (50 = balanced) |
| Mobility volume | `Σ (t.st + t.mv)` in window |
| Circulation volume | `Σ dur` of CIRCULATE sessions in window |

Repetitions are not counted from wrist motion. The watch cannot see leg or hip movement.

### Sleep / wind-down (`SleepCalculator`)
| Metric | Formula |
|---|---|
| Wind-down time | `Σ dur` of SLEEP sessions |
| Evening sessions | sessions starting at local hour ≥ 18 |
| Evening consistency | days with an evening session / N days × 100 |

### Consistency (`ConsistencyCalculator`)
| Metric | Formula |
|---|---|
| Day streak | consecutive local days with ≥ 1 session, ending today, or ending yesterday if there is no session yet today |
| Completion rate | completed / all sessions × 100 |
| Session completion | completed exercises / total exercises × 100 |
| Routine consistency | completed planned / planned × 100 |
| Module share | module seconds / total seconds × 100 |
| Modules used | number of modules with > 0 s |

### Trends (`TrendCalculator`, `RecoveryCalculator`)
| Metric | Formula |
|---|---|
| Sessions, minutes | count, `round(Σ dur / 60)` |
| Average session | `round(Σ dur / count)` s |
| Sessions per week | `count × 7 / days` |
| Most used session | highest count; on a tie, the earliest in history |
| Personal baseline | mean of the last 14 days, needs ≥ 5 valid points, else null |
| vs baseline | `current − baseline` |
| Daily / weekly recovery minutes | practice minutes on the local day / last 7 local days |

## Heart rate and HRV (optional, Settings → HR & HRV, off by default)

- Capability detection: `SensorAvailability` (`Sensor.getInfo`, `Sensor.registerSensorDataListener`, `ActivityMonitor.getHeartRateHistory`). Settings shows what the watch supports.
- HR: Garmin measured. Before / after snapshots, plus mean and minimum during the session (`SessionSensors`).
- HRV: RMSSD in ms from Garmin beat-to-beat intervals (`HrvCalculator`). The intervals are measured; the RMSSD is a RESTORA calculation.
  - Cleaning: intervals outside 300–2000 ms are dropped, and so is any beat that differs more than 20 % from the previous one.
  - At least 30 clean beats or the value is null.
  - Sessions of 5 min or more store RMSSD for the first 2 min (`hvS`) and the last 2 min (`hvE`); shorter sessions store one value over the whole session (`hvE`).
  - Wrist-optical RR is noisier than a chest strap. Values are shown as a within-session comparison, not as a health score.

## Facade

`CalculationEngine.summarizeSession(record)` gives the metrics for the summary screen.
`CalculationEngine.summarizeWeek(history, now, tzOffset)` gives the dashboard for the 7 local days ending today.

## Planned (V1.1+)

Stress and Body Battery history (`SensorHistory` permission) after on-device validation on FR165. These will be added as `MEASURED` inputs only. Nothing here depends on them.
