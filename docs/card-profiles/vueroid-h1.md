# Vueroid H1

Seed profile based on the 2026-06-09 app learning submission and the mounted
card `/Volumes/H1-QHD-INF`.

## Identification

- Public app model name: `Vueroid H1`
- High-confidence model evidence: `CONFIG/config.bin` contains
  `H1-QHD-INFINITE`.
- Firmware/config string observed on the mounted card:
  `H1-QHD-INFINITE V0.5.9`.
- Supporting volume label: `H1-QHD-INF`.
- `CONFIG/.boot.log` entries repeatedly report `1CH`.
- `CONFIG/.boot.log` also records a `DRIVE TO PARK` transition, confirming the
  card entered parking mode.

## Channels

- Confirmed as `1CH`.
- Treat all visible MP4 footage as front-channel footage.
- Visible filenames do not include the S1 physical channel token (`F`, `I`, or
  `R`). H1 samples use names such as `20260515_214744_INF_N.mp4`.

## Folder Mapping

- `INF/` -> driving
- `EVENT/` -> protected driving event
- `PARK/` -> parking
- `PEVENT/` -> parking event
- `USER/` -> manual
- `BOOKMARK/` -> non-video bookmark area, not imported by default
- `CONFIG/` -> camera configuration and logs, excluded from normal video import

## Observed Settings And Media Specs

- `CONFIG/config.bin` exposes model, firmware, and build-date strings, but not a
  readable named parking-mode setting.
- `CONFIG/.boot.log` exposes operational state clues such as `1CH`,
  `DRIVE ON`, `OFF-ACC OUT`, and `DRIVE TO PARK`.
- The mounted H1 sample includes `PARK/` clips and a `PEVENT/` clip after the
  `DRIVE TO PARK` transition. That confirms parking recording was active, but
  the readable config/log evidence does not name the exact parking mode.
- Sample driving and parking MP4s are H.264, 2560x1440, 30 fps, approximately
  22 Mbps.

## App Submission Notes

The initial app scan correctly captured the root folders, media file counts, mode
counts, and user notes, but selected `Vueroid S1 4K Infinite` because H1 shares
the same Vueroid folder layout and there was no H1 profile yet. The scan also
included `CONFIG/config.bin` as a support-file sample, but did not preserve the
safe model string inside it in `settingSnapshots`. That meant the strongest H1
identifier was available on the card but missing from the learning payload.

The scanner now treats config-like `.bin` files and text logs as eligible for
short safe setting evidence. Future learning submissions can include strings like
`H1-QHD-INFINITE V0.5.9`, plus concise operational clues like `1CH` and
`DRIVE TO PARK`, without uploading full settings dumps.
