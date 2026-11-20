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
| Content: 40 exercises (incl. custom breathing), 29 sessions, 4–6 per module (`source/Content/`) | done |
| UI: sport-tech style (Oswald, green accent, central ring HUD, RESTORA logo) | done; checked in the simulator (Home, module lists, session detail, breathing and Calf Stretch HUD) |
| Motion: 25 animated exercise figures (side view + front-view bust) (see `docs/mockups/motion-*.png`) | done; all poses pass `motion_model.py` validation |
| Sensors: HR and HRV (RMSSD from Garmin beat intervals), optional | done; unit tests; **not yet verified on a real sensor** |
| History: weekly dashboard, last 20 sessions, detail page | done |
| Store material (`docs/store/`: listing, privacy, release notes, screenshots), version 1.0.0 | done |
| Build | compiles for fr165 and fr165m; 42/42 unit tests pass; release package `bin/RESTORA.iq` builds |
| Physical FR165 test, battery measurement | **not done** |

Animated: calf_stretch, cat_cow, ankle_pumps, heel_raises, knee_bends (heel slides), childs_pose, legs_wall, legs_chair, seated_march, walk_cool, hamstring, quad_stretch, hip_flexor, knee_chest, hip_mobility (figure four), transition, relax (savasana), supine_elev. Breathing exercises use the breathing ring instead of a figure. Every movement exercise is animated. neck_side and shoulder_rolls use the front-view bust (`view: 1`, outlines in `BUST_*`). Engine: optional rest between exercises (Settings → Rest). Custom breathing pattern in Settings → Custom.

Build notes: `monkey.jungle` pins `base.sourcePath`/`resourcePath`, because the repo also holds other watch projects under `projects/`. Python 3.12 + Pillow is installed for the generators. `developer_key.der` is a local test key; use your permanent key for store uploads.

## Next steps (in order)

1. Sideload `bin\restora.prg` to a physical FR165 (copy to `GARMIN\APPS`), then check haptics, readability on AMOLED, buttons and battery during a 20-minute session.
2. Go through every session in the simulator once (all 17), using the QA checklist in `docs/DESIGN_SYSTEM.md`.
3. Add a front view to the figure renderer, then animate the upper-body exercises (neck, shoulders, arms, thoracic rotation, ankle circles) and the rest of the 42-movement library.
4. Regenerate `docs/mockups/screen-*.png` (needs Playwright for `tools/mockups/render.js`); they still show Roboto.
5. Store listing: screenshots, description, and the permanent signing key.

```powershell
monkeyc -f monkey.jungle -d fr165 -o bin\restora-test.prg -y developer_key.der --unit-test
monkeydo bin\restora-test.prg fr165 /t
monkeyc -f monkey.jungle -d fr165 -o bin\restora.prg -y developer_key.der
monkeydo bin\restora.prg fr165
monkeyc -f monkey.jungle -e -r -o bin\RESTORA.iq -y developer_key.der
```

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
