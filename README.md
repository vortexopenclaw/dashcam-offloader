# Dashcam Offloader

Documentation-first planning repo for an open-source dashcam microSD-card offloader.

The purpose of this app is to automate and simplify moving dashcam footage from one or more microSD cards to the location the user chooses. The app should detect the camera model, classify footage by recording mode and camera channel, filter clips by date/type/channel, and copy them safely into an organized destination without modifying the source card.

Learning new dashcams supports that main offload workflow. A user should be able to choose a known model, choose a known but not-yet-supported model, or choose `Other`, describe their camera/channel setup, scan the card, and generate a sanitized intake package that can be used to add that dashcam to the profile library.

## Current Status

This project now has a first native macOS SwiftUI prototype in addition to the research/profile database. The app can load YAML profiles, scan a selected card or folder, detect likely dashcam profiles, classify clips, filter by mode/channel/date, preview selected files and size, copy to a chosen destination, show progress, skip matching duplicates, and write a local manifest.

The prototype is local-only and keeps source cards read-only. It does not download firmware, modify `/Volumes/`, or upload files.

The toolbar includes an `Updates` control for manual app update checks. It checks the public Cloudflare update manifest, compares the latest version against the current app bundle version, and can download/open the release asset for installation. Current unsigned prototype builds still require the user to replace the app bundle when macOS opens the downloaded archive or installer.

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

Internal test builds can be packaged without a paid Apple Developer ID. These builds should be treated as local/internal prototypes:

- Build Apple Silicon arm64.
- Ad-hoc sign the app to keep the bundle structurally valid.
- Zip the `.app` for sharing.
- On the receiving Mac, Gatekeeper may still require right-click Open or quarantine removal because the app is not Developer ID signed or notarized.

For public distribution without security warnings, use Developer ID signing and Apple notarization later.

Run the built-in scanner/planner smoke test:

```bash
swift run DashcamOffloader --smoke-test
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
- Copy manifest with source path, destination path, detected mode, detected channel, timestamp, size, and checksum status
- Clear progress and verification per card/job
- Sanitized profile-submission bundle for unsupported models, excluding private identifiers and video content by default

## Seed Profiles

**BlackVue**
- BlackVue DR970X Plus — 2CH, real card sampled
- BlackVue Elite 8 — 2CH, real card sampled
- BlackVue Elite 9 — 2CH, real card sampled

**Cansonic**
- Cansonic UltraDash Z3+ Standard Edition — dual front lens (wide + telephoto) + optional rear (R1), footage sampled

**Cobra**
- Cobra Road Scout — 1CH, real card sampled. Combined radar detector + dashcam.

**DJI**
- DJI Mini 3 Pro — 1CH drone, real card sampled

**Escort**
- Escort M1 — 1CH, real card sampled
- Escort M2 — 1CH, real card sampled
- Escort MAXcam 360c — 1CH, real card sampled. Combined radar detector + dashcam.

**Sony**
- Sony Alpha A7 III (ILCE-7M3) — 1CH mirrorless camera, real card sampled. Video + photos.

**Thinkware**
- Thinkware U3000 — 2CH, real card sampled
- Thinkware U3000 Pro — real card sampled

**Vantrue**
- Vantrue E1 Pro — 1CH, real card sampled
- Vantrue N4 Pro S — 3CH, real card sampled
- Vantrue N4 S — 3CH, real card sampled

**VIOFO**
- VIOFO A119 Mini 2 — 1CH, real card sampled
- VIOFO A119M Pro — 1CH, footage sampled
- VIOFO A139 Pro — 3CH, footage sampled
- VIOFO A229 Plus — 3CH, real card sampled
- VIOFO A229 Pro — 3CH, real card sampled
- VIOFO A229 Ultra — 3CH, footage sampled, OSD OCR confirmed
- VIOFO A329S — 3CH, real card sampled
- VIOFO A329T — telephoto variant, official references only

**Vueroid**
- Vueroid S1 4K Infinite — 1CH/2CH/3CH variants, all confirmed from real card samples

## Repository Layout

- `Package.swift` - Swift Package definition for the macOS prototype
- `Sources/DashcamOffloaderApp/` - SwiftUI app, scanner, detector, planner, copy engine, and manifest writer
- `scripts/build-macos-app.sh` - builds `build/Dashcam Offloader.app`
- `DESIGN.md` - product and technical design baseline
- `docs/project-plan.md` - phased build plan
- `docs/card-intake-checklist.md` - repeatable SD-card analysis checklist
- `docs/profile-schema.md` - camera profile format
- `docs/video-metadata-reference.md` - codec, resolution, bitrate, and fps reference across all cameras
- `docs/research/` - manual/source-link notes and research artifacts
- `docs/supported-cameras.md` - support status tracker
- `docs/card-profiles/` - human-readable camera notes
- `profiles/` - machine-readable camera profiles
