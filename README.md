# Dashcam Offloader

Documentation-first planning repo for an open-source dashcam microSD-card offloader.

The purpose of this app is to automate and simplify moving dashcam footage from one or more microSD cards to the location the user chooses. The app should detect the camera model, classify footage by recording mode and camera channel, filter clips by date/type/channel, and copy them safely into an organized destination without modifying the source card.

Learning new dashcams supports that main offload workflow. A user should be able to choose a known model, choose a known but not-yet-supported model, or choose `Other`, describe their camera/channel setup, scan the card, and generate a sanitized intake package that can be used to add that dashcam to the profile library.

## License and Branding

Dashcam Offloader is open source under the GNU Affero General Public License v3.0. You can inspect, use, modify, and share the code under the terms of the AGPLv3. Modified versions that are distributed or offered as a network service must preserve the same license freedoms and make their corresponding source available.

Copyright (c) 2026 Vortex Radar.

The Vortex Radar name, Vortex Radar logo, Dashcam Offloader name, Dashcam Offloader app icon, and related branding are not licensed for reuse by forks, ports, hosted services, or unofficial builds. See [TRADEMARKS.md](TRADEMARKS.md) for branding guidance.

Official builds are published by Vortex Radar. Unofficial builds, forks, ports, and hosted services should use their own names and clearly state that they are not official Vortex Radar releases.

## Current Status

This project now has a first native macOS SwiftUI prototype in addition to the research/profile database. The app can load YAML profiles, scan a selected card or folder, detect likely dashcam profiles, classify clips, filter by mode/channel/date presets, preview and trim the download queue, copy to a chosen destination, organize downloads into one folder or by clip type, date, or camera, optionally append custom text to copied video filenames, optionally preserve camera settings/log files, show progress, stop an active download, skip matching duplicates, check/install app updates, submit feedback, and submit card-learning packages for new cameras or supported cameras with unobserved setups.

The prototype is local-only and keeps source cards read-only. It does not download firmware, modify `/Volumes/`, or upload files.

Firmware filename knowledge is maintainer research only: public firmware downloads may be inspected outside the app to learn filename patterns, but the Mac app only compares filenames already present on a card as weak bonus evidence.

## Run The Prototype

From the repo root:

```bash
swift run DashcamOffloader
```

Build a launchable app bundle:

```bash
scripts/build-macos-app.sh
open "build/Dashcam Offloader.app"
```

Build the latest version from `origin/main` in a clean detached worktree:

```bash
scripts/build-latest-macos-app.sh
open "build-latest/Dashcam Offloader.app"
```

The app checks the Cloudflare update manifest on launch when automatic update checks are enabled. Users can also choose **Check for Updates** in the toolbar, then install an available ZIP update directly from the prompt.

Update metadata is published through `docs/releases/latest.md`. That file becomes the GitHub `latest` release body and is also included in the Cloudflare update manifest so the app can link users to release notes without crowding the update prompt.

Internal test builds can be packaged without a paid Apple Developer ID. These builds should be treated as local/internal prototypes:

- Build Apple Silicon arm64.
- Ad-hoc sign the app to keep the bundle structurally valid.
- Zip the `.app` for sharing.
- On the receiving Mac, Gatekeeper may still require right-click Open or quarantine removal because the app is not Developer ID signed or notarized.

For public distribution without security warnings, use Developer ID signing and Apple notarization later. Release ZIPs include only `Dashcam Offloader.app`. Do not ship quarantine-clearing helper apps or scripts in the ZIP because macOS can quarantine those helpers too before they can run.

Run the built-in scanner/planner verification test:

```bash
swift run DashcamOffloader --verify
```

## Initial Scope

- macOS first
- Read-only SD-card inspection
- User-selected local or external destination
- Multiple dashcam cards mounted and offloaded in one workflow
- Guided intake for new or unsupported dashcam models
- Camera model detection from card metadata and file structure
- Recording mode classification
- Channel classification, such as front, rear, interior, telephoto
- Date/time parsing from filenames and metadata
- Event/protected/manual/emergency clip handling
- Optional video filename suffix inserted before the original extension
- Output organization modes: one folder, by clip type, by date, or by camera
- Optional camera settings/log copy for troubleshooting, stored separately from copied footage
- Editable review queue before download
- Clear progress and verification per card/job
- Learn Card workflow for new models and alternate known-camera setups, excluding private identifiers and video content by default
- Feedback submission for bug reports, feature requests, card learning, and optional sanitized scan summaries

## Supported Cameras

The app currently ships 52 camera profiles. “Supported” means the app has a
profile that can safely identify or classify that camera's media. Exact
automatic model recognition requires unique on-card evidence; where that is
not yet available, the profile remains available for manual selection. See
[the detailed support status](docs/supported-cameras.md) for the evidence and
limitations of each profile.

**Botslab**
- Botslab G980H: 4CH, app submission and real card sampled. Detected from `MISC/G980HMCN5291.TXT`; generic `360CARDVR` cards should remain unrecognized unless exact model evidence is present.

**70mai**
- 70mai M310: 1CH, real card and archive samples
- 70mai 4K Omni X800: 2CH, app submission and real card sampled
- 70mai T800: 3CH, app submissions and real card samples

**BlackVue**
- BlackVue DR770X Box: 3CH, app submission and archive samples
- BlackVue DR970X Plus: 2CH, real card sampled
- BlackVue Elite 8: 2CH, real card sampled
- BlackVue Elite 9: 2CH, real card sampled

**Cansonic**
- Cansonic UltraDash Z3+ Standard Edition: dual front lens (wide + telephoto) + optional rear (R1), footage sampled
- Cansonic UltraDash Z4 Standard Edition: 3CH, app submission and real card sampled. Uses `VIDEO/` driving clips and `PROTECTED/` P-prefixed protected parking clips.

