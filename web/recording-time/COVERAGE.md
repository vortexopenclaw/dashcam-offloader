# Calculator coverage audit — September 8, 2026

Calculator: **85 model presets**. This is not complete app-catalog coverage.

Compared all 262 explicit model entries in `KnownDashcamCatalog.swift` from the current main checkout and all 68 JSON profiles in the maintained `dashcam-camera-profiles` checkout. Catalog source SHA-256: `7862feb183b26317bff161df3fdb9da1040d093ca279a03c26860bea6791a10b`.

Matching uses case/punctuation normalization, documented app aliases, channel-package suffixes, and the Cansonic “Standard Edition” name. It does not merge Plus, Pro, LTE, Commercial, or numbered-generation variants.

The app catalog includes non-dashcams and entries without recording-rate evidence. A supported card layout, resolution, or file-naming pattern does not establish storage consumption. “Missing” below means unavailable in the reviewed local recording-rate data, not that exhaustive manufacturer research proved no data exists.

## Current counts

### App catalog

- Excluded: unreleased: 1
- Included: 65
- Missing: catalog-only or variant: 166
- Missing: profile lacks driving rates: 4
- Outside dashcam scope: 26

### Maintained profile

- Excluded: unreleased: 1
- Included: 57
- Missing: parking-only rates: 1
- Missing: profile lacks driving rates: 4
- Outside dashcam scope: 5

### Calculator additional model

- Included: 21

## Original-submission audit and recovery

Retrieved all 50 records currently in the feedback namespace. Retained 264 anonymous paired driving-file measurements and 96 driving summary groups in `storage-evidence.json`, mirrored from the canonical profile repository. These include repeated scans, unknown channels and interrupted clips: they are evidence counts, not unique camera counts.

- Added Botslab G980H (measured 2880x1620 Front, 1080p Left/Right/Rear at 25 fps), Ottocast OttoSafe Cam, Thinkware FA200 and Thinkware ARC 800.
- FA200: each full 60.06-second channel file occupies 83,886,080 bytes despite different video bitrates. Short 32-second preallocated files remain evidence but are excluded from full-loop estimates.
- ARC 800: a single-format 4K30/1080p30 submission has constant per-channel file sizes and observed 60-second clips. Constant size across all files establishes the size of those sampled full loops. Mixed-format submissions are not merged into this estimate.
- S1 QHD: replaced video-only rates with constant allocated-size / 60-second loop rates. This includes padding. Short interrupted loops reduce actual time further.
- Cansonic Z4: added a default complete-file measured range across sampled settings. Existing named quality options remain explicitly video-only because these individual size/duration pairs do not establish the menu selection.
- No generic padding percentage and no pairing of unrelated size/duration extrema.

### Remaining maintained-profile gaps

Escort MAXcam 360c, Rove R2-4K, Tesla TeslaCam, Thinkware ARC 700 and ARC 900 still lack verified driving storage estimates in the reviewed evidence. No matching original submission with usable driving measurements was found for these exact models. Rove R2-4K Pro submissions do not establish R2-4K measurements. This is not a claim that external manufacturer evidence is unavailable.

Broader catalog-only coverage is still incomplete. Unreleased H1 remains excluded.

## Correction made

Cansonic UltraDash Z4 Standard Edition was missed by the old video-reference-only eligibility check. Its profile has explicitly driving-folder video measurements for High/Highest quality: Front and Telephoto 4K30, Rear 1440p30. Added them as submitted-video estimates with overhead caveats. Did not use PROTECTED parking clips or label video-stream rates as complete file sizes.

Reviewed ARC700’s official manual for recording-time/bitrate evidence but found no usable figure in its extracted text. The ARC 800 estimate now uses recovered scan evidence, not the ARC 700 manual.

All rows, exact mappings, and gap reasons are in [coverage-2026-09-08.csv](coverage-2026-09-08.csv). H1 remains excluded. The gap list is a research backlog, not fake selectable presets. Public release checks remain necessary for catalog-only candidates.
