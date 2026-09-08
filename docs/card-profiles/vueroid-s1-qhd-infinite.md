# Vueroid S1 QHD Infinite

## Status

Seed profile learned from four privacy-sanitized app training submissions captured on firmware
1.0.4. `CONFIG/config.bin` exposes the exact marker `S1-QHD-INFINITE`, which is
safe to use to distinguish this model from the S1 4K Infinite and H1.

The product supports front/rear and front/interior/rear configurations. The
catalog records three channels as the maximum capability so incomplete cards do
not incorrectly prefill the learning form as 2CH.

## Observed Recording Behavior

- Two recognized 30 fps 3CH submissions preserved per-channel aggregates. The
  newest contained 57 driving clips, 126 time-lapse parking clips, and 18
  parking-impact clips; the other contained 51 driving clips and 6 impact
  clips.
- In the high-bitrate 3CH samples, front and rear were 2560x1440 H.264 at about
  22 Mbps, while interior was 1920x1080 H.264 at about 15 Mbps.
- Time-lapse parking used all three channels at 5 fps in 20-second files. Its
  sampled bitrates were about 13.8-16.3 Mbps front, 7.8-8.5 Mbps interior, and
  9.8-10.9 Mbps rear.
- Parking-impact clips used all three channels at 30 fps in 30-second files and
  retained roughly the same high-bitrate resolution profile as driving clips.
- 60 fps submission: 49 driving clips and 4 parking impact clips, all observed
  samples 2560x1440 H.264 at roughly 22-24 Mbps. The user reported that 60 fps
  mode disables the interior channel and HDR.
- All four submissions identify firmware 1.0.4.
- The config snapshot reported `2CH` even for the user-confirmed 3CH card, so
  that field is not authoritative for active channel count.
- Parking impact clips use the `PEVENT` folder and are presented as Parking
  Events. `PARK` footage at 5 fps is time-lapse parking; regular motion/impact,
  time-lapse, and extreme-low-power behavior are represented across the cards.

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

- Confirm whether 60 fps always disables both the interior camera and HDR.
- Validate a physical 2CH bundle rather than relying on the shared profile's
  supported front/rear variant.
