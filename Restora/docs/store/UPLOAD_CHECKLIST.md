# RESTORA 1.0.0 — Connect IQ Store upload checklist

Everything the project can provide is ready. The steps marked **You** need your Garmin account and your private signing key.

## 1. Before the upload

- [ ] **You** — Manual tests on a physical Forerunner 165 pass (see the test list in `HANDOVER.md` / the last report).
- [ ] **You** — Create the permanent signing key once and back it up in two places (not in the repo, not in a public folder):
      `powershell -File tools\release.ps1 -NewKey C:\Keys\restora_release_key.der`
      Losing this key means the Store app can never be updated.
- [ ] Build the release package with that key (runs the unit tests first):
      `powershell -File tools\release.ps1 -Key C:\Keys\restora_release_key.der`
      Output: `dist\RESTORA-1.0.0.iq`.

## 2. Upload (developer.garmin.com → Connect IQ → Upload an app)

| Field | Use |
|---|---|
| App file | `dist\RESTORA-1.0.0.iq` |
| App type | Watch app (from the manifest) |
| Devices | Forerunner 165, Forerunner 165 Music (from the manifest) |
| Title | RESTORA |
| Category | Health & Fitness |
| Price | Free |
| Short description | `docs/store/STORE_LISTING.md` → Short description |
| Description | `docs/store/STORE_LISTING.md` → Description, followed by the Disclaimer paragraph |
| What's new | `docs/store/RELEASE_NOTES.md` → 1.0.0 |
| App icon | `docs/store/icons/icon-512.png` (also `icon-1024.png`, `icon-512-transparent.png`); use the size the upload form asks for |
| Screenshots | `docs/store/screenshots/*.png` — 10 raw 390 × 390 screens from the simulator (home, module, detail, breathing, summary, end-session, side figure, hip figure, 3/4 front figure, countdown) |
| Framed screenshots | `docs/store/marketing/screen-01..08-1080x1080.png` — each screen in a round watch frame with a caption |
| Cover / hero / banner | `docs/store/marketing/hero-1920x1080.png`, `cover-1440x720.png`, `feature-1024x500.png`, `square-1080.png`; use the size the form asks for, or crop from the hero |
| Privacy | Text of `docs/store/PRIVACY.md` (RESTORA collects nothing; data stays on the watch). If the form asks for a URL, decide where to host the text; the repo is private. |
| Permissions shown to users | Sensor — heart rate and beat intervals, only when *HR & HRV* is on (off by default) |
| **You** — Developer contact | The support e-mail you want public |

## 3. After the upload

- [ ] Wait for Garmin's review (usually a few days). If rejected, read the reason, fix, bump the version in `manifest.xml` if the Store asks for it, rebuild with the same key, re-upload.
- [ ] **You** — Install RESTORA from the Store on the watch and run one session (final install test).
- [ ] Keep `dist\RESTORA-1.0.0.iq` and the key backup together with the release notes.

## 4. Regenerating the images

- Screens change: retake the 390 × 390 screenshots into `docs/store/screenshots/` (same file names).
- Then `python tools/store/make_store_images.py` rebuilds everything in `docs/store/marketing/`. The watch frame is a generic round bezel drawn by the script (no Garmin device artwork).

## 5. Next versions

1. Change code, raise `version` in `manifest.xml` (e.g. 1.0.1), add a section to `RELEASE_NOTES.md`.
2. `powershell -File tools\release.ps1 -Key <same permanent key>`
3. Upload the new `.iq` as an update of the same app.
