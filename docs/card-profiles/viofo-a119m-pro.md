# VIOFO A119M Pro — Card Profile

**Date learned:** 2026-06-05
**Source:** Private archive sample, no direct card scan
**Validation note:** Folder structure is inferred. Filename pattern and resolution data verified from real footage files.

## Filename Pattern

`YYYYMMDDHHMMSS_SEQUENCE.MP4` — no underscores within the date/time component, no channel letter.

This is the most distinct pattern in the VIOFO lineup. The entire datetime is a single 14-digit number:

```
20300101120000_000001.MP4   ->  2030-01-01 12:00:00, seq 1
20300101120100_000002.MP4   ->  2030-01-01 12:01:00, seq 2
20300101120200_000003.MP4   ->  2030-01-01 12:02:00, seq 3
```

No channel letter because this is a single-channel (front-only) camera.

The sequence number is a global monotonic counter persisting across recording sessions. Do not publish observed sequence ranges or recording dates from private archives.

## Channels and Resolutions

| Channel | Role | Resolution | Codec |
|---------|------|-----------|-------|
| F (implied) | Front | 3840×2160 (4K UHD) | H.264 |

Single-channel camera. No channel letter appears in filenames.

## Clip Duration

60-second clips confirmed.

## MP4 Metadata

Container brand: `mp42`. No `creation_time` tag present. NOVATEK-specific tags not observed in the private archive sample.

## OSD Detection

OSD line from front-channel footage (GPS locked, hardwired or battery):
```
00MPH N00.000000 W000.000000  DUMMYCAM VIOFO A119M Pro 01/01/2000 00:00:00
```

Fields: GPS speed · GPS coordinates (lat/lon) · user-configurable camera name · model name · date/time

Additional OSD variant (HDR active):
```
AMPH VIOFO A119M Pro HDR 01/01/2030 12:00:00
```

"VIOFO A119M Pro" confirmed via OCR on multiple day, night, and overcast clips. Some high-contrast frames (direct sun, bright reflections) produce garbled OCR — retry with additional frames when first attempt fails.

## Inferred Card Structure

Folder structure is unknown (no direct card scan). Based on VIOFO conventions:
```
DCIM/
└── Movie/    # continuous recording
              # parking/RO structure unknown
```

## Open Questions

- What is the full DCIM folder structure?
- Does parking mode exist, and if so, do parking filenames use the same `YYYYMMDDHHMMSS_SEQUENCE` pattern?
- Does `format.txt` appear at card root?
- Is there a real-card volume label?
- Are NOVATEK `©fmt`/`©inf` metadata tags present on a direct card scan?
