# VIOFO A119 Mini 2 — Research Notes

## Camera Overview

The VIOFO A119 Mini 2 is a compact single-channel (front-only) dashcam with a 2K QHD (2560×1440) sensor. It shares the `YYYYMMDDHHMMSS_SEQUENCE` filename convention with the A119M Pro but has a distinct folder structure for parking recordings.

## Filename Convention

**Pattern: `YYYYMMDDHHMMSS_SEQUENCE.MP4`** — identical to VIOFO A119M Pro.

Confirmed on real card starting at sequence 000001 on a fresh format.

## Folder Structure

Confirmed from official manual V25.12.18:

| Mode | Path |
|------|------|
| Loop recording | `DCIM/Movie` |
| Locked clips | `DCIM/Movie/RO` |
| Parking (all subtypes) | `DCIM/Parking` |
| Locked parking clips | `DCIM/Parking/RO` |
| Snapshots | `DCIM/Photo` |

**Key difference from A229/A329/A139 lineup:** Parking recordings go to `DCIM/Parking/` at the top level, not `DCIM/Movie/Parking/`. Any offloading logic that assumes parking clips are always under `DCIM/Movie/` will miss them on this model.

Parking subtypes (auto event detection, time-lapse, and low bitrate recording) are all written to the same `DCIM/Parking/` folder — no sub-differentiation by type.

## OSD Stamp

OSD layout: `VIOFO A119 Mini 2` (bottom-center) + `MM/DD/YYYY HH:MM:SS` (bottom-right).

The OSD text is **light gray**, not white. This causes OCR to fail on bright-background frames (e.g., camera pointing at sky or a bright surface) because the contrast between text and background collapses. Adaptive thresholding is required for reliable detection.

Additionally, `Camera Model Stamp` is a user-configurable setting. If disabled, the model name does not appear in OSD and OCR-based detection will not work for that card.

OCR may read "119" as "1TA" or similar — fuzzy/regex pattern matching recommended:
```
r'VIOFO\s+A1(?:19|[0-9T][A-Z0-9]*)\s+Mini\s+2'
```

## Resolution Options

Per manual, available resolutions:
- 2592×1944P 30fps
- 2560×1600P 30fps
- **2560×1440P 30fps** (default, confirmed on real card)
- 2560×1440P 60fps
- 2560×1080P 60fps / 30fps
- 2304×1296P 30fps
- 1920×1080P 60fps / 30fps

## Sources

- Real microSD card scan (VIOFO A119 Mini 2, fresh format, scanned 2026-06-05)
- Official manual V25.12.18: https://viofotech.com/download/manual/MINI2/A119MINI2EnglishManual.pdf
- VIOFO product page: https://www.viofo.com/collections/dash-cam
