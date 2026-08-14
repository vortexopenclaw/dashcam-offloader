# Agent Handoff

Last updated: 2026-06-12

This file is the cross-machine handoff source for agents working from GitHub. Do not rely on local OpenClaw memory as the only source of truth for important Dashcam Offloader state.

## Current Published Build

- Source of truth: the public update manifest contains the current published build hash, asset name, SHA-256, and release timestamp.
- Manifest: <https://dashcam-offloader-updates.vortexradar.workers.dev/dashcam-offloader/latest.json>
- Direct Cloudflare download: <https://dashcam-offloader-updates.vortexradar.workers.dev/dashcam-offloader/download/latest>
- GitHub releases carry the packaged ZIP artifacts.

## GitHub Publishing

Pushes to `main` run `.github/workflows/release.yml`, which builds the app, creates and verifies the signed update manifest against the packaged app's embedded public key plus exact bundle version/commit, stages the ZIP in the `dashcam-offloader-updates` Cloudflare R2 bucket, deploys `workers/updates/wrangler.toml`, replaces the GitHub `latest` release, and activates the update by uploading `latest.json` last. Missing or mismatched update credentials fail before any public write.

The GitHub `latest` release is intentionally deleted and recreated on each publish after the lightweight `latest` tag is moved. Do not change this back to `gh release edit` plus asset replacement: GitHub preserves the old `published_at` timestamp when editing a release, and the release page age is used as an at-a-glance freshness check.

Before publishing, update `docs/releases/latest.md` with short, user-facing notes for the current build. Keep it relative to the latest build, not a rolling changelog. Write about new features and benefits, not implementation details; it is fine to say "bug fixes" instead of listing every fix. Put older context in docs or memory, not in the GitHub `latest` release body. The release workflow uses this file for the GitHub `latest` release body and embeds the same text in the Cloudflare update manifest as `releaseNotes`. The app should link to release notes from update UI instead of showing the notes inline in the update prompt.

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

Feature branches run the same list automatically through `.github/workflows/verify.yml`, which posts a legacy commit status (context `verify`) so API clients that cannot read the Checks API can still see pass/fail.

When the user says "build", "publish", "push a release", "new build", or similar for Dashcam Offloader, use the full standard release path unless they explicitly ask for a local-only build: verify, push the intended commit, publish through GitHub Actions, verify the GitHub `latest` release asset, and verify the Cloudflare latest manifest/download. If the Actions release step fails after the app package is built, repair GitHub with local authenticated `gh` and verify both GitHub and Cloudflare instead of leaving only one side published.

When fixing the updater, verify it replaces the launched `.app` in place and relaunches. If the launched bundle path is not writable, the updater should reveal the downloaded replacement instead of silently staging a mystery app.

Do not ship quarantine-clearing helpers in release ZIPs. macOS can quarantine `.command` files, raw `.applescript` files, and compiled helper apps, then block the helper before it can clear quarantine from `Dashcam Offloader.app`. Release ZIPs should include only `Dashcam Offloader.app` until Developer ID signing and notarization are in place.

## Submission Review

Use `scripts/review-feedback-submissions.py` to inspect Cloudflare KV submissions. It loads credentials through the workspace env loader and checks `CLOUDFLARE_DASHCAM_OFFLOADER_TOKEN` first, then `CLOUDFLARE_WORKERS_API_TOKEN`.

Useful commands:

```bash
scripts/review-feedback-submissions.py list --date 2026-06-09
scripts/review-feedback-submissions.py search Botslab --date 2026-06-09
scripts/review-feedback-submissions.py search ULTRADASH --date 2026-06-09
scripts/review-feedback-submissions.py get feedback/2026-06-09/<submission-id>.json
```

Submissions should include `appVersion`, `identifiedCamera`, selected profile/candidates/evidence, diagnostics, directory summaries, folder summaries, file sizes, setting snapshots, video spec samples, and video spec summaries. Directory summaries are the expected way to preserve empty folders, placeholder-only folders, hidden camera folders, child directory counts, and per-folder extension counts without uploading media. The Worker currently accepts up to 1 MB and stores up to 64 video spec samples plus 120 video spec summaries.

