# RESTORA — Handover

Context for continuing RESTORA in a new session, for example Claude Code running locally in `D:\Garmin\Restora`.

## Product

RESTORA is a Garmin Connect IQ **watch app** for the **Forerunner 165 / 165 Music** (390×390 AMOLED, API 5.x). It is an offline-first guided recovery companion. Tagline: *Breathe. Move. Restore.*

It has six modules: BREATHE, MIND, CIRCULATE (lymphatic-support movement and leg elevation), MOBILITY, SLEEP and RECOVER.

It is **not** a medical app:
- no detox or lymphatic-drainage claims,
- no made-up health scores,
- missing data is shown as `--`, never estimated,
- every metric is labelled `Garmin` (measured) or `RESTORA calc` (derived).

The user writes in Indonesian; reply in Indonesian.

## Repo and branch

- GitHub: `albiruby/garminwatchiqapp`, branch `claude/restora-calculation-engine-1n4b9q`. This is the only working branch; there is no PR yet.
- Clone into the local folder:
  `git clone -b claude/restora-calculation-engine-1n4b9q https://github.com/albiruby/garminwatchiqapp.git D:\Garmin\Restora`

## Status

| Area | State |
|---|---|
| Calculation Engine (`source/Calculation/`) | done; unit tests written |
| Session Engine (`source/Engine/SessionEngine.mc`) | done; state machine driven by real time (`System.getTimer` deltas); unit tests written |
| Content: 27 exercises, 17 sessions (`source/Content/`) | done (seed set) |
| UI: sport-tech style (Roboto Condensed, green accent, central ring HUD) | done |
| Motion Engine + 3 exercise prototypes (Calf Stretch, Cat-Cow, Ankle Pumps) with anatomical figures | done; unit tests written |
| **Compiled / run in the simulator** | **NEVER.** The cloud session had no Connect IQ SDK. This is the next step. |

## Next steps (in order)

1. **Build and test** with the Connect IQ SDK, then fix compile and type errors. Small API or syntax mistakes are likely, because none of this code has ever been compiled.
   ```powershell
   monkeyc -f monkey.jungle -d fr165 -o bin\restora-test.prg -y developer_key.der --unit-test
   connectiq
   monkeydo bin\restora-test.prg fr165 /t
   monkeyc -f monkey.jungle -d fr165 -o bin\restora.prg -y developer_key.der
   monkeydo bin\restora.prg fr165
   ```
   APIs most at risk of failing: `WatchUi.CustomMenu` with the `:foreground` / `:titleItemHeight` options, custom bitmap fonts (`resources/fonts/*.fnt`), `Dc.setAntiAlias`, `Dc.setClip`, `fillPolygon` with Number points, class `const` members, and dictionary literals with symbol keys.
2. Check the three motion prototypes on the FR165 simulator: drawing, frame rate (125 ms frames while animating) and memory. Use the profiler.
3. Once they are correct, add the other exercises. Each one is data only, added in `tools/motion/motion_model.py`; there is no per-exercise drawing code.
4. Measure battery use and performance on the simulator or device.

## Architecture (`source/`)

```
RestoraApp.mc            entry: HomeMenu
Calculation/             pure metrics (Metric, MetricValidator, *Calculator, CalculationEngine facade)
Engine/                  SessionEngine (state machine + EVT_* bitmask), HapticEngine
Content/                 ExerciseLibrary, SessionLibrary (data)
Data/                    Models (keys, ids), HistoryRepository (Storage, 100 records), SettingsRepository
Sensors/                 optional HR before/after (off by default)
Motion/                  MotionConfig, Easing, Tween, FrameClock, MotionController,
                         BreathingPulse, CompletionAnimation
Motion/Exercise/         Skeleton (FK), PoseSampler, FigureRenderer,
                         ExercisePoseData.mc + FigureShapes.mc  <- GENERATED, do not edit by hand
UI/                      MenuKit (CustomMenu), Home/Module/Settings menus, SessionDetail,
                         SessionPlayerView (HUD), SessionSummary, History, Hud, Icons
Utils/                   Theme (palette, fonts, 390-px grid, safe circles), TimeFormatter
Tests/                   CalculationTests, SessionEngineTests, MotionTests, MotionGolden (generated)
```

## Rules to keep

- **Animation never owns time.** The Session Engine measures real time, animations only read it, and pausing freezes them. A test proves session state is the same at any frame rate.
- **Layout runs on a 390-px grid** (`Theme.px`) with safe circles: HUD r160, pages r170, menus r164 (with a mask). Nothing may press against the bezel; the user is strict about this.
- **Exercise names are at most 22 characters and cues at most 26** (`testContentFitsHud`).
- **Do not hand-edit the poses or shape data.** Edit `tools/motion/motion_model.py`, then run it. The script:
  - validates the biomechanics (floor contact, joint ranges, hands at the wall, body outline above the floor),
  - checks that every frame stays inside the HUD ring,
  - generates the `.mc` data, the golden test values and the previews.
- **Mockups must pass the layout check**: `node tools/mockups/render.js` must print `layout check: no issues`.
- **Fonts are generated** from `tools/fonts/RobotoCondensed-VF.ttf` (SIL OFL) by `python tools/make_fonts.py`.

## Tools

| Command | Needs |
|---|---|
| `python tools\motion\motion_model.py` | Python 3 + Pillow |
| `node tools\mockups\render.js` (renders `docs/mockups/*.png` + layout check) | Node + Playwright with Chromium |
| `python tools\make_fonts.py` | Python 3 + Pillow |

## Documentation

- `README.md`: overview and build steps.
- `docs/CALCULATION_ENGINE.md`: every metric formula and the null rules.
- `docs/DESIGN_SYSTEM.md`: fonts, palette, grid, safe circles, screens.
- `docs/MOTION_ENGINE.md`: motion architecture, events, prototypes, settings, completed and deferred work.
- `docs/mockups/`: UI and motion previews.

## User's design decisions

- **Visual direction**: Suunto-inspired HUD × COROS-inspired performance UI. Sport-tech, AMOLED black, green accent, condensed typography. The user's reference image: home list with icons and chevrons, a ring HUD showing "Inhale 4", and a summary with metric rows.
- **Exercise figures**: anatomical, not stickmen, and smooth.
- **Motion work order**: prototypes first, validate on the simulator, then expand to the other modules and exercises.
