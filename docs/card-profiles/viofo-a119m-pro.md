# VIOFO A119M Pro — Card Profile

**Date learned:** 2026-06-05
**Source:** Private archive samples and owner-confirmed submitted card scans.
**Validation note:** Current Windows card evidence confirms Movie and Parking folders with paired video measurements. Model, Low driving quality, 1 fps Night Vision capture, and unchanged firmware are owner context; the stored 30 fps is playback.

## Filename Pattern

`YYYYMMDDHHMMSS_SEQUENCE.MP4` — no underscores within the date/time component, no channel letter.

The entire datetime is a single 14-digit number. This shape is shared with the A119 Mini 2 and is not an exact-model signature:

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

## Reviewed Windows card measurements

Firmware **1.2_20260817**, confirmed by the owner as unchanged from prior scans (the Windows form itself omitted firmware).

- **Low driving quality:** front 3840×2160, H.264, 30 fps; two measured video-stream rates **32.766298–32.766472 Mbps**. Full file-size/playback-duration pairs are retained, including the shorter 108.466667-second clip.
- **1 fps Night Vision time-lapse parking:** front 2560×1440, H.264, **30 fps playback**, measured video-stream rate **26.213128 Mbps**, 132 seconds playback. Capture cadence and Night Vision are owner-confirmed, not inferred from encoding fps. Playback rate/duration must not be used directly as real-time storage consumption.
- Scan completed: four video files were inventoried and three representative measurements retained. Native mode hints were unknown; Movie/Parking context plus owner confirmation establish reviewed categories.
- No power consumption or wakeup delay was measured by this scan. This configuration remains distinct from High/Auto Event Detection and Medium/continuous Low Bitrate tests.

Exact anonymous evidence: [Low / 1 fps Night Vision card scan](https://github.com/vortexopenclaw/dashcam-camera-profiles/blob/main/docs/data/a119m-pro-low-1.2_20260817.json). Individual numeric pairs are also mirrored in `web/recording-time/storage-evidence.json`.

## Card Structure

The Windows scan observed these camera folders. No private filenames are published here.
```
DCIM/
├── Movie/    # owner-confirmed driving context
└── Parking/  # owner-confirmed 1 fps Night Vision time-lapse for this scan
```

## Open Questions

- Which additional folders/recording modes appear across other configurations?
- Do all parking configurations retain the same filename shape?
- Does `format.txt` appear at card root?
- Is there a real-card volume label?
- Are NOVATEK `©fmt`/`©inf` metadata tags present on a direct card scan?
