# VIOFO A119 Mini 2 — Card Profile

**Date scanned:** 2026-06-05
**Card state:** Freshly formatted (3 files)
**Volume label:** NO NAME (default, camera assigns no fixed label)
**Manual version:** V25.12.18

## Root Contents

| Path | Type | Notes |
|------|------|-------|
| `DCIM/` | Directory | All dashcam recordings |
| `.fseventsd/` | Directory | macOS filesystem events (system-generated) |

No `format.txt` at root. No `.diskdb`. Simpler root than A229/A329 cards.

## DCIM Structure

```
DCIM/
└── Movie/
    ├── 20260513140010_000001.MP4   (2s — brief test clip)
    ├── 20260513140102_000002.MP4   (60s)
    └── 20260513140202_000003.MP4   (41s)
```

`Movie/RO/`, `Parking/`, `Parking/RO/`, and `Photo/` not present on fresh card — created on first use.

**Important:** Parking recordings go to `DCIM/Parking/` (top-level), not `DCIM/Movie/Parking/` as used by the A229/A329 lineup. This is confirmed by the official manual.

## Filename Pattern

`YYYYMMDDHHMMSS_SEQUENCE.MP4` — identical to VIOFO A119M Pro.

```
20260513140010_000001.MP4  →  2026-05-13 14:00:10, seq 1
20260513140102_000002.MP4  →  2026-05-13 14:01:02, seq 2
20260513140202_000003.MP4  →  2026-05-13 14:02:02, seq 3
```

The entire datetime is a 14-digit concatenated number with no underscore separators. No channel letter — single-channel (front-only) camera. Sequence starts at 1 on a fresh format and is a global monotonic counter.

## Folder Structure (from official manual)

| Recording mode | Folder |
|---|---|
| Loop recording | `DCIM/Movie` |
| Locked/emergency clips | `DCIM/Movie/RO` |
| Parking (all subtypes) | `DCIM/Parking` |
| Locked parking clips | `DCIM/Parking/RO` |
| Snapshots | `DCIM/Photo` |

Parking subtypes (auto event detection, time-lapse, low bitrate) all write to `DCIM/Parking/` — they are not separated by subfolder.

## Resolutions

Default: **2560×1440** (confirmed on real card). Full option list per manual:
2592×1944, 2560×1600, 2560×1440 (default), 2560×1440@60fps, 2560×1080@60fps, 2560×1080, 2304×1296, 1920×1080@60fps, 1920×1080.

## MP4 Metadata

| Tag | Value |
|-----|-------|
| `major_brand` | mp42 |
| `creation_time` | present (e.g. `2026-05-13T14:02:01.000000Z`) |

No NOVATEK-specific `©fmt`/`©inf` tags observed on real card.

## OSD Detection

OSD layout: `VIOFO A119 Mini 2` at bottom-center, `MM/DD/YYYY HH:MM:SS` at bottom-right.

**Visual confirmation:** "VIOFO A119 Mini 2  05/13/2026 14:02:39" clearly visible in extracted frame.

**OCR challenge:** OSD text is light gray, not white. On bright scenes (camera pointing toward sky or bright surface), the OSD background is also bright, resulting in very low contrast. The half-max brightness threshold used for A229/A329 models fails here. Adaptive thresholding is required. OCR may also misread "119" as "1TA" or similar — fuzzy matching recommended.

**Setting dependency:** `Camera Model Stamp` is a configurable setting (System Settings menu). If disabled by the user, the model name will not appear in the OSD and this detection method will not work.

## Open Questions

- Do `Parking/` and `Parking/RO/` follow the same `YYYYMMDDHHMMSS_SEQUENCE` pattern?
- Does `Photo/` use `.JPG` extension as assumed?
- Does the OSD include speed/GPS coordinates when GPS has a fix?
