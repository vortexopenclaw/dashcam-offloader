# Thinkware ARC 800

## Status

Validated 2-channel profile based on an app-submitted ARC 800 card scan, safe
`.SETTING/dashcam.inf` model metadata, ARC OSD recognition, and the official
English manual dated 2026-06-23.

## Model Detection

- `.SETTING/dashcam.inf` contains `ARC800` and is the deterministic model
  marker used by the profile.
- The card's normal Thinkware recording folders and `REC`/`EVT`/`MOT`/`PAK`
  filenames corroborate the family but are not model-specific by themselves.
- Front-camera OSD recognition supplied independent model-family evidence.

## Recording Folders

- `cont_rec` holds continuous driving recording.
- `evt_rec` holds impact-triggered driving events.
- `motion_timelapse_rec` holds parking motion-detection or time-lapse video.
  The 2026-08-17 card submissions confirm the short 720p15 recurring clips
  are timelapse, not continuous/low-bitrate parking recording.
- `parking_rec` holds low-power energy-saving parking impact video.
- `manual_rec` holds manual recordings.
- `Safety_Box` holds videos the user has saved in-camera.
- `sos_rec` holds optional SOS recordings.
- `.parking_rec_sec` was present on the sampled card. Its full-resolution
  twin folder is `parking_rec`; it is imported as footage but its exact
  product role remains provisional.

## Channels And Filenames

Observed filenames are `MODE_YYYYMMDD_HHMMSS_CHANNEL.MP4`.

- `F` is Front.
- `R` is Rear.
- Observed prefixes: `REC` continuous, `EVT` driving event, `MOT` parking
  motion or time-lapse, `PAK` parking impact, `PAS` secondary parking, and
  `MAN` manual.

The sampled card was 2-channel. The manual documents 1CH and 2CH video
configurations, so the profile supports an F-only card without inventing an
unobserved channel.

## Video Configurations

The initial submitted footage was 4K30 Front plus FHD30 Rear. A subsequent
read-only direct-card scan also found a QHD30 Front clip paired with FHD30
Rear. The 2026-08-17 card scan confirms QHD60 Front plus FHD30 Rear. The
official manual also documents that configuration.

The Learn Card summary now retains a representative file for every observed
codec/resolution/frame-rate configuration inside each recording bucket, so a
rare setting such as the QHD30 clip cannot be omitted by generic sampling.

## Reference

- Official manual: <https://download2.inavi.com/dashcam/ARC800/manual/arc800_manual_english_20260623.pdf>