**Cobra**
- Cobra Road Scout: 1CH, real card sampled. Combined radar detector + dashcam.

**DJI**
- DJI Mini 3 Pro: 1CH drone, real card sampled
- DJI RC (RM330): companion device (remote controller), real card sampled. Controller microSD only; full-res drone footage is on the drone's own card.

**GoPro**
- GoPro HERO9 Black: 1CH action camera, real cards sampled
- GoPro HERO / MAX Camera: generic GoPro fallback profile

**Escort**
- Escort M1: 1CH, real card sampled
- Escort M2: 1CH, real card sampled
- Escort MAXcam 360c: 1CH, real card sampled. Combined radar detector + dashcam.

**Nextbase**
- Nextbase 622GW: front/rear filename pattern profile

**Ottocast**
- Ottocast OttoSafe Cam: front/rear normal and emergency clips classified

**Rove**
- Rove R2-4K Pro: 1CH, app submission and documentation

**Sony**
- Sony A7 III (ILCE-7M3): 1CH mirrorless camera, real card sampled. Video + photos.

**Tesla**
- TeslaCam: generic Tesla dashcam profile

**Thinkware**
- Thinkware ARC 700: 2CH, manual-backed profile. Manual selection until a real card provides exact detection evidence.
- Thinkware ARC 800: 2CH, validated real-card profile with safe `ARC800` metadata recognition. Supports documented 4K30 and QHD60 Front configurations.
- Thinkware ARC 900: 2CH, manual-backed profile. Manual selection until a real card provides exact detection evidence.
- Thinkware U3000: 2CH, real card sampled
- Thinkware U3000 Pro: real card sampled
- Thinkware U1000: front/rear filename pattern profile
- Thinkware U1000 Plus: front/rear filename pattern profile

**Vantrue**
- Vantrue E1 Pro: 1CH, real card sampled
- Vantrue E360: multi-channel filename pattern profile
- Vantrue N4: 3CH filename pattern profile
- Vantrue N4 Pro S: 3CH, real card sampled
- Vantrue N4 S: 3CH, real card sampled
- Vantrue N5: 4CH filename pattern profile

**VIOFO**
- VIOFO A119 Mini 2: 1CH, real card sampled
- VIOFO A119M Pro: 1CH, footage sampled
- VIOFO A129 Duo: 2CH filename pattern profile
- VIOFO A129 Plus Duo: 2CH filename pattern profile
- VIOFO A129 Pro: 2CH filename pattern profile
- VIOFO A139 Pro: 3CH, footage sampled
- VIOFO A229 Plus: 3CH, real card sampled
- VIOFO A229 Pro: 3CH, real card sampled
- VIOFO A229 Ultra: 3CH, footage sampled, OSD OCR confirmed
- VIOFO A329S: 3CH, real card sampled
- VIOFO A329T: telephoto variant, official references only
- VIOFO T130: 3CH filename pattern profile
- VIOFO VS1: 1CH filename pattern profile
- VIOFO WM1: 1CH filename pattern profile

**Vueroid**
- Vueroid H1: 1CH front variant, confirmed from app submission and real card sample
- Vueroid S1 4K Infinite: 1CH/2CH/3CH variants, all confirmed from real card samples

## Repository Layout

- `Package.swift` - Swift Package definition for the macOS prototype
- `Sources/DashcamOffloaderApp/` - SwiftUI app, scanner, detector, planner, and copy engine
- `scripts/build-macos-app.sh` - builds `build/Dashcam Offloader.app`
- `scripts/open-dashcam-offloader.applescript` - local-only helper source for maintainers; do not ship it or a compiled launcher in release ZIPs
- `DESIGN.md` - product and technical design baseline
- `docs/agent-handoff.md` - cross-machine handoff notes for future agents
- `docs/project-plan.md` - phased build plan
- `docs/card-intake-checklist.md` - repeatable SD-card analysis checklist
- `docs/profile-schema.md` - camera profile format
- `docs/video-metadata-reference.md` - codec, resolution, bitrate, and fps reference across all cameras
- `docs/research/` - manual/source-link notes and research artifacts
- `docs/supported-cameras.md` - support status tracker
- `docs/card-profiles/` - human-readable camera notes
- `profiles/` - machine-readable camera profiles
- `scripts/review-feedback-submissions.py` - private Cloudflare submission review helper
- `workers/feedback/` - Cloudflare Worker endpoint for feedback submissions

## Feedback And Card Learning Endpoint

The app includes Feedback and Learn Card buttons in the toolbar. Users can submit bug reports, feature requests, or other feedback. When a source has already been scanned, they can choose to include a sanitized scan summary.

Learn Card submissions ask for manufacturer, model, camera channel count, what each channel records, optional notes, and optional contact. They attach a sanitized description of the card structure so new camera support can be added or existing camera support can be expanded for different channel layouts, parking modes, resolutions, bitrates, firmware, and recording settings.

Scan statistics are opt-in for ordinary feedback and are included for explicit camera-learning submissions. They include aggregate counts, camera-profile candidates, sanitized setting fields, and aggregate media technical summaries. They never include source names, folder paths, filenames, videos, photos, GPS traces, serial numbers, Wi-Fi details, device IDs, or full settings dumps.

Privacy policy: https://dashcam-offloader-updates.vortexradar.workers.dev/dashcam-offloader/privacy

The receiving Cloudflare Worker scaffold lives in `workers/feedback/`. Configure either an R2 bucket binding named `FEEDBACK_BUCKET` or a KV namespace binding named `FEEDBACK_KV`, then deploy the Worker.

Maintainers can review private stored submissions with `scripts/review-feedback-submissions.py`. It loads Cloudflare credentials from the OpenClaw workspace environment and redacts contact fields in output.
