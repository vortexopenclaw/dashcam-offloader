# VIOFO A229 Pro

## Status

Seed profile, based on real 3CH sample cards read-only scanned at `/Volumes/Untitled` and the
official VIOFO A229 Pro manual (V26.01.09).

## Model Detection

No high-confidence model-identifying file was found on this real-card sample. The A229 Pro does
not store a permanent firmware file in `DCIM/`, unlike the VIOFO A329S which stores
`DCIM/FWA329S.bin`. The firmware file `FWA229P.bin` is placed at the card root only during
firmware updates and should be removed by reformatting afterward.

Detection relies on supporting evidence only: folder structure and filename pattern. The absence
of any `DCIM/FW*.bin` file is a weak negative signal against A329S and other VIOFO models that
do store a permanent firmware file.

Weak evidence:

- Volume label was `Untitled` on the sample card - user-renamable, not useful for detection.

Do not use:

- `DCIM/.diskdb` - binary cache file, no readable model strings found.

## Card Layout

Real-card observed:

- `DCIM/Movie` - loop recordings (normal driving and time-lapse). Latest temporary card:
  210 F + 210 I + 210 R = 630 MP4 files.
- `DCIM/Movie/Parking` - parking recordings. The manual says this folder is used for
  auto event detection, time-lapse, and low bitrate, but the latest sampled card's
  parking clips were user-confirmed auto event detection from motion/impact triggers.
  Latest temporary card: 1866 PF + 1866 PI + 1866 PR = 5598 MP4 files.
- `DCIM/Movie/RO` - emergency/locked recordings. 1 F + 1 I + 1 R = 3 MP4 files on the
  latest temporary card.
- `DCIM/Photo` - snapshots. 3 JPG files (F, I, R) on the latest temporary card.
- `DCIM/.diskdb` - binary database/cache file. Exclude from footage import.
- `format.txt` - empty file at card root. Exclude.

No separate Event or Emergency top-level folder was observed. The manual confirms locked videos
go to `DCIM/Movie/RO`, not a separate folder.

## Filename Pattern

All video and photo files use:

`YYYY_MMDD_HHMMSS_SEQUENCECHANNEL.EXT`

Real examples:

- `DCIM/Movie/2026_0501_162928_000538F.MP4`
- `DCIM/Movie/2026_0501_162928_000539I.MP4`
- `DCIM/Movie/2026_0501_162928_000540R.MP4`
- `DCIM/Movie/Parking/2026_0501_194819_001135PF.MP4`
- `DCIM/Movie/Parking/2026_0501_194819_001136PI.MP4`
- `DCIM/Movie/Parking/2026_0501_194819_001137PR.MP4`
- `DCIM/Movie/RO/2026_0501_162128_000511F.MP4`
- `DCIM/Movie/RO/2026_0501_162128_000512I.MP4`
- `DCIM/Movie/RO/2026_0501_162128_000513R.MP4`
- `DCIM/Photo/2026_0501_162155_000514F.JPG`
- `DCIM/Photo/2026_0501_162155_000515I.JPG`
- `DCIM/Photo/2026_0501_162155_000516R.JPG`

Observed channel suffixes:

- `F` - front
- `I` - interior
- `R` - rear
- `PF` - parking front
- `PI` - parking interior
- `PR` - parking rear

The manual also documents `T` (telephoto) and `PT` (parking telephoto) for cameras with an
optional telephoto accessory. Neither was present on the sample card.

## Sequence Number

The sequence number is a global monotonic counter spanning all channels and all recording modes.
Observed range on the sample card: `000511` (earliest RO clip, May 1) through `006759` (last
parking clip, May 13). The counter does not reset between modes or between normal and parking
sessions.

The manual example shows 5-digit numbers (`00001`). The real card shows 6-digit numbers. The
counter grows as needed and should be treated as variable-length.

## Related-File Grouping

Group related files by year, month/day, and time. The sequence number is not the grouping key.

Observed groups on the latest temporary card:

- `DCIM/Movie`: 210 complete F/I/R triplets. No incomplete groups on this sample.
- `DCIM/Movie/Parking`: 1866 complete PF/PI/PR triplets. No incomplete groups on this sample.
- `DCIM/Movie/RO`: 1 complete F/I/R triplet.
- `DCIM/Photo`: 1 complete F/I/R triplet.

## Measured Video Metadata

Latest temporary 3CH card sampled at `/Volumes/Untitled`:

- F driving: H.264, 3840x2160, 30 fps, about 36.0 Mbps stream bitrate, 60-second clips.
- I driving: H.264, 1920x1080, 30 fps, about 15.6 Mbps stream bitrate, 60-second clips.
- R driving: H.264, 2560x1440, 30 fps, about 24.0 Mbps stream bitrate, 60-second clips.
- PF parking auto event: H.264, 3840x2160, 30 fps, about 4.1 Mbps stream bitrate,
  60-second clips.
- PI parking auto event: H.264, 1920x1080, 30 fps, about 3.9 Mbps stream bitrate,
  60-second clips.
- PR parking auto event: H.264, 2560x1440, 30 fps, about 4.1 Mbps stream bitrate,
  60-second clips.

Parking clips on this card use 32 MiB file sizes across PF/PI/PR, with roughly 4.47 Mbps
container bitrate. Ariel noted this camera was likely set to High/Max bitrate rather than the
standard/default bitrate.

Additional direct-camera NAS examples from the A229 Pro folder measured:

- F driving: H.264, 3840x2160, 30 fps, about 36.0 Mbps stream bitrate.
- I driving: H.264, 1920x1080, 30 fps, about 15.6 Mbps stream bitrate.
- R driving: H.264, 2560x1440, 30 fps, about 23.8 Mbps stream bitrate.
- PF parking motion/auto event: H.264, 2560x1440, 30 fps, about 12.3 Mbps stream bitrate.
- PI parking motion/auto event: H.264, 1920x1080, 30 fps, about 6.6 Mbps stream bitrate.
- PR parking motion/auto event: H.264, 2560x1440, 30 fps, about 14.8 Mbps stream bitrate.

## Exclude By Default

- `.Trashes/**`
- `.fseventsd/**`
- `.Spotlight-V100/**`
- `._*`
- `format.txt`
- `DCIM/.diskdb`

## Media Metadata Notes

Mounted-card pass on 2026-06-08 measured the current `/Volumes/Untitled` card:

- Driving/locked F: H.264 3840x2160 30 fps at about 36.0 Mbps.
- Driving/locked I: H.264 1920x1080 30 fps at about 15.6 Mbps.
- Driving/locked R: H.264 2560x1440 30 fps at about 23.8 Mbps.
- Parking PF/PI/PR keep the same resolutions and 30 fps but drop to about 3.9-4.1 Mbps.
- Root `format.txt` is present but empty and should only be treated as an exclusion signal.

## Open Questions

- Whether the RO folder can also contain locked parking clips (as observed on A329S). Only
  locked normal clips were present on this sample.
- Need separate parking time-lapse and parking low-bitrate samples to measure bitrate,
  frame rate, audio behavior, and whether they can be distinguished from auto event
  detection beyond user-selected settings.
- Whether A229 Pro exposes current camera settings in a readable config file on the card.
  `/Volumes/Untitled` was not mounted during the 2026-06-08 follow-up, and the NAS A229 Pro
  archive did not contain copied settings/config files.
- Whether the telephoto `T`/`PT` channel behaves identically to other channels in grouping.
- Whether a high-confidence detection signal exists (e.g., a model string in `.diskdb` readable
  via a different access method, or a firmware-version file written by the camera).
- Whether the sequence counter resets on card format or persists until overflow.
