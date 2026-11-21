# RESTORA release notes

## 1.0.0 — first release

- Six modules (Breathe, Mind, Circulate, Mobility, Sleep, Recover) with 33 guided sessions and 51 exercises, including a custom breathing pattern.
- Session engine driven by real time: countdown, optional rest between exercises, pause/resume, skip (DOWN), previous/restart (UP), manual or automatic advance, early end with confirmation.
- Animated anatomical exercise figures for all 36 movement exercises (side view, close-ups, and a 3/4 front view for neck, shoulder and chest work); breathing pacer for breathing exercises; Anatomy X-Ray style with the target muscle in red (classic grey figure in Settings); reduced-motion and low-detail options.
- Haptic cues for new exercise, side change and completion; breathing cues limited to about one per breath cycle.
- Optional heart rate and HRV (RMSSD from Garmin beat intervals), off by default.
- Session summary, weekly dashboard, and history with a detail page per session.
- Every metric labelled Garmin (measured) or RESTORA CALC (calculated); missing data shown as `--`.

### Known limits

- Mind and breathing exercises use the breathing ring and timer instead of a figure.
- Toe curls is drawn as a forefoot press and lift; individual toes are not modelled.
- HRV from the optical wrist sensor needs a still wrist; with too few clean beats it is shown as `--`.
