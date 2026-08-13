# Thinkware ARC 700

## Status

Manual-backed seed profile. It is available for user selection and safely
classifies the manual-confirmed card layout, but a real card is required before
automatic exact model recognition or unobserved filename prefixes are claimed.

## Manual-Confirmed Behavior

- Folders: `cont_rec`, `evt_rec`, `manual_rec`, `motion_timelapse_rec`, and
  `parking_rec`.
- `REC_YYYYMMDD_HHMMSS_F.MP4` and `_R.MP4` identify Front and Rear clips.
- Continuous clips are one minute; driving impact and parking clips are kept
  separately by folder.
- 1CH and 2CH variants are documented. The two-camera resolutions are 4K30
  Front plus QHD30 Rear, or QHD45 Front plus QHD30 Rear.

## Not Yet Claimed

The manual does not show model-specific card metadata or examples for every
non-continuous filename prefix. Folder semantics remain deterministic, but
their filename prefixes and actual bitrates need a real card scan.

## Reference

- Official manual: <https://download2.inavi.com/dashcam/ARC700/manual/arc700_manual_english_20250411.pdf>
