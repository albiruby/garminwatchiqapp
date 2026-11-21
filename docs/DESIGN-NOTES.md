# PULSEFORM: design notes (antislop, mode: during)

## Direction
The user picked "a combination" of three offered directions:
- **Precision instrument**: a measuring scale on the bezel and technical labels.
- **Bold sport poster**: a large focal number and an asymmetric composition.
- **Calm and minimal**: lots of black space and one accent.

**Design read:** a watch face for daily activity goals, worn by runners.
- Visual language: precision sport instrument, with poster-scale numerals and calm black space.
- Dials: **ENERGY 2 / RHYTHM 2 / MOTION 1.**

| Dial | Value | Why |
|---|---|---|
| ENERGY | 2 | The stacked numerals carry the poster weight; everything else stays quiet. |
| RHYTHM | 2 | The three presets share one grid (spine plus readouts). Minimal breaks it on purpose by dropping the spine. |
| MOTION | 1 | It is a watch face: seconds tick while awake, nothing animates. Battery comes first (no timers, no partial updates). |

## Identity motif
1. **The spine.** A vertical hairline through the centre divides *time* (left) from *readings* (right). In linear style the spine itself becomes the vertical goal gauge.
2. **Stacked time.** Hours sit above minutes, right-aligned against the spine.
3. **Instrument needle.** A white cursor crosses the goal track at the exact step position. A 10 % scale is ticked inside the track, and the 50 % tick is longer.

Swap test: replace the name, and the spine with stacked numerals and a needled bezel scale still marks it as this face. The previous layout (ring, centred time, three equal metric cards) could have been anyone's.

