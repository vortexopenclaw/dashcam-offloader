# Vueroid S1 QHD Infinite

## Status

Seed profile learned from two app training submissions captured on firmware
1.0.4. `CONFIG/config.bin` exposes the exact marker `S1-QHD-INFINITE`, which is
safe to use to distinguish this model from the S1 4K Infinite and H1.

The product supports front/rear and front/interior/rear configurations. The
catalog records three channels as the maximum capability so incomplete cards do
not incorrectly prefill the learning form as 2CH.

## Observed Recording Behavior

- 30 fps submission: 63 one-minute driving clips and 6 thirty-second parking
  impact clips. Samples included 2560x1440 and 1920x1080 H.264 video at roughly
  15-22 Mbps, consistent with an active front/interior/rear set.
- 60 fps submission: 49 driving clips and 4 parking impact clips, all observed
  samples 2560x1440 H.264 at roughly 22-24 Mbps. The user reported that 60 fps
  mode disables the interior channel and HDR.
- Both submissions identify firmware 1.0.4.
- The config snapshot reported `2CH` even for the user-confirmed 3CH card, so
  that field is not authoritative for active channel count.
- Parking impact clips use the `PEVENT` folder and are presented as Parking
  Events. Regular motion/impact and extreme-low-power behavior were both
  represented in the submitted cards.

## Layout and Filenames

The card shares the established Vueroid S1 layout:

- `INF` — continuous driving footage
- `EVENT` — driving impact events
- `PARK` — motion or time-lapse parking footage
- `PEVENT` — parking impact events
- `USER` — manual recordings
- `CONFIG` — settings and model metadata, excluded from footage imports

Expected filename shape:

`YYYYMMDD_HHMMSS_PREFIX_CHANNEL_FLAG.mp4`

Channel tokens are `F` (front), `I` (interior), and `R` (rear). Related clips
are grouped by date, time, and prefix.

## Remaining Questions

- Confirm the exact split of 1920x1080 files between interior and rear using a
  future privacy-safe scan that preserves per-channel aggregates.
- Confirm PARK time-lapse frame-rate behavior on this QHD model.
- Confirm whether 60 fps always disables both the interior camera and HDR.
