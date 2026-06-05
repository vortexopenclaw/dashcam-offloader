# VIOFO A119M Pro — Card Profile

**Date learned:** 2026-06-05
**Source:** NAS-archived footage (33 clips, 2025-10-17, 2025-11-29, 2025-12-02) — no direct card scan
**Validation note:** Folder structure is inferred. Filename pattern and resolution data verified from real footage files.

## Filename Pattern

`YYYYMMDDHHMMSS_SEQUENCE.MP4` — no underscores within the date/time component, no channel letter.

This is the most distinct pattern in the VIOFO lineup. The entire datetime is a single 14-digit number:

```
20251017133816_000043.MP4   →  2025-10-17 13:38:16, seq 43
20251017143416_000099.MP4   →  2025-10-17 14:34:16, seq 99
20251129121050_000261.MP4   →  2025-11-29 12:10:50, seq 261
20251202165843_000468.MP4   →  2025-12-02 16:58:43, seq 468
```

No channel letter because this is a single-channel (front-only) camera.

The sequence number is a global monotonic counter persisting across recording sessions. Observed range: 43–468 across the NAS sample spanning three recording dates, confirming it does not reset on each session.

## Channels and Resolutions

| Channel | Role | Resolution | Codec |
|---------|------|-----------|-------|
| F (implied) | Front | 3840×2160 (4K UHD) | H.264 |

Single-channel camera. No channel letter appears in filenames.

## Clip Duration

60-second clips confirmed.

## MP4 Metadata

Container brand: `mp42`. No `creation_time` tag present. NOVATEK-specific tags not observed (likely stripped during NAS archiving or absent on this platform).

## OSD Detection

OSD line from front-channel footage (GPS locked, hardwired or battery):
```
0MPH N00.0000 E000.000000  DUMMY VIOFO A119M Pro 01/01/2025 00:00:00
```

Fields: GPS speed · GPS coordinates (lat/lon) · user-configurable camera name · model name · date/time

Additional OSD variant (HDR active):
```
AMPH VIOFO A119M Pro HDR 12/02/2025 16:58:47
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
