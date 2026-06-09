# BlackVue DR770X Box Research Notes

## App Submission Evidence

The real app-submitted Learn Card package verified:

- Kind: card learning / training submission.
- User-supplied model: BlackVue DR770X Box.
- Volume name: `BLACKVUE`.
- Selected profile: `blackvue-dr770x-box`.
- Selected profile confidence: high.
- Model metadata matched from `BlackVue/Config/version.bin` and `BlackVue/Config/micom_version.bin`.
- Card layout: `BlackVue/Record` and `BlackVue/Config`.
- Copyable samples: four `NF` MP4 clips.
- Filename clock issue: sample filenames were dated `19991231`, so the app must keep camera-clock-suspect clips transferable.

The submission also confirmed that stored Learn Card data remains a structural/sanitized package rather than video or photo bytes. The Worker now strips sensitive support filenames such as `bt_ssid.bin` from future stored submissions.

## NAS Evidence

Read-only source:

- `/Volumes/Dashcams/Blackvue DR770X Box`

Direct camera footage folders:

- `Driving Clips`
- `Parking Clips`

Folders intentionally excluded from profile evidence:

- `Clips of Dashcam` - review/b-roll footage of the product.
- `App Screencaps` - screen recordings of the BlackVue app.
- `Photos` - product/camera photos and still images.

## Findings

- The app submission is the primary card-layout and model-detection evidence.
- The NAS archive contains 38 direct camera MP4 clips across driving and parking examples.
- Filenames preserve BlackVue-style `YYYYMMDD_HHMMSS_MODECHANNEL` tokens, with human descriptions appended after a space.
- The three observed channel letters are `F`, `O`, and `R`.
- `O` maps to the interior cabin camera in this sample set.
- Observed mode letters are `M`, `N`, `P`, and `I`.
- Most groups are complete front/interior/rear triplets. Two parking examples are interior-only.

## Representative Media Measurements

Measured with `ffprobe` from direct camera clips:

- `MF`: H.264, 1920x1080, 60 fps, about 16.0 Mbps video, 60.98 seconds.
- `MO`: H.264, 1920x1080, 30 fps, about 10.0 Mbps video, 60.97 seconds.
- `MR`: H.264, 1920x1080, 30 fps, about 10.0 Mbps video, 60.97 seconds.
- `PF`: H.264, 1920x1080, 59.94 fps, about 16.0 Mbps video, 60.04 seconds.
- `PO`: H.264, 1920x1080, 29.97 fps, about 10.0 Mbps video, 59.47 seconds.
- `PR`: H.264, 1920x1080, 29.97 fps, about 10.0 Mbps video, 59.71 seconds.

Audio observed on an `MF` sample:

- MP3, about 160 kbps.

## Privacy Notes

This research used media container fields and filenames only. Do not ingest private BlackVue config files or store serial, network, GPS trace, account, or cloud fields when a full card is scanned later.
