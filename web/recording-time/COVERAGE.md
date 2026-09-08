# Calculator coverage audit — September 8, 2026

Calculator: **81 model presets**. This is not complete app-catalog coverage.

Compared all 262 explicit model entries in `KnownDashcamCatalog.swift` from the current main checkout and all 68 JSON profiles in the maintained `dashcam-camera-profiles` checkout. Catalog source SHA-256: `7862feb183b26317bff161df3fdb9da1040d093ca279a03c26860bea6791a10b`.

Matching uses case/punctuation normalization, documented app aliases, channel-package suffixes, and the Cansonic “Standard Edition” name. It does not merge Plus, Pro, LTE, Commercial, or numbered-generation variants.

The app catalog includes non-dashcams and entries without recording-rate evidence. A supported card layout, resolution, or file-naming pattern does not establish storage consumption. “Missing” below means unavailable in the reviewed local recording-rate data, not that exhaustive manufacturer research proved no data exists.

## Counts

### App catalog

- Excluded: unreleased: 1
- Included: 62
- Missing: catalog-only or variant: 166
- Missing: profile lacks driving rates: 6
- Missing: parking-only rates: 1
- Outside dashcam scope: 26

62 app rows map to 60 unique calculator presets (catalog aliases can share an estimate). The other 21 calculator presets are additional measured models.

### Calculator additional model

- Included: 21

### Maintained profile

- Included: 53
- Missing: profile lacks driving rates: 7
- Outside dashcam scope: 5
- Missing: parking-only rates: 2
- Excluded: unreleased: 1

## Maintained dashcam-profile gaps

- **Botslab G980H**: Profile has recognition/configuration facts but no usable driving bitrate or recording-time figure. Needs measured driving files or a published duration/bitrate.
- **Escort MAXcam 360c**: Profile has recognition/configuration facts but no usable driving bitrate or recording-time figure. Needs measured driving files or a published duration/bitrate.
- **Rove R2-4K**: Maintained profile has only parking measurements, not driving rates.
- **Thinkware FA200**: Maintained profile has only parking measurements, not driving rates.
- **Ottocast OttoSafe Cam**: Profile has recognition/configuration facts but no usable driving bitrate or recording-time figure. Needs measured driving files or a published duration/bitrate.
- **Tesla TeslaCam**: Profile has recognition/configuration facts but no usable driving bitrate or recording-time figure. Needs measured driving files or a published duration/bitrate.
- **Thinkware ARC 700**: Profile has recognition/configuration facts but no usable driving bitrate or recording-time figure. Needs measured driving files or a published duration/bitrate.
- **Thinkware ARC 800**: Profile has recognition/configuration facts but no usable driving bitrate or recording-time figure. Needs measured driving files or a published duration/bitrate.
- **Thinkware ARC 900**: Profile has recognition/configuration facts but no usable driving bitrate or recording-time figure. Needs measured driving files or a published duration/bitrate.

## Correction made

Cansonic UltraDash Z4 Standard Edition was missed by the old video-reference-only eligibility check. Its profile has explicitly driving-folder video measurements for High/Highest quality: Front and Telephoto 4K30, Rear 1440p30. Added them as submitted-video estimates with overhead caveats. Did not use PROTECTED parking clips or label video-stream rates as complete file sizes.

Reviewed ARC700’s official manual for recording-time/bitrate evidence but found no usable figure in its extracted text. No ARC estimates were guessed.

All rows, exact mappings, and gap reasons are in [coverage-2026-09-08.csv](coverage-2026-09-08.csv). H1 remains excluded. The gap list is a research backlog, not fake selectable presets. Public release checks remain necessary for catalog-only candidates.
