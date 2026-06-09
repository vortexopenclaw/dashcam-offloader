# Botslab G980H

**Make:** Botslab

**Model:** G980H

**Status:** App-submission sampled and direct-card sampled

## Evidence

- App training submission `9d0bd1cb-7593-4276-9b09-2cd793d57dee`
- Direct card read from `/Volumes/NO NAME`
- High-confidence marker file: `MISC/G980HMCN5291.TXT`

The card was tested in 4CH mode with driving footage and sentry-mode parking footage, then in 3CH mode with the front channel raised to the fake 4K mode and parking switched to timelapse.

## Card Layout

| Path | Meaning |
|---|---|
| `360CARDVR/REC/` | Driving clips |
| `360CARDVR/PARKING/` | Parking clips |
| `360CARDVR/SECVIDEO/` | Timelapse-style parking clips |
| `360CARDVR/GPS/` | GPS/support data, not imported as footage |
| `MISC/G980HMCN5291.TXT` | Model marker used for exact model detection |

Source filtering must allow `360CARDVR` cards to appear in Sources. Unknown `360CARDVR`-style cards should be shown as new/unrecognized unless exact model evidence exists.

## Filename Pattern

```text
YYYYMMDDHHMMSS_SEQUENCECHANNEL.MP4
```

Observed channel tokens:

| Token | Channel |
|---|---|
| `AA` | Front |
| `AB` | Rear |
| `AC` | Left |
| `AD` | Right |

## Video Specs

Observed 4CH mode samples:

- `AA` front: H.264, 2880x1620, 25 fps.
- `AB` rear: H.264, 1920x1080, 25 fps.
- `AC` left: H.264, 1920x1080, 25 fps.
- `AD` right: H.264, 1920x1080, 25 fps.

The 3CH follow-up card should be used to compare fake 4K front clips against the
4CH baseline and to confirm `SECVIDEO` timelapse samples.

## Parking Behavior

The submitted 4CH test used sentry-mode parking with motion and impact events.
The app split observed parking into Parking Continuous / Low Bitrate and Parking
Motion Detection groups. The 3CH follow-up card added `SECVIDEO` clips after the
user switched to timelapse parking mode, so the profile treats `SECVIDEO` as
Parking Timelapse.

Keep generic detection conservative for future Botslab-like cards:

- Use `MISC/G980HMCN5291.TXT` as exact G980H evidence.
- Without exact model evidence, classify the card as a generic/new dashcam instead of borrowing a profile from another 360-camera brand.
- Preserve video spec summaries and representative clips so 3CH/4CH and bitrate/resolution mode changes can be compared later.
