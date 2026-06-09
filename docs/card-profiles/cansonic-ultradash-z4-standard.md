# Cansonic UltraDash Z4 Standard Edition

**Make:** Cansonic

**Model:** UltraDash Z4 Standard Edition

**Status:** App-submission sampled and direct-card sampled

## Evidence

- App training submission `c4f6f86d-d32f-4163-9b95-884a3dfae512`
- App training submission `e4c70755-886c-4f43-9c21-a344a82a6d5c`
- Direct card reads from `/Volumes/ULTRADASH`

The first app submission came from an older build and had folder/filename samples but no video spec samples, folder summaries, setting snapshots, or correct mode labels. Later builds send the fuller scan data.

## Card Layout

| Path | Meaning |
|---|---|
| `VIDEO/` | Driving clips |
| `PROTECTED/` | Protected parking clips and possibly locked/event footage |

There were no readable config/settings files on the sampled cards.

## Filename Pattern

Driving clips:

```text
YYYYMMDD_HHMMSS_CHANNEL.MP4
```

Protected clips:

```text
PYYYYMMDD_HHMMSS_CHANNEL.MP4
```

Observed channels:

| Token | Channel |
|---|---|
| `L` | Front |
| `R` | Front telephoto |
| `B` | Rear |

## Video Specs

Observed direct-card and app-submission evidence:

- `L`: H.264, 3840x2160, 30 fps, roughly 31-41 Mbps depending on quality/mode.
- `R`: H.264, 3840x2160, 30 fps, roughly 31-41 Mbps depending on quality/mode.
- `B`: H.264, 2560x1440, 30 fps, roughly 12 Mbps in both high and highest quality samples observed so far.

## Parking Behavior

Observed parking evidence includes:

- Sentry mode with motion/vibration detection.
- Timelapse parking mode.
- P-prefixed clips in `PROTECTED/`.

Do not assume every `PROTECTED/P...` clip is an impact. The same folder/prefix can hold different parking behaviors. When config evidence is missing, infer parking pattern from:

- Folder path
- Filename prefix
- Clip spacing
- Group continuity across L/R/B
- Duration
- File size
- Bitrate and resolution samples

Current inference should distinguish regular timelapse-like protected sequences from isolated protected motion/impact moments, but exact motion vs. impact may remain ambiguous without additional camera evidence.
