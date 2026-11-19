# RESTORA Design System — Sport-tech Recovery

RESTORA uses running-watch instrumentation (structured data, segmented progress, high contrast) applied to recovery practice. It is a recovery app with a sport-tech character, not a soft meditation app.

Code: `source/Utils/Theme.mc` (tokens), `source/UI/Hud.mc` (ring and bar), `source/UI/Icons.mc` (vector icons), `source/UI/MenuKit.mc` (lists). Mockups: `docs/mockups/`, rendered by `tools/mockups/`.

## Typography: Roboto Condensed

The type is condensed and firm, so more data fits across the round screen. Roboto Condensed digits are tabular, so timers do not jitter. Connect IQ cannot load TTF files, so `tools/make_fonts.py` pre-renders bitmap fonts from the variable font (`tools/fonts/RobotoCondensed-VF.ttf`, SIL OFL 1.1) into `resources/fonts/`.

| Token | Weight | px | Use |
|---|---|---|---|
| `Theme.label()` | Medium | 15 | small UPPERCASE labels (`STARTS IN`, `SESSIONS`) |
| `Theme.small()` | Regular | 17 | subtitles, cues, table rows |
| `Theme.body()` | Medium | 20 | list names, info row, clock |
| `Theme.title()` | Bold | 24 | titles, phase word, metric values, pills |
| `Theme.num()` | Bold | 40 | headline numbers (digits only) |
| `Theme.hero()` | Bold | 60 | timer inside the HUD ring (digits only) |

The text fonts include `·`, `↑` and `↓`. Names are in sentence case ("Leg Relief"); small labels are in UPPERCASE.

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

- Line widths come from the safe circle at that height. Text that is too wide drops to a smaller font, and only then is cut (`Theme.fitLine`).
- Exercise names are at most 22 characters and cues at most 26 (`testContentFitsHud`).
- `node tools/mockups/render.js` runs the **layout check**. It flags any ink box outside the safe circle, any box touching the HUD ring, and any two boxes that overlap. It must print `layout check: no issues`.

## Screens

### Home and lists (`MenuKit`)

- Header: green leaf logo, **RESTORA**, `RECOVERY COMPANION`.
- Rows are 88 px: an icon (x 84), the name, a grey subtitle, and a chevron or a value on the right.
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

## Interaction

- **Button-first**: START selects, starts and pauses; DOWN skips; BACK goes back or asks to end the session.
- A green arc at the 2 o'clock bezel position marks START wherever START has a meaning.
- Any session is at most 3 presses from Home.

## Icons (`Icons.mc`)

- **Modules**: wind curls (Breathe), concentric rings (Mind), three waves (Circulate), runner (Mobility), crescent (Sleep), leaf (Recover, also the logo).
- **Metrics and controls**: lungs, clock, heart, check, chevron, phase markers ▲ and ▼, play, history bars, settings.
