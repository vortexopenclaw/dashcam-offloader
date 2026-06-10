# Agent Handoff

Last updated: 2026-06-10

This file is the cross-machine handoff source for agents working from GitHub. Do not rely on local OpenClaw memory as the only source of truth for important Dashcam Offloader state.

## Current Published Build

- Source of truth: the public update manifest contains the current published build hash, asset name, SHA-256, and release timestamp.
- Manifest: <https://dashcam-offloader-updates.vortexradar.workers.dev/dashcam-offloader/latest.json>
- Direct Cloudflare download: <https://dashcam-offloader-updates.vortexradar.workers.dev/dashcam-offloader/download/latest>
- GitHub releases carry the packaged ZIP artifacts.

## GitHub Publishing

Pushes to `main` run `.github/workflows/release.yml`, which builds the app, replaces the `latest` GitHub release, uploads the ZIP and `latest.json` to the `dashcam-offloader-updates` Cloudflare R2 bucket, and deploys `workers/updates/wrangler.toml`.

Before publishing, update `docs/releases/latest.md` with short, user-facing notes for the current build. Keep it relative to the latest build, not a rolling changelog. Write about new features and benefits, not implementation details; it is fine to say "bug fixes" instead of listing every fix. Put older context in docs or memory, not in the GitHub `latest` release body. The release workflow uses this file for the GitHub `latest` release body and embeds the same text in the Cloudflare update manifest as `releaseNotes`, so the in-app Release Notes/What's New UI has real content.

The workflow uses encrypted GitHub secrets:

- `CLOUDFLARE_DASHCAM_OFFLOADER_TOKEN`
- `CLOUDFLARE_DASHCAM_OFFLOADER_ACCOUNT_ID`

These were refreshed from the local OpenClaw Cloudflare credentials on 2026-06-09. Do not commit Cloudflare credentials to the repo or print them in logs.

## Verify Before Publishing

Run these from the repo root:

```bash
swift build
swift run DashcamOffloader --verify
scripts/build-macos-app.sh
build/Dashcam\ Offloader.app/Contents/MacOS/DashcamOffloader --verify
node --check workers/feedback/worker.js
python3 -m py_compile scripts/review-feedback-submissions.py
git diff --check
```

When the user says "build", "publish", "push a release", "new build", or similar for Dashcam Offloader, use the full standard release path unless they explicitly ask for a local-only build: verify, push the intended commit, publish through GitHub Actions, verify the GitHub `latest` release asset, and verify the Cloudflare latest manifest/download. If the Actions release step fails after the app package is built, repair GitHub with local authenticated `gh` and verify both GitHub and Cloudflare instead of leaving only one side published.

When fixing the updater, verify it replaces the launched `.app` in place and relaunches. If the launched bundle path is not writable, the updater should reveal the downloaded replacement instead of silently staging a mystery app.

Do not ship a `.command` file as the quarantine-clearing helper. macOS can quarantine that helper too and show a scary "Apple could not verify" warning. Use the AppleScript launcher source at `scripts/open-dashcam-offloader.applescript`; release ZIPs should include `Open Dashcam Offloader.applescript` and a compiled `Open Dashcam Offloader.app` beside `Dashcam Offloader.app`.

## Submission Review

Use `scripts/review-feedback-submissions.py` to inspect Cloudflare KV submissions. It loads credentials through the workspace env loader and checks `CLOUDFLARE_DASHCAM_OFFLOADER_TOKEN` first, then `CLOUDFLARE_WORKERS_API_TOKEN`.

Useful commands:

```bash
scripts/review-feedback-submissions.py list --date 2026-06-09
scripts/review-feedback-submissions.py search Botslab --date 2026-06-09
scripts/review-feedback-submissions.py search ULTRADASH --date 2026-06-09
scripts/review-feedback-submissions.py get feedback/2026-06-09/<submission-id>.json
```

Submissions should include `appVersion`, `identifiedCamera`, selected profile/candidates/evidence, diagnostics, folder summaries, file sizes, setting snapshots, video spec samples, and video spec summaries. The Worker currently accepts up to 1 MB and stores up to 64 video spec samples plus 120 video spec summaries.

## Current Scanner Rules

