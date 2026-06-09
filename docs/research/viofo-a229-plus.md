# VIOFO A229 Plus — Research Notes

## Camera Overview

The VIOFO A229 Plus is a 3-channel dashcam (front, interior, rear) with 2K QHD (2560×1440) front and rear cameras and a 1080P interior camera. It shares the VIOFO A229-series filename and folder family with A229 Pro and A229 Ultra.

A329S may look similar at the folder/filename level, but it uses a different processor/internal platform. Do not inherit A229 codec, bitrate, or metadata assumptions for A329S without direct A329S clip validation.

### A229 Lineup Resolution Comparison

| Model | Front | Interior | Rear |
|-------|-------|----------|------|
| A229 Ultra | 4K (3840×2160) | 1080P (1920×1080) | 4K (3840×2160) |
| A229 Pro | 4K (3840×2160) | 1080P (1920×1080) | 2K (2560×1440) |
| A229 Plus | 2K (2560×1440) | 1080P (1920×1080) | 2K (2560×1440) |

The A229 Plus is the entry model in the 3CH A229 lineup.

## Filename and Folder Structure

Confirmed identical to VIOFO A229 Pro and similar to A329S at the visible filename/folder level:
- Pattern: `YYYY_MMDD_HHMMSS_SEQUENCECHANNEL.EXT`
- Folders: `DCIM/Movie/`, `DCIM/Movie/Parking/`, `DCIM/Movie/RO/`, `DCIM/Photo/`
- Global monotonic sequence counter across all channels and modes
- Parking subfolders use PF/PI/PR channel suffixes

## MP4 Metadata

`©fmt=NOVATEK` and `©inf=DEMO1` confirmed on the A229 Plus real-card sample. Similar metadata must be rechecked on A329S because that model should not be treated as the same internal platform.

## OSD Stamp

Every video frame has "VIOFO A229 Plus" burned into the bottom-center. Observed on a fresh card with no GPS sync:

```
VIOFO A229 Plus  HDR  01-01-2025 00:06:05
```

When GPS has a fix and on hardwire power, the OSD likely also includes speed and voltage fields (as confirmed on A229 Ultra footage). Not verified on A229 Plus due to fresh card and no GPS lock.

OCR extraction confirmed working on dark footage using 50% brightness threshold.

## Sources

- Real microSD card scan (VIOFO A229 Plus, fresh format, scanned 2026-06-05)
- VIOFO product page: https://www.viofo.com/collections/dash-cam
- Cross-reference: VIOFO A229 Pro manual V26.01.09 (identical platform documentation)
