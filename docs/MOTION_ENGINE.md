# RESTORA Motion & Animation Engine

**Status: Phases 1, 2, 4 and 5 are implemented in Monkey C. They have NOT been compiled or run yet.** No Connect IQ SDK is available where this was written: `developer.garmin.com` is unreachable, and FR165 device files need a Garmin login. Before going further, build the app and run the unit tests (commands at the end).

## Principles

1. **Animation never owns time.** `SessionEngine` measures real elapsed time (`System.getTimer()` deltas). Animations read the session time, never the other way round:
   - Exercise figures are sampled at the step's elapsed time, so pausing freezes them.
   - No animation decides when an exercise or session ends.
   - `testSessionTimingIndependentOfFrameRate` proves that 2,000 ticks at 125 ms and a single tick give identical session state.
2. **A single source of truth for poses.** `tools/motion/motion_model.py` defines the skeleton and every pose. From it, the tool:
   - validates biomechanics (floor contact, knee, elbow and ankle ranges, hand on wall, wrists under shoulders),
   - checks that every frame stays inside the HUD ring,
   - generates `ExercisePoseData.mc`, the golden test values, the mockup frames and the preview strips.
3. **Data-driven exercises.** Adding an exercise means adding poses and segments to the model. There is no per-exercise drawing code.
4. **Allocation-free frames.** Joint buffers, polygon point arrays and ring/bar weights are allocated once per screen.
5. **Frame rate follows need.** Frames run at 125 ms while something moves (250 ms in low detail) and at 1 s otherwise. Screens drop to 1 s when paused, while a stretch is held, while hidden behind a notification, or when motion is off.

## Architecture (as built)

The prompt's ~60-file tree was condensed: many of the proposed files would have been a few lines each, and the brief says not to create empty files. The responsibilities map like this:

| Proposed | Implemented in |
|---|---|
| MotionEngine / MotionScheduler | `source/Motion/FrameClock.mc`: one timer per screen, interval switching |
| MotionConfig | `source/Motion/MotionConfig.mc`: settings and frame-interval policy |
| MotionInterpolator | `source/Motion/Easing.mc`: linear, in-out sine, out cubic, in-out quad, lerp |
| MotionState | `source/Motion/Tween.mc`: reusable start/duration/easing tween |
| MotionController + session events | `source/Motion/MotionController.mc` |
| SkeletonModel / BodyPart / JointModel | `source/Motion/Exercise/Skeleton.mc`: lengths, pose layout, part flags, FK, mirroring |
| PoseDefinition / MovementSequence / Library | `source/Motion/Exercise/ExercisePoseData.mc` (**generated**) |
| PoseInterpolator / ExerciseAnimationEngine | `source/Motion/Exercise/PoseSampler.mc`: easing per segment, loops, reps, hold, phase label |
| ExerciseRenderer / MovementDirection / RangeIndicator | `source/Motion/Exercise/FigureRenderer.mc` |
| BreathingPulse / Ring / Phase animation | `source/Motion/BreathingPulse.mc` and the existing phase ring (`source/UI/Hud.mc`) |
| SuccessAnimation / SessionCompletionAnimation | `source/Motion/CompletionAnimation.mc` |
| CircularProgress / LinearProgress / SegmentedProgress | `source/UI/Hud.mc` (`segmentRing`, `segmentBar`) |
| HapticSynchronizer | `MotionController.onEvents` → `HapticEngine` |

## Session Engine integration

`SessionPlayerView` → `MotionController.onEvents(engine, evtBits, nowMs)`:

| Prompt event | Engine signal | Motion response |
|---|---|---|
| SESSION_STARTED | `start()` (countdown) | the ring sweeps through each countdown second |
| EXERCISE_STARTED | `EVT_STEP_START` | new `PoseSampler`, 220 ms slide-in (out-cubic), double haptic |
| EXERCISE_COMPLETED / SKIPPED | `EVT_STEP_DONE` / `skip()` | the next step binds; the bar segment fills |
| PHASE_CHANGED | `EVT_PHASE` | breathing ring segment and pulse follow the phase; single haptic |
| left/right switch | `EVT_SIDE` | the figure mirrors and the set-up replays on the new side; long haptic |
| TIMER_UPDATED | every frame | `PoseSampler.sample(stepElapsedMs)` |
| REPETITION_UPDATED | `sampler.reps` | label shows `FLEX · 3`. For breath-synced moves, a haptic on each cat↔cow change |
| SESSION_PAUSED / RESUMED | engine state | figure and guides freeze, ring turns amber, 1 s frames |
| SESSION_CANCELLED / COMPLETED | `EVT_COMPLETE` / cancel | summary plays the 450 ms check-mark animation, then its clock stops |

## Exercise figure

- **Skeleton**: a side view with head, neck, torso (a curved spine for flexion and extension), and near and far arms and legs (upper arm, forearm, thigh, shin, foot with heel and toe). Angles are absolute; the figure faces +x. Mirroring flips x around the figure centre.
- **Styles**:
  - *Silhouette* (default): tapered limb polygons with rounded joints. Near limbs are light grey and far limbs dark grey. Highlighted parts are green. Props (floor, wall) are dark.
  - *Skeletal*: 2 px bones with joint dots, used when Motion detail is Low.
- **Guides**:
  - Green direction arrows: straight or arc, bound to a movement segment or shown during a hold.
  - A range arc around a joint (ankle-pump range).
  - The phase label and rep count under the timer.
