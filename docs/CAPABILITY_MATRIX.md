# PULSEFORM: API capability matrix (Forerunner 165)

Sources:
- Connect IQ SDK 9.3.0 (2026-10-20), installed at `%APPDATA%\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.3.0-…`.
  The per-API "Supported Devices" lists come from the SDK's `doc/Toybox/*.html`.
- The FR165 device profile: `Devices/fr165/compiler.json` and `fr165.api.debug.xml`.

Profile facts:
- Screen: 390×390, round, AMOLED, 16 bpp.
- CIQ level: 5.2.0.
- Watch face memory limit: 131,072 B.
- FR165 Music (`fr165m`) appears in the same supported-device lists as FR165 for every API used here.

Status meanings:
- **VERIFIED**: the API exists, FR165 is in its supported-device list, a watch face may call it, and it needs no permission.
- **CONDITIONAL**: the API is supported, but its value may be `null` (no sensor reading, no phone link, hardware variant) or it needs a permission.
- **UNSUPPORTED**: there is no API for this on FR165 or for watch faces.

All "watch face access" entries were checked against the SDK documentation and the device profile only.
**Real-device behaviour is not verified yet.** That happens in M08 on a physical FR165.

| Metric | API | Watch face access | FR165 support | Status | PULSEFORM handling |
|---|---|---|---|---|---|
| Steps | `ActivityMonitor.Info.steps` | Yes | Yes (all devices, API 1.0) | VERIFIED | Primary goal. If null, shows "--" and an empty track. |
| Step goal | `ActivityMonitor.Info.stepGoal` | Yes | Yes (API 1.0) | VERIFIED | Default target. The custom goal setting overrides it. |
| Distance | `ActivityMonitor.Info.distance` (cm) | Yes | Yes (API 1.0) | VERIFIED | Units follow `DeviceSettings.distanceUnits`. Target is optional. |
| Total calories | `ActivityMonitor.Info.calories` (kcal) | Yes | Yes (listed) | VERIFIED | Shown and labelled as **total** kcal (BMR included). |
| Active calories | none | n/a | No API | **UNSUPPORTED** | Not shown. Total minus estimated BMR would be made-up data. |
| Intensity min, day | `Info.activeMinutesDay.total` | Yes | Yes (listed, API 2.1) | VERIFIED | Garmin's total = moderate + 2 × vigorous. |
| Intensity min, week | `Info.activeMinutesWeek.total` | Yes | Yes (listed) | VERIFIED | Weekly progress. Never mixed with the daily value. |
| Intensity weekly goal | `Info.activeMinutesWeekGoal` | Yes | Yes (listed) | VERIFIED | Default weekly target. A custom goal can override it. |
| Move bar | `Info.moveBarLevel` (0–5) | Yes | Yes (API 1.0) | VERIFIED | Five segments. Hidden at level 0 and when null. No timer is invented. |
| Floors | `Info.floorsClimbed`, `floorsClimbedGoal` | Yes | Yes (listed, API 2.1) | CONDITIONAL | Shown only when non-null. Missing data is never shown as 0. |
| Battery % | `System.Stats.battery` | Yes | Yes | VERIFIED | Always available. Red below 15 %. |
| Battery days | `System.Stats.batteryInDays` | Yes | Yes (listed, API 3.3) | CONDITIONAL | Used with `has` checks. Hidden when 0 or null. |
| Heart rate | `Activity.getActivityInfo().currentHeartRate`, falling back to `ActivityMonitor.getHeartRateHistory(1, true)` | Yes | Yes (listed) | CONDITIONAL | Value can be null between sensor reads. A history sample older than 10 minutes is greyed out, not shown as live. |
| Stress | `Info.stressScore` (API 5.0) | Yes | Yes (listed) | CONDITIONAL | Not exposed in v1. |
| Body Battery | `SensorHistory.getBodyBatteryHistory` | Needs `SensorHistory` permission | Yes (module listed) | CONDITIONAL | Not exposed in v1, to avoid a permission prompt. Candidate for v1.1. |
| Respiration | `Info.respirationRate` | Yes | Yes (listed) | CONDITIONAL | Not exposed in v1. |
| Pulse Ox | Complications only | Needs a complication subscription | Yes | CONDITIONAL | Not exposed in v1. |
| Weather | `Weather.getCurrentConditions()` | Yes | Yes (listed, API 3.2) | CONDITIONAL | Needs phone-synced data. Not exposed in v1. |
| Notifications | `DeviceSettings.notificationCount` | Yes | Yes | VERIFIED | Not shown in v1, because it made the date line too wide on 390 px. Candidate for v1.1. |
| 12/24 h | `DeviceSettings.is24Hour` | Yes | Yes | VERIFIED | Follows the device by default. A setting can override it. |

## Lifecycle and display

| Item | Finding | Decision |
|---|---|---|
| `onEnterSleep` / `onExitSleep` | All devices, API 1.0 | Switch between the high-power and low-power looks. No timers are used at all. |
| `onPartialUpdate` | **FR165 is not in the supported-device list** | Not implemented. Seconds show only in high-power mode. |
| AMOLED always-on | `requiresBurnInProtection` is true on AMOLED | Dedicated AOD render, updated once a minute: dim colours, no track rings, and a 2 px position shift each minute against burn-in. |
| Fonts | System fonts only | No custom fonts, so there is no licensing or glyph-memory risk. |
| Settings | `Application.Properties` plus `settings.xml` | Every read is validated, with a default for each value. |
