# VIOFO A229 Ultra — Card Profile

**Date learned:** 2026-06-05
**Source:** Private archive sample, no direct card scan
**Validation note:** Folder structure is inferred from VIOFO platform conventions. Filename pattern and resolution data verified from real footage files.

## Filename Pattern

`YYYY_MMDD_HHMMSS_SEQUENCECHANNEL.EXT` — identical to all other VIOFO models.

Dummy native card filename examples:
```
2030_0101_120000_000001F.MP4
2030_0101_120000_000002I.MP4
2030_0101_120000_000003R.MP4
2030_0101_120100_000004F.MP4
2030_0101_120100_000005I.MP4
2030_0101_120100_000006R.MP4
```

Sequence numbers are global monotonic across F/I/R channels. Do not publish observed sequence ranges from private archives.

Channels observed: F (front), I (interior), R (rear).

## Resolutions

| Channel | Role | Resolution |
|---------|------|-----------|
| F | Front | 3840×2160 (4K UHD) |
| I | Interior | 1920×1080 (1080P) |
| R | Rear | 3840×2160 (4K UHD) |

Both front and rear are 4K — distinguishing the A229 Ultra from A229 Pro (4K front, 2K rear) and A229 Plus (2K front, 2K rear).

## Clip Duration

60-second clips confirmed on multiple F/I/R files.

## MP4 Metadata

Container brand: `mp42`. The NOVATEK-specific `©fmt=NOVATEK` and `©inf=DEMO1` tags were not observed in the private archive sample. Cannot be confirmed without a direct card scan.

## OSD Detection

OSD line observed in front-channel footage (GPS locked, hardwired power):
```
000MPH 00.00V 0.0.000000 VIOFO A229 Ultra 01/01/2030 12:00:00 PM
```

Fields: GPS speed · vehicle voltage · firmware version · model name · date/time

"VIOFO A229 Ultra" confirmed via OCR on multiple day clips and one rainy-night clip.

## Inferred Card Structure

Based on VIOFO platform conventions confirmed on A229 Pro and A329S real cards:

```
DCIM/
├── Movie/           # continuous recording
├── Movie/RO/        # locked/protected clips
├── Movie/Parking/   # parking mode recordings
└── Photo/           # still photos
```

## Open Questions

- Does `format.txt` appear at card root?
- Is a T/PT telephoto channel supported with an accessory cam?
- Are Parking and RO subfolders structured identically to A229 Pro?
- Does the A229 Ultra have a distinct volume label when formatted?
- Can NOVATEK `©fmt`/`©inf` tags be confirmed on a direct card scan?
