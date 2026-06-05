# VIOFO A119M Pro — Research Notes

## Camera Overview

The VIOFO A119M Pro is a single-channel (front-only) 4K dashcam. It uses a completely different filename convention from all other VIOFO models learned so far.

## Filename Convention

**Pattern: `YYYYMMDDHHMMSS_SEQUENCE.MP4`**

Key differences from all other VIOFO models:
- **No underscore separators** within the date/time component — the full 14-digit datetime is a single token
- **No channel letter** — single-channel camera, front only
- Sequence number is still present and is a global monotonic counter persisting across sessions

This is the most compact filename format in the VIOFO lineup. The datetime format `YYYYMMDDHHMMSS` (vs. `YYYY_MMDD_HHMMSS` on other models) is a breaking difference for any parser that assumes underscores in the timestamp.

## OSD Stamp

A119M Pro OSD with GPS lock:
```
00MPH N00.000000 W000.000000  DUMMYCAM VIOFO A119M Pro 01/01/2000 00:00:00
```

Fields: GPS speed · GPS coordinates · optional user-set camera name · model name · date/time

The model name displays as "VIOFO A119M Pro" (mixed case, not all-caps like A139 Pro). The GPS coordinates are shown in full decimal degrees in the OSD.

OSD matching confirmed via OCR on multiple clips. High-contrast frames (direct sun, bright reflections) can produce garbled OCR — the detection implementation should retry with additional frames.

## VIOFO Model Naming Note

The "M" in A119M refers to a mini form factor. The A119M Pro is a compact single-lens unit, in contrast to the multi-channel A229/A329 and A139 families.

## Source Validation

This profile was built from NAS-archived footage files, not a direct microSD card scan. Card structure is fully inferred. A real card scan would confirm:
- Full DCIM folder structure and parking/RO handling
- Whether `format.txt` appears at root
- NOVATEK `©fmt`/`©inf` metadata on real files

## Sources

- NAS footage archive: 33 clips (VIOFO A119M Pro, 2025-10-17, 2025-11-29, 2025-12-02)
- VIOFO product page: https://www.viofo.com/collections/dash-cam
