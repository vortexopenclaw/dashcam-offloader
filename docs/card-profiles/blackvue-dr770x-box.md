# BlackVue DR770X Box

## Status

Seed profile, based first on a real app-submitted Learn Card package, then augmented with private NAS archive clips from `/Volumes/Dashcams/Blackvue DR770X Box` for multi-channel examples and media measurements.

Use `BlackVue DR770X Box` as the public app model name.

## App Submission Evidence

The app-submitted learning package verified the actual card layout and model metadata path:

- Volume name: `BLACKVUE`.
- `BlackVue/Record` - recording folder.
- `BlackVue/Config` - model/settings folder, not imported as footage.
- `BlackVue/Config/version.bin` - model evidence for `BlackVue DR770X Box`.
- `BlackVue/Config/micom_version.bin` - model evidence for `BlackVue DR770X Box`.
- `BlackVue/Config/config.ini` - safe setting keys only; private values remain excluded.

The submitted card contained four copyable `NF` clips:

- `19991231_170101_NF.mp4`
- `19991231_170201_NF.mp4`
- `19991231_170301_NF.mp4`
- `19991231_170401_NF.mp4`

The 1999 filenames indicate an unset or incorrect dashcam clock. Treat those timestamps as camera-clock-suspect rather than a reason to discard clips.

## Source Notes

The NAS folder includes direct camera footage plus review/app media. Only direct camera clips were used for multi-channel filename and media-format evidence:

- `Driving Clips`
- `Parking Clips`

Excluded from profile evidence:

- `Clips of Dashcam`
- `App Screencaps`
- photos, thumbnails, product shots, and phone/camera footage

## Filename Patterns

The app submission and NAS clips both use BlackVue-style tokens:

`YYYYMMDD_HHMMSS_MODECHANNEL.mp4`

The archive copies append human descriptions after the token. The app already strips text after the first space when matching filenames, so these samples validate the same raw token pattern expected from camera files.

Examples:

- `20230427_154533_MF Driving down 35th, sunny.mp4`
- `20230427_154533_MO Driving down 35th, sunny.mp4`
- `20230427_154533_MR Driving down 35th, sunny.mp4`
- `20230428_231228_NF Night driving leaving Seattle and seeing stadiums.mp4`
- `20230428_092522_IF Whacking WS in Safeway parking lot.mp4`
- `20230428_195552_PO Van parking in front of me in parking garage.mp4`

Observed mode letters:

- `M` - manual or marked driving clip, provisional label.
- `N` - normal driving clip.
- `P` - parking clip.
- `I` - impact or event clip, provisional label.

Observed channel letters:

- `F` - front.
- `O` - interior cabin.
- `R` - rear.

## Observed Counts

App submission:

- `NF` - 4 files.
- `BlackVue/Record` and `BlackVue/Config` confirmed.
- Exact model evidence from `version.bin` and `micom_version.bin`.

NAS archive:

The direct camera clip set contained 38 MP4 files:

- `MF/MO/MR` - 4 files per channel.
- `NF/NO/NR` - 3 files per channel.
- `PF/PR` - 4 files per channel.
- `PO` - 6 files.
- `IF/IO/IR` - 1 file per channel.

Grouping by date, time, and mode produced:

- 14 total groups.
- 12 complete front/interior/rear triplets.
- 2 interior-only parking clips.

## Media Characteristics

Representative `ffprobe` results:

- Front (`F`) - H.264, 1920x1080, 60 fps or 59.94 fps, roughly 16.0 Mbps video, MP4.
- Interior (`O`) - H.264, 1920x1080, 30 fps or 29.97 fps, roughly 10.0 Mbps video, MP4.
- Rear (`R`) - H.264, 1920x1080, 30 fps or 29.97 fps, roughly 10.0 Mbps video, MP4.
- Typical clip duration - about 60 seconds.
- Audio track observed - MP3 around 160 kbps.

## Card Layout

The app submission confirmed `BlackVue/Record` and `BlackVue/Config`. The NAS archive confirmed additional channel and mode examples, but it is not a full card image.

## Exclude By Default

- `.Trashes/**`
- `.fseventsd/**`
- `.Spotlight-V100/**`
- `._*`
- `BlackVue/Config/config.ini`
- `BlackVue/Config/bt_ssid.bin`
- `BlackVue/System/**`

## Open Questions

- Validate a full DR770X Box card with `BlackVue/Record` and `BlackVue/Config` present.
- Confirm the exact user-facing meaning of `M` mode.
- Confirm whether `I` means impact, event, or both in this model family.
