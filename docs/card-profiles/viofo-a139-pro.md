# VIOFO A139 Pro — Card Profile

**Date learned:** 2026-06-05
**Source:** NAS-archived footage (89 clips, 2022-10-27 through 2023-06-14) — no direct card scan
**Validation note:** Folder structure is inferred. Filename pattern and resolution data verified from real footage files.

## Filename Pattern

`YYYY_MMDD_HHMMSS_CHANNEL.MP4` — **no sequence number**.

This is distinct from the A229/A329 lineup (`YYYY_MMDD_HHMMSS_SEQCHANNEL.MP4`). The channel letter is underscore-separated rather than appended directly to a sequence number.

Example filenames (native, before user-added labels):
```
2022_1027_084120_F.MP4
2022_1027_084420_F.MP4
2022_1205_165601_I.MP4
2023_0614_164759_R.MP4
```

Because there is no sequence number, grouping must rely on timestamp alone. Same-second recording starts across channels are theoretically possible but not observed in the NAS sample.

## Channels and Resolutions

| Channel | Role | Resolution | Codec |
|---------|------|-----------|-------|
| F | Front | 3840×2160 (4K UHD) | H.264 |
| I | Interior | 1920×1080 (1080P) | HEVC (H.265) |
| R | Rear | 1920×1080 (1080P) | H.264 |

The interior channel uses HEVC while front and rear use H.264 — a mixed-codec configuration not seen on the A229/A329 lineup.

Channel distribution in NAS sample: 60 F, 12 I, 17 R files (not a balanced set — user archived selectively).

## Clip Duration

60-second clips confirmed on multiple files.

## MP4 Metadata

Container brand: `mp42`. No `creation_time` tag was always present — varies by file. The NOVATEK-specific `©fmt`/`©inf` tags were not observed (likely stripped during NAS archiving).

## OSD Detection

OSD line observed in front-channel footage:
```
034MPH VORTEXRADAR VIOFO A139 PRO HDR+ON 01/04/2023 17:21:25
```

Fields: GPS speed · user-configurable camera name · model name · HDR status · date/time

**Important:** The A139 Pro renders the model suffix in all caps — "VIOFO A139 PRO" — unlike the A229/A329 lineup which uses title case ("VIOFO A229 Pro"). OSD matching must be case-insensitive.

Confirmed on day, overcast, snowy, and night clips.

## Inferred Card Structure

Folder structure is unknown (no direct card scan). Based on VIOFO conventions:
```
DCIM/
└── Movie/    # continuous recording
              # parking/RO/photo structure unknown for this model
```

## Open Questions

- What is the DCIM folder structure (parking, RO, photo)?
- Does `format.txt` appear at card root?
- Are parking recordings stored with the same `YYYY_MMDD_HHMMSS_CHANNEL` pattern or a different one?
- Does the A139 Pro support a parking mode at all?
- Is there a real-card volume label?
