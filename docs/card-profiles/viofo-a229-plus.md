# VIOFO A229 Plus — Card Profile

**Date scanned:** 2026-06-05
**Card state:** Fresh format, barely used (9 files, 3 recording sessions)
**Volume label:** A229 Plus (renamed by user; camera likely assigns no fixed label)

## Root Contents

| Path | Type | Notes |
|------|------|-------|
| `DCIM/` | Directory | All dashcam recordings |
| `DCIM/.diskdb` | File | 184 bytes — camera index, essentially empty on fresh card |

No `format.txt` at root. Both A229 Pro and A329S had a `format.txt`; its absence here may reflect the fresh-format state or a firmware/model difference. Needs a follow-up scan of a well-used card.

## DCIM Structure

```
DCIM/
└── Movie/
    ├── 2025_0101_000600_000001F.MP4
    ├── 2025_0101_000600_000002I.MP4
    ├── 2025_0101_000600_000003R.MP4
    ├── 2025_0101_000700_000004F.MP4
    ├── 2025_0101_000700_000005I.MP4
    ├── 2025_0101_000700_000006R.MP4
    ├── 2025_0101_000800_000007F.MP4
    ├── 2025_0101_000800_000008I.MP4
    └── 2025_0101_000800_000009R.MP4
```

`Parking/`, `RO/`, and `Photo/` subfolders were not present — consistent with a freshly formatted card where these directories are created on first use.

## Filename Pattern

`YYYY_MMDD_HHMMSS_SEQUENCECHANNEL.EXT` — identical to all other VIOFO models.

Timestamps show `2025_0101` because the camera clock defaulted to 2025-01-01 00:00:00 without GPS sync (recording indoors, no sky view).

Sequence numbers are a global monotonic counter across all channels:
- Session 1: `000001F`, `000002I`, `000003R`
- Session 2: `000004F`, `000005I`, `000006R`
- Session 3: `000007F`, `000008I`, `000009R`

## Resolutions

| Channel | Role | Resolution |
|---------|------|-----------|
| F | Front | 2560×1440 (2K QHD) |
| I | Interior | 1920×1080 (1080P) |
| R | Rear | 2560×1440 (2K QHD) |

Default factory settings. Users can lower resolution in camera settings.

## MP4 Metadata

| Tag | Value |
|-----|-------|
| `©fmt` | NOVATEK |
| `©inf` | DEMO1 |
| `tima` | ver 20022008 |

Identical to A229 Pro and A329S samples. Not useful for model discrimination.

## OSD Detection

The camera burns "VIOFO A229 Plus" into the bottom-center of every video frame. All footage on this card is extremely dark (camera pointed at a dark indoor surface), but the white OSD text is still readable after brightness thresholding.

**Method:** Bottom 8% crop of front-channel F.MP4 → threshold at 50% of max pixel value → 4× upscale → tesseract `--psm 6`

**Confirmed result:** `VIOFO A229 Plus HDR 01-01-2025 00:06:05`

Also confirmed via direct visual inspection of extracted frames.

## Open Questions

- Does `format.txt` appear on a well-used A229 Plus card?
- Do Parking, RO, and Photo subfolders follow identical structure to A229 Pro?
- Does the T/PT telephoto channel appear if an accessory telephoto cam is attached?
- Does the OSD include speed/voltage fields when GPS is locked and on hardwire power?
