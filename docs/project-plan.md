# Project Plan

## Phase 1 - Documentation And Profiles

- Capture real SD-card folder trees.
- Capture representative filenames from every recording folder.
- Record official manual evidence for folder meanings.
- Store manual/source-link notes under `docs/research/`.
- Build one human-readable profile note per camera.
- Build one machine-readable YAML profile per camera.
- Document open questions per camera.

## Phase 2 - CLI Prototype

- Scan a source path.
- Detect the camera profile.
- Classify clips.
- Print a summary by mode, channel, and date range.
- Accept a user-selected destination path.
- Produce a copy manifest from source card to destination.
- Support dry-run copy planning.

## Phase 3 - Safe Copy Engine

- Copy selected clips to a destination folder.
- Preserve source files untouched.
- Skip duplicates.
- Resume interrupted jobs.
- Verify file size and optional checksum.
- Track copy progress and results per card.
- Export manifest as JSON and CSV.

## Phase 4 - Mac App

- Use `docs/prototype-build-brief.md` as the first Mac prototype handoff before implementation starts.
- Show mounted removable volumes.
- Allow manual source selection.
- Allow user-selected destination folders.
- Display detected camera and confidence evidence.
- Provide filters for camera channel, recording mode, date range, and protected/event clips, including user-saved emergency clips flagged by folder, filename, or file-level read-only protection.
- Run multiple card copy jobs at once.

## Phase 5 - Guided New-Camera Intake

- Offer a model picker with supported, known not-yet-supported, and `Other` options.
- Let users specify camera count and channel roles.
- Scan the card for folder structure, representative filenames, extensions, sizes, and date ranges.
- Redact private identifiers and exclude video content by default.
- Export a local sanitized intake bundle suitable for review.
- Support a later submission path such as GitHub issue, private upload, or manual file handoff.

## Phase 6 - Public Profile Library

- Accept community-submitted profiles.
- Add sample tree fixtures with private data redacted.
- Add validation tests for every profile.
- Document how to add a new dashcam model.
