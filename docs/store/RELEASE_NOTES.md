# RESTORA release notes

## 1.0.0 — first release

- Six modules (Breathe, Mind, Circulate, Mobility, Sleep, Recover) with 27 guided sessions and 38 exercises.
- Session engine driven by real time: countdown, pause/resume, skip (DOWN), previous/restart (UP), manual or automatic advance, early end with confirmation.
- Animated anatomical exercise figures for 18 movements; breathing pacer for breathing exercises; reduced-motion and low-detail options.
- Haptic cues for new exercise, side change and completion; breathing cues limited to about one per breath cycle.
- Optional heart rate and HRV (RMSSD from Garmin beat intervals), off by default.
- Session summary, weekly dashboard, and history with a detail page per session.
- Every metric labelled Garmin (measured) or RESTORA CALC (calculated); missing data shown as `--`.

### Known limits

- Ankle circles, thoracic rotation, neck stretch, shoulder rolls/mobility, ankle mobility, toe curls and the mind and breathing exercises have no exercise figure yet; they run with the timer, cue and ring.
- HRV from the optical wrist sensor needs a still wrist; with too few clean beats it is shown as `--`.
