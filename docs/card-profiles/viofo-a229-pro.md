# VIOFO A229 Pro

## Status

Seed profile, based on one real 3CH sample card read-only scanned at `/Volumes/Untitled` and the
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

- Volume label was `Untitled` on the sample card — user-renamable, not useful for detection.

Do not use:

- `DCIM/.diskdb` — binary cache file, no readable model strings found.

## Card Layout

Real-card observed:

- `DCIM/Movie` — loop recordings (normal driving and time-lapse). 208 F + 208 I + 208 R = 624
  MP4 files on the sample card.
- `DCIM/Movie/Parking` — parking recordings (auto event, time-lapse, and low bitrate).
  1866 PF + 1866 PI + 1866 PR = 5598 MP4 files on the sample card.
- `DCIM/Movie/RO` — emergency/locked recordings. 1 F + 1 I + 1 R = 3 MP4 files on the
  sample card.
- `DCIM/Photo` — snapshots. 3 JPG files (F, I, R) on the sample card.
- `DCIM/.diskdb` — binary database/cache file. Exclude from footage import.
- `format.txt` — empty file at card root. Exclude.

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

- `F` — front
- `I` — interior
- `R` — rear
- `PF` — parking front
- `PI` — parking interior
- `PR` — parking rear

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

Observed groups:

- `DCIM/Movie`: 208 complete F/I/R triplets. No incomplete groups on this sample.
- `DCIM/Movie/Parking`: 1866 complete PF/PI/PR triplets. No incomplete groups on this sample.
- `DCIM/Movie/RO`: 1 complete F/I/R triplet.
- `DCIM/Photo`: 1 complete F/I/R triplet.

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
- Whether parking time-lapse and parking low-bitrate recordings use the same folder, filename
  pattern, and channel suffixes as parking auto event recordings, or whether they are
  distinguishable.
- Whether the telephoto `T`/`PT` channel behaves identically to other channels in grouping.
- Whether a high-confidence detection signal exists (e.g., a model string in `.diskdb` readable
  via a different access method, or a firmware-version file written by the camera).
- Whether the sequence counter resets on card format or persists until overflow.
