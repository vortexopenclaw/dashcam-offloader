# Dashcam Offloader

Documentation-first planning repo for an open-source dashcam SD-card offloader.

The goal is to make it easy to plug in one or more dashcam memory cards, detect the camera model, classify footage by recording mode and camera channel, filter clips by date/type, and copy them safely into an organized destination without modifying the source card.

The longer-term goal is for the Mac app to help learn new dashcams. A user should be able to choose a known model, choose a known but not-yet-supported model, or choose `Other`, describe their camera/channel setup, scan the card, and generate a sanitized intake package that can be used to add that dashcam to the profile library.

## Current Status

This project is in the research and profile-building phase. The first work is documenting real SD-card layouts and official manual references so the eventual app can be driven by camera profiles instead of hard-coded assumptions.

## Initial Scope

- macOS first
- Read-only SD-card inspection
- Multi-card offload workflow
- Guided intake for new or unsupported dashcam models
- Camera model detection from card metadata and file structure
- Recording mode classification
- Channel classification, such as front, rear, interior, telephoto
- Date/time parsing from filenames and metadata
- Event/protected/manual/emergency clip handling
- Copy manifest with source path, destination path, detected mode, detected channel, timestamp, size, and checksum status
- Sanitized profile-submission bundle for unsupported models, excluding private identifiers and video content by default

## Seed Profiles

- Thinkware U3000 Pro
- Vueroid S1 4K Infinite

Planned intake targets:

- BlackVue Elite 9 2CH
- Viofo A329S 3CH
- Vueroid S1 4K 3CH
- Vantrue N4 Pro S
- Viofo A229 Pro
- Thinkware U3000
- BlackVue DR970X Plus

## Repository Layout

- `DESIGN.md` - product and technical design baseline
- `docs/project-plan.md` - phased build plan
- `docs/card-intake-checklist.md` - repeatable SD-card analysis checklist
- `docs/profile-schema.md` - camera profile format
- `docs/supported-cameras.md` - support status tracker
- `docs/card-profiles/` - human-readable camera notes
- `profiles/` - machine-readable camera profiles
