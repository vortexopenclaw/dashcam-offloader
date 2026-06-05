# VIOFO A329T

## Status

Experimental profile, based on official VIOFO product-family references and user-provided filename/channel evidence. No real A329T card has been inspected yet.

Use `VIOFO A329T` as the public app model name. Treat channel count as variant metadata behind the scenes.

## Source References

- Official front and telephoto collection: <https://www.viofo.com/collections/front-telephoto-dashcam>
- Official A329T 2CH product link from VIOFO collection: <https://www.viofo.com/products/viofo-a329t-2ch-4k-60fps-2k-telephoto-dashcam>
- Official A329T 3CH product link from VIOFO collection: <https://www.viofo.com/products/viofo-a329t-3ch-4k-front-2k-telephoto-camera-2k-rear-camera-sony-starvis-2-sensor>

VIOFO lists A329T as its telephoto system, pairing a front camera with a telephoto camera. VIOFO also lists A329T 2CH and A329T 3CH configurations.

VIOFO also documents Multiplex Video on A329T, including telephoto camera support. Treat this as an optional combined-output mode, not as a separate camera model.

## Relationship to A329S

A329T appears to use the same VIOFO A329-series filename family as A329S, but swaps the interior channel for a telephoto channel.

User-provided example:

- `2025_0612_055737_000103T.MP4`

## Filename Pattern

Expected MP4 filename family:

`YYYY_MMDD_HHMMSS_SEQUENCECHANNEL.MP4`

Observed from user-provided evidence:

- `T` - telephoto

Expected from A329S similarity, pending real-card validation:

- `F` - front
- `R` - rear

Do not assume parking or protected suffix behavior until a real A329T card is inspected.

## Channel Variants

- 2CH - front and telephoto. Official reference and user-confirmed channel roles.
- 3CH - front, rear, and telephoto. Official reference and user-confirmed channel roles.

## Multiplexed Video

Official VIOFO A329T pages describe Multiplex Video as combining selected camera views, including the telephoto camera, into a single split-screen file.

Supported combinations to recognize once real filenames are validated:

- Off/default - separate camera files.
- 2CH side-by-side - front plus telephoto on A329T 2CH or A329T 3CH.
- 2CH side-by-side - front plus rear on A329T 3CH, if selectable.
- 3CH stacked layout - front plus telephoto plus rear on A329T 3CH.

Reported layout details from Vortex Radar's A329S/T multiplexing review:

- 2CH multiplex uses side-by-side video, described as 7680x2160.
- 3CH multiplex uses the front view above two secondary views, described as 3840x3240.
- If a third camera is not part of a selected 2CH multiplex combination, it may remain as a separate file.

Importer behavior:

- Keep `DCIM/Movie/.dashcamexport/**` excluded by default as generated exports/cache, inferred from the related A329S profile.
- If multiplexed files are later observed in `DCIM/Movie`, `DCIM/Movie/Parking`, or `DCIM/Movie/RO`, treat them as footage only after the filename pattern is validated from a real A329T card.

## Open Questions

- Confirm folder layout with a real A329T card.
- Confirm whether normal front/rear/telephoto files use `F/R/T`.
- Confirm whether parking files use `PF/PR/PT` or another suffix family.
- Confirm whether protected files live under `DCIM/Movie/RO` like A329S.
- Identify safe model-detection evidence, such as firmware filename or non-unique model strings.
- Capture a real A329T multiplexed file to validate path, filename suffix, and whether it appears in the primary recording folders or only via `.dashcamexport`.
