# RESTORA Design System — Sport-tech Recovery

RESTORA uses running-watch instrumentation (structured data, segmented progress, high contrast) applied to recovery practice. It is a recovery app with a sport-tech character, not a soft meditation app.

Code: `source/Utils/Theme.mc` (tokens), `source/UI/Hud.mc` (ring and bar), `source/UI/Icons.mc` (vector icons), `source/UI/MenuKit.mc` (lists). Mockups: `docs/mockups/`, rendered by `tools/mockups/`.

The design system has six foundations: layout, typography, components, colour, interaction and state, and motion and rendering. Every screen is built from them. A screen is not finished until it passes the [QA checklist](#design-qa-checklist).

## Typography: Oswald

The type is condensed and firm, so more data fits across the round screen. Connect IQ cannot load TTF files, so `tools/make_fonts.py` pre-renders bitmap fonts from the variable font (`tools/fonts/Oswald-VF.ttf`, SIL OFL 1.1) into `resources/fonts/`. Oswald digits are proportional; the generator gives 0–9 one common advance (tabular numerals), so `00:09` → `00:10` does not change the timer's width.

| Token | Weight | px | Use |
|---|---|---|---|
| `Theme.label()` | Medium | 14 | small UPPERCASE labels (`STARTS IN`, `SESSIONS`) |
| `Theme.small()` | Regular | 16 | subtitles, cues, table rows |
| `Theme.body()` | Medium | 18 | list names, info row, clock |
| `Theme.title()` | SemiBold | 22 | titles, phase word, metric values, pills |
| `Theme.num()` | SemiBold | 36 | headline numbers (digits only) |
| `Theme.hero()` | SemiBold | 54 | timer inside the HUD ring (digits only) |

The text fonts include `·`, `↑`, `↓` and `…`. Names are in sentence case ("Leg Relief"); small labels are in UPPERCASE.

## Spacing scale

Margins and gaps come from one scale (`Theme.SP_*`, 390-px units, scaled with `Theme.px()`). Values are a starting point; adjust after testing on the device, not per screen.

| Token | px | Use |
|---|---|---|
| `SP_XS` | 2 | icon to a small detail |
| `SP_S` | 4 | related elements (title → subtitle) |
| `SP_M` | 8 | between groups |
| `SP_L` | 12 | component padding (row card inset, pill padding) |
| `SP_XL` | 16 | between sections |
| `SP_XXL` | 24 | between main areas |
| `SP_XXXL` | 32 | large separations |

Fixed component sizes: list row 88, focused card radius 12, pill 120 × 30 (radius 15), hairline 1, row icon 26, chevron 18, focus bar 4 × 36.

## Colour (AMOLED black, one green accent)

| Token | Hex | Role |
|---|---|---|
| `BG` | `#000000` | Canvas. AMOLED pixels are off |
| `SURFACE` | `#17211B` | Focused row, pills |
| `TRACK` | `#26302A` | Ring and bar track, inactive segments |
| `LINE` | `#2A322D` | Hairlines |
| `GREEN` | `#4FC97A` | Accent: active state, progress, HUD title, focused icon, values that are on |
| `GREEN_DIM` | `#2C6B45` | Secondary green (module share) |
| `WHITE` | `#F2F3EF` | Primary text and numbers |
| `SOFT` | `#C9CEC9` | Unfocused names and icons |
| `GREY` | `#8A918C` | Labels, secondary text |
| `AMBER` | `#E2A93B` | Paused |
| `RED` | `#E06C61` | Error |

## Layout grid and safe circles

All layouts use a **390 px grid** (FR165), scaled with `Theme.px()`. Content stays inside a **safe circle**:

| Screen | Safe radius |
|---|---|
| Session HUD | **160 px** |
| Detail, summary, history | **170 px** |
| Menus | **164 px**. `MenuMask` also blacks out y < 62 and y > 316 |

Radial zones: the **core** (r ≤ 120) holds the primary content (timer, figure, focused row); the **central safe zone** (up to the screen's safe radius) holds supporting text; the **peripheral zone** (r 160–190) holds only the HUD ring, the START arc and indicators; nothing is drawn in the **edge exclusion** beyond that.

- Line widths come from the safe circle at that height. Text that is too wide drops to a smaller font, and only then is cut (`Theme.fitLine`).
- Exercise names are at most 22 characters and cues at most 26 (`testContentFitsHud`).
- Screens are checked on simulator screenshots (`docs/store/screenshots/`, 390 × 390). The old HTML mockup renderer (`tools/mockups/`) still uses Roboto and illustrative data; it is kept for reference only and is no longer the source of truth.

## Screens

### Home and lists (`MenuKit`)

- Header: RESTORA logo mark (`resources/drawables/logo_mark.png`, from `LogoStandaloneRESTORA`), **RESTORA**, `RECOVERY COMPANION`.
- Rows are 88 px: an icon (x 84), the name, a grey subtitle, and a chevron or a value on the right. Row x positions are screen positions: the item dc starts right of the system scroll strip, so `RowItem` subtracts that offset.
- The focused row sits on a `SURFACE` rounded card (x 48–342) with a green bar on the left; its name is bold and its icon is green.
- The bands and the circle mask show either the title or the focused row with one neighbour on each side. No row is ever half-cut by the bezel.

### Session HUD

```
    34  10:47                         clock
    54  Legs Up the Wall              exercise, green
        ╭──── ring r88 @ y186 ────╮   breathing: one segment per phase, active fills
        │   ▲  Inhale / HOLD      │   other: one ring = exercise progress
        │      4  /  03:24        │   timer 60 px
        │      RIGHT              │   side for alternating exercises
        ╰─────────────────────────╯
   286  cue | Next: X (last 10 s) | PAUSED (amber) | START: next exercise
   308  ⌚ 04:24          4/5          icon + pattern or session time left, step
   336  ▬▬ ▬ ▬ ▬▬▬▬▬ ▬               segmented bar, one segment per exercise
```

When paused, the active segment and the state line turn amber and the timer turns grey.

### Summary

- A check mark in a circle (green when completed, amber when ended early), **Session complete**, then the session name and data source.
- Three metric rows, each an icon followed by a bold value over a grey label:
  - Duration.
  - Breathing cycles, leg elevation or exercises, whichever fits the session.
  - HR change, marked `Garmin`, or completion when there is no HR reading.
- A **Done** pill and the START hint on the bezel.

### History

- Page 1: a 2 × 2 grid of green 40 px numbers (sessions, minutes, modules, day streak), the module-share bar, and the completion line.
- Page 2: a label/value table.
- Both pages are labelled `RESTORA CALC`.

## Exercise figure style: Anatomy X-Ray

Default figure style (Settings → X-ray figure; off = classic grey). Based on the Claude Design study `design-import/Wall Calf Stretch X-Ray.html`.

| Element | Colour | Notes |
|---|---|---|
| Body fill | `#1A1F24` | dark, reads as a scan |
| Rim (outline) | `#8FA3B0` | 1 px outside every silhouette |
| Far-side body / rim | `#111418` / `#4E5A63` | depth |
| Target muscle | `#E5484D` | replaces the green highlight on figures only |
| Muscle fibres | `#FF8A8E` | 3 lines along the highlighted segment |
| Anatomy hint | `#3C4A55` | spine line inside the back |
| Floor / wall | `#2A3138` | dotted floor; wall with measuring ticks |
| Direction arrows | `#E5484D` | |

Silhouettes are drawn in groups — far limbs, then torso + head + near leg, then the near arm — each with a rim pass and then a fill pass, so overlapping parts read as one body and the near arm keeps its own outline. The 3/4 bust uses two groups: body, then arms in front. The app UI keeps the green accent; red is only for the target muscle and movement cues.

## Components and states

| Component | Default | Focused / active | Paused | Completed | Disabled / no data |
|---|---|---|---|---|---|
| Navigation row (`RowItem`) | SOFT name, GREY subtitle, GREY chevron | SURFACE card, green bar, WHITE bold name, green icon | — | — | value shows `--` |
| Session step (detail table) | green index, WHITE name, GREY time | — | — | — | — |
| Metric (summary, history) | WHITE/green value over GREY label + source tag | — | — | — | `--`, never an estimate |
| Primary action pill | SURFACE pill, green label (Start, Done) | — | — | — | not drawn |
| HUD ring / segmented bar | TRACK | GREEN fill | AMBER | full GREEN | — |

Session states keep one layout: `IDLE → COUNTDOWN → RUNNING ⇄ PAUSED → (AWAITING_NEXT) → COMPLETED`. Only colour and the state line change; nothing moves.

## Content and data rules

- Exercise names ≤ 22 characters, cues ≤ 26 (`testContentFitsHud`). Longer text falls to a smaller font, then truncates (`Theme.fitLine`); notes wrap to at most two lines (`Theme.wrap`).
- Missing data is `--`. With no history, the completion line reads "No sessions yet" instead of a percentage.
- Every number carries its source: `Garmin` (measured), `RESTORA CALC` (derived), `USER` (entered). Formulas, denominators and periods are in `docs/CALCULATION_ENGINE.md`; a derived number never reads like a medical measurement.
- One screen, one purpose: the HUD shows only the movement, timer, phase and progress.

## Interaction

- **Button-first**: START selects, starts and pauses; DOWN skips; BACK goes back or asks to end the session.
- A green arc at the 2 o'clock bezel position marks START wherever START has a meaning.
- Any session is at most 3 presses from Home.
- Haptics mark events, not time: step start (2 pulses), side change (1 long), completion (3). Breathing and breath-synced phase cues are throttled to one per ~9 s.

## Motion and rendering

- Animation never owns time: the Session Engine measures it; pausing freezes the figure.
- Frames run at 125 ms only while something moves; held poses and paused sessions drop to 1 s.
- Animations never move the timer, ring or text, and every screen reads correctly with animation off (Settings → Motion).
- Exercise figures come only from `tools/motion/motion_model.py` (validated poses, ring check).

## Design QA checklist

A screen is done when all of these hold:

1. Nothing leaves the circular safe area; no text or icon is clipped.
2. Spacing and alignment use the spacing scale.
3. The hierarchy reads at a glance: primary → supporting → metadata → action.
4. Text and icons have enough contrast on black.
5. Focused, active, paused, completed and no-data states are designed.
6. Long names and changing numbers are tested (tabular digits, no layout shift).
7. Empty and unavailable data are handled.
8. Physical buttons work end to end (touch is optional).
9. No components overlap.
10. Animation does not disturb the timer or hide information.
11. Checked in the simulator and on a physical FR165.
12. Redraw rate and battery checked (profiler).

## Icons (`Icons.mc`)

- **Modules**: wind curls (Breathe), concentric rings (Mind), three waves (Circulate), runner (Mobility), crescent (Sleep), leaf (Recover, also the logo).
- **Metrics and controls**: lungs, clock, heart, check, chevron, phase markers ▲ and ▼, play, history bars, settings.
