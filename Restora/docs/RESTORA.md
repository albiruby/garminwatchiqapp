# RESTORA — Recovery, Mind & Movement

*Breathe. Move. Restore.*

An offline-first guided recovery companion for Garmin Connect IQ. The first target is the **Forerunner 165 / 165 Music** (API 5.x, 390×390 AMOLED).

RESTORA is a wellness app, not a medical device. It does not diagnose, treat or claim detox or lymphatic-drainage effects.

## Modules

| Module | Content (seed set) |
|---|---|
| BREATHE | Box, 4-7-8, Extended Exhale, Resonance |
| MIND | Mindful Breathing, Body Scan, Focus Reset |
| CIRCULATE | Leg Reset, Leg Relief, Desk Break (ankle pumps/circles, leg elevation, Legs Up the Wall) |
| MOBILITY | Lower Body, Spine, Neck & Shoulders |
| SLEEP | 5-Min Wind Down, Evening Restore |
| RECOVER | Post-Run Downshift, Workout Cooldown |

## Architecture

```
source/
  RestoraApp.mc        app entry
  UI/                  Custom-drawn menus, session detail, session HUD, summary, history, settings, icons
  Engine/              SessionEngine (state machine), HapticEngine
  Content/             ExerciseLibrary, SessionLibrary
  Data/                Models, HistoryRepository (Storage, 100 records), SettingsRepository (Properties)
  Sensors/             SensorManager, HeartRateProvider, SensorAvailability (all optional)
  Calculation/         Calculation Engine (pure, unit-tested) — see docs/CALCULATION_ENGINE.md
  Motion/              Motion & Animation Engine: frame clock, easing, tweens, breathing pulse,
                       procedural exercise figures (Exercise/) — see docs/MOTION_ENGINE.md
  Utils/               TimeFormatter, Theme (palette, Roboto Condensed fonts, layout helpers)
  Tests/               (:test) unit tests
```

- **Session Engine.** One state machine runs every exercise type: breathing phases, holds, repetitions, alternating left/right, rest and transitions. The states are IDLE → COUNTDOWN → RUNNING ⇄ PAUSED → (AWAITING_NEXT) → COMPLETED / CANCELLED. Elapsed time comes from `System.getTimer()` deltas, not from counting ticks.
- **Calculation Engine.** Derives metrics from session data. Each value is labelled *Garmin* (measured) or *RESTORA calc* (derived). Missing data shows as `--` and is never estimated.
- **Haptics.** Forerunner devices have a single vibration strength, so cues differ by count and spacing: 1 pulse for a phase, 2 for the next exercise, a long pulse for a side change, 3 for complete.

## Controls (in a session)

START pauses or resumes (in manual mode it moves to the next exercise). DOWN skips the exercise. BACK asks for confirmation, then ends the session.

## Build & test

Requires the Connect IQ SDK and a developer key.

```sh
# Unit tests
monkeyc -f monkey.jungle -d fr165 -o bin/restora-test.prg -y developer_key.der --unit-test
connectiq &
monkeydo bin/restora-test.prg fr165 /t

# App in the simulator
monkeyc -f monkey.jungle -d fr165 -o bin/restora.prg -y developer_key.der
monkeydo bin/restora.prg fr165
```

In VS Code you can use **Monkey C: Run Tests** and **Monkey C: Run** instead.

## Settings

Haptics (on), countdown 3/5/10 s, auto-advance (on), HR before/after (off). You can change them on the watch or in Connect IQ app settings.

## Safety

Each session shows a safety note. Elevation and inversion sessions carry a specific warning: Legs Up the Wall is not suitable for everyone, for example people with glaucoma, heart or kidney failure, or uncontrolled blood pressure. Stop if you feel pain, dizziness, shortness of breath or more swelling.

## Design

The design is a sport-tech recovery look: Roboto Condensed, AMOLED black, one green accent, a segmented progress ring and bar, and safe-circle layouts. See `docs/DESIGN_SYSTEM.md`.

- Fonts: `python3 tools/make_fonts.py` regenerates `resources/fonts/` from `tools/fonts/RobotoCondensed-VF.ttf` (SIL OFL).
- Motion model: `python3 tools/motion/motion_model.py` validates exercise poses and regenerates
  `source/Motion/Exercise/ExercisePoseData.mc`, test golden values and previews.
- Screens: real simulator screenshots in `docs/store/screenshots/`; marketing images built from them by `tools/store/make_store_images.py`. The older HTML mockups (`tools/mockups/`, Roboto) are kept for reference only.

![RESTORA hero](docs/store/marketing/hero-1920x1080.png)