## Decisions and reasons (R-31)
| Decision | One-line reason |
|---|---|
| Black background | AMOLED: unlit pixels cost no power and give the calm black space the direction asks for. |
| One accent per theme (lime, cyan, orange, white) | The accent only ever means "progress", so the eye finds progress instantly. |
| White numerals, grey labels | Two neutral levels give hierarchy without spending a second colour. |
| Red only below 15 % battery | A warning has to break the palette to be noticed, so it is used for nothing else. |
| Barlow Condensed for numerals | Condensed digits fit two lines of time and a readout column side by side on 390 px; Barlow's flat terminals read as sport instrumentation. |
| Barlow (normal width) for the step count | The one number the face exists for gets the wider, steadier cut. |
| Uppercase labels, 2 px tracking, 16 px | At 16 px on 390 px, Barlow caps stay legible where its lowercase x-height (about 8 px) does not; the 2 px tracking separates condensed caps without becoming decoration. |
| Stacked time, right-aligned to the spine | Poster scale without losing half the screen; keeps the reading order left to right (time, then progress). |
| Readout rows (label left, value right, bar under) | Instrument-panel rows scan top to bottom like a spec sheet; they replace three identical cards. |
| Needle on the track | The arc shows the amount; the needle answers "where exactly am I" without reading a number. |
| 10 % scale ticks, longer at 50 % | Gives the arc a ruler, so 30 % and 40 % look different without text. |
| Inner lap for overshoot | Going past the goal is shown as a second, thinner lap rather than a clamped ring or a number only. |
| Hairline dividers (#2C2F35) | They separate groups at a contrast low enough to disappear behind the data. |
| No icons | The labels (KM, KCAL, MIN/WK, BPM) say it in fewer pixels; generic glyphs would add noise. |
| No glow, gradient or shadow | AMOLED black plus flat colour is the identity. Effects would also cost lit pixels. |
| Battery in the track opening | It is device status, not activity, so it lives outside the activity zone. |

## Faces (layout setting)
Each face answers "how close am I to my goal?" with a different picture. They share the spine-and-readout vocabulary, the needle and the look system.

| Face | Picture of progress | Reason it exists |
|---|---|---|
| Balanced | Bezel track, with time and readouts split by the spine | Default: time first, goal second, metrics third. |
| Minimal | Bezel track, centred stacked time, one footer line | For people who want the goal as an ambient ring. |
| Data Dense | Bezel track, five readout rows | All verified metrics at once, still on the same grid. |
| **Dial** | Analog hands over the bezel track | An analog wearer reads the time from the hands' angle; the goal track keeps its scale and needle. |
| **Horizon** | A level rising from the bottom of the screen to a GOAL line | Progress becomes the whole surface, readable at a glance from across a room. |
| **Stack** | One column per goal against a shared 100 % line | Compares every goal at once. Columns without a target stay as empty outlines, never invented bars. |

Notes:
- Horizon and Stack draw their own progress, so the goal-track style setting does not apply to them (the setting's help text says so).
- Linear style applies to the spine faces and Minimal. Dial keeps its ring.
- Horizon's fill is a 12 % tint of the progress colour, which keeps text on it at 4.5:1 or better.

## Looks (look setting)
A look is a treatment, not a colour swap. It sets numerals, rules, the needle, the scale, the neutral palette and how the accent behaves. The accent colour can follow the look (default) or be one of 8 fixed colours.

| Look | Numerals | Rules | Needle | Scale | Palette | Accent behaviour |
|---|---|---|---|---|---|---|
| Carbon | Solid Barlow Condensed SemiBold | 1 px hairline | Line | Ticks | Cool greys | Lime marks progress |
| Reflective | Outline (stroked) | Dashed | Chevron | Dots | Bright cool greys | Volt marks progress |
| Field | Light Barlow Condensed | None (spacing only) | Round dot | Dots | Warm white and sand | Terracotta marks progress |
| Signal | Solid | 2 px bold | Block | Heavy ticks | Pure monochrome | **No colour until the goal is met**, then red |

Reasons:
- **Reflective** is modelled on the reflective print on running gear: outlines and dashes read as reflective tape, and the chevron is the arrow such gear uses.
- **Field** is for wearing outside of training. Light numerals and no rules make it quieter; warm neutrals take the edge off pure black.
- **Signal** makes reaching the goal an event: the first colour on the face appears only then.

## Honesty rules applied
- No data is invented. Every value comes from a verified Garmin API, and missing data shows "--" (`docs/CAPABILITY_MATRIX.md`).
- There is no active-calorie figure, because FR165 has no API for it. Total calories are labelled as such in the settings.
- Screenshot fixtures (`source/Preview.mc`) are off in every release build, and a unit test guards that.

## Delivery Gate (antislop), 2026-11-21, after adding faces and looks
Context: a Garmin watch face, not a web page. Items about navbars, FAQs, keyboard focus and page breakpoints have nothing to apply to, and are marked N/A with the reason.

**Block 1: Hard Gate**
| Rule | Result | Evidence |
|---|---|---|
| R-02 em dash | PASS | No match for an em dash in `source/`, `resources/` or the docs. |
| R-03 responsive | PASS | One target screen (390 px round). The layout audit found 0 collisions and 0 out-of-circle boxes in 37 shots (6 faces x 4 looks plus edge states). Analog hands are excluded: they move across the dial by nature. |
| R-17 / R-36 / R-38 numbers and claims | PASS | Every value comes from a device API listed in `CAPABILITY_MATRIX.md`; missing values show "--". The screenshot fixtures are off in release builds (unit test `previewIsOff`). |
| R-18 / R-28 testimonials, FAQ | N/A | None exist. |
| R-23 assets | PASS | The launcher icon was drawn for this project (track and lap); no people or logos. |
| R-24 / R-32 navigation, keyboard | N/A | A watch face has no navigation or input. |
| R-25 contrast | PASS | Unit test `lookContrast` checks every look's text and muted colour and all 8 accents: the lowest accent is Signal Red at 5.92:1. Text on Horizon's fill uses a 12 % tint, which keeps it at 4.5:1 or better. Always-on text is 5.3:1. |
| R-26 interactive | N/A | No controls on the face. Settings run through Garmin Connect. |
| R-27 states | PASS | No data shows "--" and "NO STEP DATA"; no goal shows "NO STEP GOAL"; stale heart rate is greyed. Data is read synchronously, so there is no loading state. |
| R-33 patching | PASS | All features are written in the source. The helper scripts generate fonts and screenshots; none patch the UI. |
| R-34 themes | PASS | All 4 looks were rendered on all 6 faces; a white accent switches the lap to lime so it stays visible. |
| R-35 verify | PASS | Release builds for fr165 and fr165m, 15/15 unit tests, 37-shot matrix, heap about 47 KB of 127 KB. Real-device check still pending (M08). |
| R-37 direction | PASS | The user chose a combination of three offered directions; the design read and dials are above. |

**Block 2: Purpose-Gate.** PASS. The face has no gradients, glow, shadow, glass, badges, arrows or generic icons. The uppercase tracked labels have a written reason (decisions table).

**Block 3: Liveliness**
| Check | Result |
|---|---|
| Dials declared, output matches | ENERGY 2 / RHYTHM 2 / MOTION 1. Poster-scale stacked numerals; Minimal breaks the shared grid on purpose; nothing animates. |
| One focal point | The stacked time. |
| Structural whitespace | Black space separates the time column from the readouts; no filler. |
| One deliberate accent | The theme accent marks progress only. |
| Identity motif | Spine, stacked time, needle on a 10 % scale. |

**Block 4: Craftsmanship.** PASS.
- The three identical cards were replaced by readout rows.
- No buzzwords.
- The palette is neutrals, one accent and a warning red.
- No clone of another product.
- Every major decision has a one-line reason.
