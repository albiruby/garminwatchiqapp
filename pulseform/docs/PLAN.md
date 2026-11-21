# PULSEFORM: plan, structure, risks

## Product concept
GOAL TRACK is the visual identity.
- The step goal is a 300° track around the bezel. The 60° opening at the bottom holds the battery reading.
- A small marker shows where 100 % lands on the track.
- Going past the goal draws a second, thinner **lap** inside the track. The lap's length is the real overshoot: 150 % gives half a lap. The track itself never fakes more than 100 %.
- Five visual states come only from the percentage: START (<25), BUILDING (25–74), NEAR (75–99), COMPLETED (100), OVER (>100).
- There are three track styles: circular, linear and segmented (10 × 10 %).
- There are three layout presets: Balanced, Minimal and Data Dense.

## Source structure
| File | Role |
|---|---|
| `PulseFormApp.mc` | Entry point. Reloads settings when they change. |
| `PulseFormView.mc` | Runs the render: settings, metrics, goals, layout, then drawing. Handles sleep state. |
| `SettingsManager.mc` | Reads, validates and resets settings, with a default for every value. |
| `MetricProvider.mc` | Reads only the VERIFIED and CONDITIONAL APIs. `null` means unavailable. |
| `ActivityGoalEngine.mc` | Pure maths: ratio, floor percent, remaining amount, state, filled segments, overshoot lap. |
| `ProgressRenderer.mc` | Draws the circular, linear and segmented tracks and the mini bars. |
| `LayoutEngine.mc` | Positions and fonts for each preset, all derived from the screen radius. |
| `ThemeManager.mc` | Four themes, each with one accent colour, plus neutral tokens. |
| `FormatUtils.mc` | Formats time, thousands, distance, calories and percent. |
| `PowerManager.mc` | AOD burn-in shift and the AOD palette. |
| `Preview.mc` | Screenshot-only overrides. `ON = false` in every release build. |
| `test/*.mc` | Unit tests for the goal maths, formatting and settings checks. |

Device geometry is computed inside `LayoutEngine`. A separate DeviceProfile class would hold four numbers, so it was left out.
The brief's FontManager and Delegate modules were also left out: system fonts are chosen per preset in `LayoutEngine`, and no input handling is needed.

## Risks
1. **No active-calorie API.** We show total calories with a clear label and say so in the store text.
2. **The simulator can't show real sensor behaviour** (heart-rate gaps, floors on the real FR165 barometer). Real-device checks happen in M08.
3. **System font sizes differ between devices.** The layout measures font heights at runtime; FR165 is the only tuned target.
4. **AOD lit-pixel budget.** We measure it from simulator screenshots, and Garmin's on-device enforcement still needs a real-device check.
5. **Settings UI limits.** Garmin Connect has no colour picker, so the "custom accent" option is out of scope and the four themes cover it.

## Milestones (from the brief)
M01 foundation → M02 clock → M03 activity data → M04 goal engine → M05 visualization and presets → M06 settings → M07 power/AOD → M08 QA → M09 release prep.
M01 to M07 are built in this pass, with simulator verification. M08's real-device part and M09's store submission need the user's watch and account.
