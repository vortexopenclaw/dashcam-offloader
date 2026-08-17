# VIOFO A329S

## Status

Seed profile, based on one real 3CH sample card read-only scanned at `/Volumes/A329S` and official VIOFO product/support research.

Use `VIOFO A329S` as the public app model name. Treat channel count as variant metadata behind the scenes.

## Source References

- Official product page: <https://www.viofo.com/products/viofo-a329s-3ch-first-4k-front-2k-wide-210-fov-fisheye-cabin-2k-rear-dash-cam-with-starvis-2-sensor>
- Official firmware and manual hub: <https://www.viofo.com/pages/manual>
- Official support manual folder: <https://support.viofo.com/support/solutions/folders/19000151665>

The official product page confirms the sampled A329S 3CH configuration and describes it as a 4K front, 2K cabin, and 2K rear three-channel dash cam with SSD storage support. The official support/manual pages were checked, but a clean A329S PDF manual link was not exposed during this pass.

The official VIOFO collection page also lists A329S 1CH, A329S 2CH, A329S 2CH IR, and A329S 3CH configurations.

VIOFO also documents Multiplex Video for the A329S family. Treat this as an optional combined-output mode, not as a separate camera model.

Do not treat A329S as the same internal hardware platform as the A229 series. It can share a similar folder and filename family, but first-party testing confirmed the A329S uses a different processor/internal platform. Codec, bitrate, and transcode assumptions must be measured from direct A329S files rather than inherited from A229 profiles.

## Video Configuration Notes

Confirmed A329S 3CH resolution layout:

- Front: 3840x2160
- Interior: 2560x1440
- Rear: 2560x1440

The 2026-08-17 user-submitted 2CH maximum-bitrate card confirms a Front/Rear
configuration: 4K30 H.264 front at approximately 65.5 Mbps and 1440p30 H.264
rear at approximately 27 Mbps. It contained normal driving, protected clips,
and distinct parking continuous/low-bitrate, motion-detection, and
impact-detection groups. A 2CH card can coexist with older 3CH footage.

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

- 1CH - front. Official reference, not card-sampled yet.
- 2CH - front and rear. Official reference, not card-sampled yet.
- 2CH IR - front and interior. Official reference, not card-sampled yet.
- 3CH - front, interior, and rear. Validated from the sampled card.

## Multiplexed Video

Official VIOFO pages describe A329S Multiplex Video as a way to combine multiple camera views into a single split-screen video file for sharing or review. The sampled card did not include confirmed multiplexed primary recording samples, and the observed `.dashcamexport` folder is treated as an app/export cache.

Supported combinations to recognize once real filenames are validated:

- Off/default - separate camera files, as observed on the sampled card.
- 2CH side-by-side - front plus rear on A329S 2CH or A329S 3CH.
- 2CH side-by-side - front plus interior on A329S 2CH IR or A329S 3CH.
- 3CH stacked layout - front plus interior plus rear on A329S 3CH.

Reported layout details from Vortex Radar's A329S/T multiplexing review:

- 2CH multiplex uses side-by-side video, described as 7680x2160.
- 3CH multiplex uses the front view above two secondary views, described as 3840x3240.
- If a third camera is not part of a selected 2CH multiplex combination, it may remain as a separate file.

Importer behavior:

- Keep `DCIM/Movie/.dashcamexport/**` excluded by default as generated exports/cache.
- If multiplexed files are later observed in `DCIM/Movie`, `DCIM/Movie/Parking`, or `DCIM/Movie/RO`, treat them as footage only after the filename pattern is validated from a real card.

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
- Confirm whether 1CH, 2CH, and 2CH IR A329S variants use the same folder and suffix layout.
- Capture a real A329S multiplexed file to validate path, filename suffix, and whether it appears in the primary recording folders or only via `.dashcamexport`.
