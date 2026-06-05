# VIOFO A229 Ultra — Research Notes

## Camera Overview

The VIOFO A229 Ultra is VIOFO's flagship 3-channel dashcam, featuring 4K UHD front and rear cameras paired with a 1080P ultra-wide interior camera. It shares the Novatek-based platform common to the A229 and A329 lineup, with identical filename conventions.

The A229 Ultra's distinguishing feature: **4K on both front and rear**, whereas the A229 Pro has 4K front with 2K rear, and the A229 Plus has 2K on both.

### A229 Lineup Resolution Comparison

| Model | Front | Interior | Rear |
|-------|-------|----------|------|
| A229 Ultra | 4K (3840×2160) | 1080P (1920×1080) | 4K (3840×2160) |
| A229 Pro | 4K (3840×2160) | 2K (2560×1440) | 2K (2560×1440) |
| A229 Plus | 2K (2560×1440) | 1080P (1920×1080) | 2K (2560×1440) |

## Filename and Folder Structure

Confirmed identical to other VIOFO models:
- Pattern: `YYYY_MMDD_HHMMSS_SEQUENCECHANNEL.EXT`
- Channels: F (front), I (interior), R (rear) confirmed from footage
- Global monotonic sequence counter confirmed across multiple sessions
- Folder structure inferred from VIOFO platform conventions (not directly scanned)

## OSD Stamp

A229 Ultra OSD when on hardwire power with GPS lock:

```
000MPH 00.00V 0.0.000000 VIOFO A229 Ultra 01/01/2030 12:00:00 PM
```

Fields: GPS speed · vehicle voltage · firmware version · model name · date/time

This is richer than A229 Plus OSD (model name + HDR flag + timestamp only). The additional fields appear when GPS has a fix and the camera is on hardwired power. Firmware version in sample: `1.0.250804`.

OCR extraction confirmed on multiple day clips and one rainy-night clip using brightness thresholding.

## Source Validation

This profile was built from a private archive sample, not a direct microSD card scan. Folder structure, parking modes, and file exclusion patterns are inferred. A real card scan would confirm:
- Whether `format.txt` is present at root
- Parking, RO, and Photo subfolder structure
- Whether a distinct volume label is assigned
- NOVATEK `©fmt`/`©inf` metadata

## Sources

- Private archive sample; counts and recording dates intentionally omitted
- VIOFO product page: https://www.viofo.com/collections/dash-cam