## Current Scanner Rules

- UI-facing manufacturer display uses the product's preferred casing: `Blackvue`, `Viofo`, `DJI`, and `GoPro`. Do not show `BlackVue` in the model picker or identified-camera UI, even when source folders, docs, or official brand pages use that spelling.
- Prefer explicit model evidence over folders: model strings, safe config fragments, OSD proof, distinctive filename/channel tokens, and known marker files.
- Folder-only evidence can identify a family or brand, but should not force a specific sibling model.
- Same-brand sibling guard: when multiple profiles match shared structure and there is no distinctive model clue, fall back to `generic-new-dashcam`.
- Safe model metadata should improve generic/unknown-card identity, not just train individual profiles. Current safe metadata recognizers include BlackVue `BlackVue/Config` model files, GoPro `MISC/version.txt`, Thinkware `SETTING/lang/ver.dat` or model-coded settings executables, Vantrue model-coded settings filenames, Miofive/Wolfbox common model/version support files, and Sony XAVC XML model fields. If metadata identifies a known catalog model but no trained profile matches exactly, keep the card on the generic import path and show the known model as unsupported/untrained.
- Volume labels are weak evidence only.
- App submissions should get close to what a direct mounted-card read can gather, without uploading video/photo bytes, GPS traces, serials, Wi-Fi/cloud fields, device IDs, full config dumps, or other private identifiers.
- Generic/unknown dashcam import must stay useful for transfer even when exact model detection is not safe.
- Recording type and channel checkboxes rebuild the download plan immediately, so deselecting all recording types or all channels clears the review/download queue instead of leaving stale rows visible.
- GoPro cards should be identified from safe `MISC/version.txt` model/firmware fields when present. Do not use stale/mutable volume labels as proof; user cards can be named after a previous camera.
- GoPro media can span `DCIM/100GOPRO`, `DCIM/101GOPRO`, and later numbered folders. Scan every matching `DCIM/*GOPRO` folder.
- Generic unknown-camera scanning should gather useful structure, directory manifests including empty/placeholder-only folders, filename patterns, mode/channel counts, file-size ranges, and sampled media metadata while excluding video/photo bytes, GPS traces, serials, Wi-Fi/cloud fields, and private identifiers.

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
  - Detected GoPro loop groups offer a user-facing output choice in What to Download: original clips only, original clips + merged clip, or merged clip only (default). The choice lives in `FilterState.goProLoopGroupOutput`, is applied in `CopyPlanner.groupedDownloadItems`, and resets to merged-only on each new scan. The picker appears only when the scanned card actually contains loop groups.

## UX Preferences Captured In Repo

- Do not post ZIP files directly to chat by default. Publish to Cloudflare/GitHub and send the direct Cloudflare link.
- Use "verification" wording, not "smoke test."
- Keep generated manifests out of the default user workflow.
- Download destination should not default to model/date/channel nested folders unless the user asks for it.
- Source cards should disappear after eject without restarting, and Refresh Sources should rescan mounted cards.
- The main app window should appear before mounted-card scans and permission prompts block the user.
- Improve Camera Support should be draggable. Camera channel examples should be placeholder text, not prefilled white text.
- Filter changes should not leave stale items in Review and Download when the selected modes/channels become empty.
- Destination files are never overwritten. A same-name file at the destination means "already downloaded": single copies and merged loop exports skip it and report "already in destination" instead of failing. Product rule: there should never be two different files with identical names, so no size comparison or rename fallback is needed.
- The review queue flags how many queued files already exist at the chosen destination before downloading. The Last Run summary shows copied count/size, already-in-destination count, failed count, the destination path, and a Retry Failed action.
- Download organization is controlled by `FilterState.outputOrganizationMode`: `oneFolder`, `byClipType` default, `byDate`, or `byCamera`. Date folders must preserve rough filesystem dates and suspicious camera-clock labels instead of flattening them into normal dates.
