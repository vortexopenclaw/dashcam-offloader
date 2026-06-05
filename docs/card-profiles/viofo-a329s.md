# VIOFO A329S

## Status

Seed profile, based on one real 3CH sample card read-only scanned at `/Volumes/A329S` and official VIOFO product/support research.

Use `VIOFO A329S` as the public app model name. Treat channel count as variant metadata behind the scenes.

## Source References

- Official product page: <https://www.viofo.com/products/viofo-a329s-3ch-first-4k-front-2k-wide-210-fov-fisheye-cabin-2k-rear-dash-cam-with-starvis-2-sensor>
- Official firmware and manual hub: <https://www.viofo.com/pages/manual>
- Official support manual folder: <https://support.viofo.com/support/solutions/folders/19000151665>

The official product page confirms the sampled A329S 3CH configuration and describes it as a 4K front, 2K cabin, and 2K rear three-channel dash cam with SSD storage support. The official support/manual pages were checked, but a clean A329S PDF manual link was not exposed during this pass.

## Card Layout

Real-card observed:

- `DCIM/Movie` - normal driving recordings. 875 visible MP4 files.
- `DCIM/Movie/Parking` - parking recordings. 1800 visible MP4 files.
- `DCIM/Movie/RO` - protected/read-only event recordings. 180 visible MP4 files, mixed normal and parking suffixes.
- `DCIM/Photo` - still images. 3127 visible JPG files.
- `DCIM/FWA329S.bin` - firmware/model file, exclude from footage import.
- `DCIM/.diskdb` - database/cache file, exclude from footage import.
- `DCIM/Movie/.dashcamexport` - app/export cache and generated compositions, exclude from footage import.

## Filename Patterns

Visible MP4 and JPG files use:

`YYYY_MMDD_HHMMSS_SEQUENCECHANNEL.EXT`

Examples:

- `DCIM/Movie/2026_0601_162734_113670F.MP4`
- `DCIM/Movie/2026_0601_162734_113671I.MP4`
- `DCIM/Movie/2026_0601_162734_113672R.MP4`
- `DCIM/Movie/Parking/2026_0601_164932_113733PF.MP4`
- `DCIM/Movie/Parking/2026_0601_164932_113734PI.MP4`
- `DCIM/Movie/Parking/2026_0601_164932_113735PR.MP4`
- `DCIM/Movie/RO/2026_0528_132556_110967PF.MP4`
- `DCIM/Photo/2025_0922_080409_000019PF.JPG`

Observed channel suffixes:

- `F` - front
- `I` - interior
- `R` - rear
- `PF` - parking front
- `PI` - parking interior
- `PR` - parking rear

## Related-File Grouping

Group related files by year, month/day, time, and mode family. The sequence number changes by channel and should not be used as the grouping key by itself.

Observed groups:

- `DCIM/Movie`: mostly `F/I/R` triplets, with 291 complete triplets and 2 `F`-only groups.
- `DCIM/Movie/Parking`: 600 complete `PF/PI/PR` triplets.
- `DCIM/Movie/RO`: mixed protected normal and protected parking groups. Observed 21 complete `F/I/R` groups, 38 complete `PF/PI/PR` groups, 1 `F`-only group, and 1 `I/R` group.
- `DCIM/Photo`: still captures use the same suffix family but are not always complete triplets.

## Channel Variants

- 3CH - front, interior, and rear. Validated from the sampled card.
- 1CH and 2CH - keep as possible app variants only if future real-card evidence or official references confirm them.

## Exclude By Default

- `.Trashes/**`
- `.fseventsd/**`
- `.Spotlight-V100/**`
- `._*`
- `format.txt`
- `DCIM/.diskdb`
- `DCIM/FWA329S.bin`
- `DCIM/._FWA329S.bin`
- `DCIM/Movie/.dashcamexport/**`

## Open Questions

- Confirm whether `RO` only contains locked events or can also include manual saves.
- Confirm whether `PF/PI/PR` always means parking channel across all A329S firmware versions.
- Confirm whether 1CH and 2CH A329S variants exist and whether they use the same layout.