- UI-facing manufacturer display must use Ariel's preferred casing: `Blackvue`, `Viofo`, `DJI`, and `GoPro`. Do not show `BlackVue` in the model picker or identified-camera UI, even when source folders, docs, or official brand pages use that spelling.
- Prefer explicit model evidence over folders: model strings, safe config fragments, OSD proof, distinctive filename/channel tokens, and known marker files.
- Folder-only evidence can identify a family or brand, but should not force a specific sibling model.
- Same-brand sibling guard: when multiple profiles match shared structure and there is no distinctive model clue, fall back to `generic-new-dashcam`.
- Volume labels are weak evidence only.
- App submissions should get close to what a direct mounted-card read can gather, without uploading video/photo bytes, GPS traces, serials, Wi-Fi/cloud fields, device IDs, full config dumps, or other private identifiers.
- Generic/unknown dashcam import must stay useful for transfer even when exact model detection is not safe.
- Recording type and channel checkboxes rebuild the download plan immediately, so deselecting all recording types or all channels clears the review/download queue instead of leaving stale rows visible.
- GoPro cards should be identified from safe `MISC/version.txt` model/firmware fields when present. Do not use stale/mutable volume labels as proof; user cards can be named after a previous camera.
- GoPro media can span `DCIM/100GOPRO`, `DCIM/101GOPRO`, and later numbered folders. Scan every matching `DCIM/*GOPRO` folder.
- Generic unknown-camera scanning should gather useful structure, filename patterns, mode/channel counts, file-size ranges, and sampled media metadata while excluding video/photo bytes, GPS traces, serials, Wi-Fi/cloud fields, and private identifiers.

## Recent Camera Notes

- **Cansonic UltraDash Z4 Standard Edition**
  - Profile: `profiles/cansonic-ultradash-z4-standard.yaml`
  - Evidence: app submissions plus direct card reads from `/Volumes/ULTRADASH`.
  - Layout: `VIDEO/` driving clips and `PROTECTED/` P-prefixed parking clips.
  - Channels: `L` front, `R` front telephoto, `B` rear.
  - Video: L/R 3840x2160 H.264 30fps, B 2560x1440 H.264 30fps.
  - Parking: observed sentry motion/impact sample and timelapse sample. Do not label every protected clip as impact; infer from timing, continuity, duration, and specs when config evidence is absent.

- **Botslab G980H**
  - Profile: `profiles/botslab-g980h.yaml`
  - Evidence: app submission plus direct card read from `/Volumes/NO NAME`.
  - Layout: `360CARDVR/REC`, `360CARDVR/PARKING`, `360CARDVR/GPS`.
  - High-confidence marker: `MISC/G980HMCN5291.TXT`.
  - Channels: `AA` front, `AB` rear, `AC` left, `AD` right.
  - Generic 360CARDVR cards should appear in Sources, but remain new/unrecognized unless exact model evidence is present.

- **VIOFO A329T**
  - A329T no longer misidentifies as A229 Plus when telephoto `T/PT` filename evidence is present.
  - A229-family folder evidence alone is not enough to force an A229 sibling.

- **Vueroid H1**
  - Detects from `CONFIG/config.bin` model text like `H1-QHD-INFINITE`.
  - Treat as 1CH/front-only from H1 evidence.

- **GoPro HERO / MAX / Mission family**
  - Profiles: `profiles/gopro-hero9-black.yaml`, `profiles/gopro-hero-action-camera.yaml`
  - Docs: `docs/card-profiles/gopro-hero9-black.md`, `docs/card-profiles/gopro-hero-action-camera.md`
  - HERO9 Black was validated from two real cards that both had stale `U3000PRO` volume labels.
  - Safe evidence: `MISC/version.txt` `camera type` and `firmware version`.
  - Private fields in `version.txt` must not be submitted or documented.
  - Default GoPro transfer categories should include regular/continuous and looping videos; Time Lapse, TimeWarp, and photos should be visible but unchecked by default.

## UX Preferences Captured In Repo

- Do not post ZIP files directly to chat by default. Publish to Cloudflare/GitHub and send the direct Cloudflare link.
- Use "verification" wording, not "smoke test."
- Keep generated manifests out of the default user workflow.
- Download destination should not default to model/date/channel nested folders unless the user asks for it.
- Source cards should disappear after eject without restarting, and Refresh Sources should rescan mounted cards.
- The main app window should appear before mounted-card scans and permission prompts block the user.
- Improve Camera Support should be draggable. Camera channel examples should be placeholder text, not prefilled white text.
- Filter changes should not leave stale items in Review and Download when the selected modes/channels become empty.
