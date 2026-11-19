# RESTORA Design System — "Calm Precision"

A quiet interface for intentional recovery. The navigation is calm and minimal. The session HUD is data-first, like a modern running watch: hairline dividers, small uppercase labels, big monospaced numerals and segmented bezel rings. RESTORA should not look like a small copy of Garmin Connect.

Code: `source/Utils/Theme.mc` (tokens), `source/UI/Hud.mc` (HUD primitives), `source/UI/Icons.mc` (module icons), `source/UI/MenuKit.mc` (lists). Mockups: `docs/mockups/`, rendered by `tools/mockups/`.

## Typography: Roboto Mono only

Every glyph is Roboto Mono. Mono digits keep timers from jittering as they count down. Connect IQ cannot load TTF files, so `tools/make_fonts.py` pre-renders bitmap fonts into `resources/fonts/`, anti-aliased.

| Token | Weight | px | Use | Glyphs |
|---|---|---|---|---|
| `Theme.label()` | Medium | 17 | uppercase labels, hints, table rows | ASCII |
| `Theme.body()` | Regular | 21 | exercise name, list rows | ASCII |
| `Theme.title()` | Bold | 27 | titles, phase word, field values | ASCII |
| `Theme.num()` | Bold | 50 | headline numbers (summary, week) | `0-9 : - / % .` |
| `Theme.hero()` | Bold | 100 | main timer | `0-9 :` |

The large fonts carry only digits, to save memory. `Theme.releaseLarge()` drops them after leaving the session screens. Roboto Mono is under the SIL OFL 1.1 licence (`tools/fonts/OFL.txt`).

Inter is the brand typeface for marketing material such as the store listing and slides. It is not used on the watch, which keeps a single font family.

## Colour

| Token | Hex | Role |
|---|---|---|
| `BG` | `#000000` | Canvas. AMOLED pixels are off, which saves battery |
| `DEEP` | `#142A22` | Deep Forest: focused row surface |
| `SURFACE` | `#243F33` | Forest: inactive ring segments, bars |
| `SAGE` | `#8FAF96` | Accent: labels, module name, active segment |
| `MINT` | `#C7DCC9` | Highlight: completed, active phase, START hint, ON |
| `IVORY` | `#F1EEE4` | Primary text and numbers |
| `GREY` | `#77847B` | Secondary text, field labels |
| `LINE` | `#2C3631` | Hairline dividers |
| `AMBER` | `#D9A441` | Paused |
| `ORANGE` / `RED` | `#E08A4F` / `#D9706A` | Warning / error |

There is one identity across all modules, with no colour per module. Modules are told apart by icon and name.

## Session HUD

Layout positions are per-mille of screen height (390 px on the FR165).

```
        ╭─ bezel: one segment per exercise, sized by duration ─╮
   110  20:27 ⦀                (clock + haptic mark)
   175  CIRCULATE  04/05        (module, step)
   220  LEGS UP THE WALL        (exercise)
   300  ─────────────────
   318  INHALE                  (breathing only, mint)
   470  03:24                   (hero timer; breathing: phase seconds "04")
   600  HOLD POSITION / RIGHT SIDE
   650  cue  |  NEXT: X (last 10 s)  |  PAUSED  |  START: NEXT
   700  ─────────────────
   712  LEFT 04:24  │  DONE 56%  (breathing: CYCLES │ LEFT)
```

- **Bezel ring** (6 px): the segments before the current one are mint, the current one fills in sage (amber when paused), and the later ones are forest. There is a 3° gap between segments.
- **Breathing ring** (10 px, inside the bezel): one segment per phase, sized by phase length, so 4-7-8 looks different from 4-4-4-4. Zero-length phases are skipped. The active phase fills in mint.
- **NEXT line**: in the last 10 s of an exercise, the cue line changes to `NEXT: <exercise>` in mint.
- **Paused**: the timer turns grey, the state line shows `PAUSED` in amber, and the active ring segment turns amber.
- Only the fields that matter for the exercise type are shown.

## Navigation

- Custom-drawn lists (`CustomMenu`) so lists can use Roboto Mono and icons. Rows are 64 px. The focused row is 104 px, on a Deep Forest rounded surface with a mint marker bar, and shows its subtitle.
- **Button-first**: START selects, starts and pauses; DOWN skips; BACK goes back or asks to end the session. A short mint arc at the 2 o'clock bezel position marks the START button wherever START has a meaning.
- Any session is at most 3 presses from Home.

## Module icons (vector, `Icons.mc`)

| Module | Motif | Character |
|---|---|---|
| BREATHE | wind lines with curls | flow |
| MIND | concentric rings | stillness |
| CIRCULATE | two flowing sine lines | circulation |
| MOBILITY | rising diagonal strokes + dot | movement |
| SLEEP | crescent | rest |
| RECOVER | leaf with midrib | restoration |

## Rules

- One main piece of information at a time. Avoid paragraphs; long text is cut to fit the round screen's chord at that height (`Theme.fit`, `Theme.chordHalf`).
- Every number shows its source (`GARMIN` / `RESTORA` calc). Missing data shows as `--`, never as an estimate.
- Motion is slow: the screen redraws once per second, with no continuous animation.