- **Placement**: the figure is centred at y 150 inside the HUD ring, with the timer (40 px) at 194 and the label at 236. `check_ring()` verifies every frame of every exercise, mirrored and not, stays within r78 of the ring centre (the ring's inner edge is r84).

### Prototypes

| Exercise | Type | Motion | Validated |
|---|---|---|---|
| Calf Stretch | HOLD (alternating sides) | split-stance set-up → lean to the wall (1.2 s, out-cubic) → hold; heel-down arrow while holding; calf green; mirrors on the right side | rear heel on the floor, hands at the wall, feet planted throughout |
| Cat-Cow | BREATH_SYNC loop | cat ⇄ cow, 4 s each (in-out sine); spine highlighted; arc arrow per phase; haptic on each change | wrists under shoulders, knees under hips |
| Ankle Pumps | REPETITION loop | point (40° plantarflexion) ⇄ flex (22° dorsiflexion), 1 s each; lower leg and foot only; range arc; rep count | ankle within −56…+35°, heel never below the floor |

Previews: `docs/mockups/motion-calf-stretch.png`, `motion-cat-cow.png`, `motion-ankle-pumps.png`, and the HUD screens 14–16 in `restora-ui-mockups.png` and `motion-hud.png`.

## Settings

| Setting | Property | Default | Effect |
|---|---|---|---|
| Motion | `motion` | On | Off = no interpolation, 1 s frames, no figure |
| Reduced motion | `reducedMotion` | Off | figure snaps between key poses; no tweens, no ring sweep |
| Figure guide | `exerciseAnim` | On | animated exercise figure |
| Breath pulse | `breathingAnim` | On | expanding/contracting disc behind the phase |
| Motion detail | `motionDetail` | Standard | Low = skeletal style, 250 ms frames |
| Haptics | `haptics` (existing) | On | all cues |

**Ambient motion is not exposed.** It was not built, and the brief says not to expose settings that do nothing.

## Tests (`source/Tests/MotionTests.mc`)

| Test | What it checks |
|---|---|
| easing | endpoints, clamping, monotonic curves |
| forward kinematics | matches the Python model (golden values) |
| calf stretch constraints | heel on the floor, hand at the wall |
| mirror symmetry | figure flips cleanly to the other side |
| pose interpolation | matches the model; keyframes are exact |
| repetition counting | rep count at given times |
| hold | reaches the hold and stays there |
| reduced motion | snaps to key poses |
| data well-formed | animation definitions are valid |
| frame-rate independence | session state is identical at any tick rate |
| pause | freezes animation time and drops to idle frames |
| alternating side | restarts and mirrors |
| tween progress | tween timing |
| breathing pulse radius | disc size per phase |

```sh
python3 tools/motion/motion_model.py      # validate poses + regenerate data/golden/previews
node tools/mockups/render.js              # mockups + layout check (must say "no issues")
monkeyc -f monkey.jungle -d fr165 -o bin/restora-test.prg -y developer_key.der --unit-test
connectiq & monkeydo bin/restora-test.prg fr165 /t
```

## Completed animations

- **Progress**: segmented progress ring, segmented exercise bar, and the countdown ring sweep.
- **Breathing**: phase ring with per-phase segments, ▲▼ phase markers, and a breathing pulse disc that expands, holds, contracts and rests.
- **Exercise**:
  - procedural figure in silhouette and skeletal styles, with forward kinematics and pose interpolation;
  - movement sequences (hold, loop, breath sync);
  - left/right mirroring with the set-up replayed on each side;
  - body-part highlighting, direction arrows, range arc, and rep and phase labels.
- **Session**:
  - 220 ms exercise slide-in, plus a re-entry when the side changes;
  - pause freeze in amber;
  - frame scheduling that slows down when hidden.
- **Feedback**:
  - completion check-mark animation;
  - haptics synchronised with steps, phases, sides, completion and breath-synced movement.

## Deferred / not implemented

| Item | Reason |
|---|---|
| Other 14+ exercise animations (ankle circles, shoulder rolls, hip circles, child's pose, legs up the wall …) | Deliberately waiting for the 3 prototypes to be validated on the FR165 simulator. Each is data-only in `motion_model.py` |
| Fade animations, card/tab transitions | Alpha blending is not used. Screen transitions use the native `WatchUi.SLIDE_*` |
| Animated menu selection / focus | `CustomMenu` owns scrolling; there is no hook for a per-frame focus tween |
| Number transitions, waveform, gauge, scanning line, status blink | Not built: they compete with instructions, and the brief asks for no decorative motion |
| Ambient pulse / wave / orbit | Not built; setting not exposed |
| Warning / error / loading animations | No screen currently needs them |
| Rest/transition countdown visuals beyond the timer | Rest steps use the standard ring + timer |

## Performance notes (not measured)

Nothing below is measured: there was no simulator or device here. These are estimates to check on the FR165.

- **Drawing per frame (silhouette)**: about 20 `fillPolygon`/`fillCircle` calls for the figure, plus the HUD. That is about 8 redraws per second while moving, and 1 per second while holding, paused, hidden or idle.
- **Memory**: one joint buffer (32 floats), the pose buffer (15), polygon arrays (4 + 3 + 14 points), and the generated pose dictionary built lazily on first use.
- **Battery**: if testing shows a high cost, set Motion detail to Low (250 ms frames, skeletal style) or turn on Reduced motion (1 s frames).
- **Profiling**: use the simulator's profiler (`File > View Profiler`) to measure `onUpdate` time. If it exceeds about 40 ms at 125 ms frames, lower `FRAME_STANDARD_MS`.
