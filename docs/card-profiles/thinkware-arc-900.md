# Thinkware ARC 900

## Status

Manual-backed seed profile. It is available for user selection and safely
classifies the manual-confirmed card layout, but a real card is required before
automatic exact model recognition or unobserved filename prefixes are claimed.

## Manual-Confirmed Behavior

- Folders: `cont_rec`, `evt_rec`, `motion_rec`, `parking_rec`, `manual_rec`,
  and `sos_rec`.
- `REC_YYYYMMDD_HHMMSS_F.MP4` and `_R.MP4` identify Front and Rear clips.
- `motion_rec` contains motion-detection or time-lapse parking video, while
  `parking_rec` contains parking-impact video.
- The documented 2CH resolutions are 4K30 Front plus QHD30 Rear, or QHD60
  Front plus FHD60 Rear.

## Not Yet Claimed

The manual does not show model-specific card metadata or examples for every
non-continuous filename prefix. Folder semantics remain deterministic, but
their filename prefixes and actual bitrates need a real card scan.

## Reference

- Official manual: <https://download2.inavi.com/dashcam/ARC900/manual/arc900_manual_english_20251031.pdf>
