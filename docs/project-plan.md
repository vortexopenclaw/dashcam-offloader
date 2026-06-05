# Project Plan

## Phase 1 - Documentation And Profiles

- Capture real SD-card folder trees.
- Capture representative filenames from every recording folder.
- Record official manual evidence for folder meanings.
- Build one human-readable profile note per camera.
- Build one machine-readable YAML profile per camera.
- Document open questions per camera.

## Phase 2 - CLI Prototype

- Scan a source path.
- Detect the camera profile.
- Classify clips.
- Print a summary by mode, channel, and date range.
- Produce a copy manifest.
- Support dry-run copy planning.

## Phase 3 - Safe Copy Engine

- Copy selected clips to a destination folder.
- Preserve source files untouched.
- Skip duplicates.
- Resume interrupted jobs.
- Verify file size and optional checksum.
- Export manifest as JSON and CSV.

## Phase 4 - Mac App

- Show mounted removable volumes.
- Allow manual source selection.
- Display detected camera and confidence evidence.
- Provide filters for camera channel, recording mode, date range, and protected/event clips.
- Run multiple card copy jobs at once.

## Phase 5 - Public Profile Library

- Accept community-submitted profiles.
- Add sample tree fixtures with private data redacted.
- Add validation tests for every profile.
- Document how to add a new dashcam model.

