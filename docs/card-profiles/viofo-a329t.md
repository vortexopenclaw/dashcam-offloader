# VIOFO A329T

## Status

Experimental profile, based on official VIOFO product-family references and user-provided filename/channel evidence. No real A329T card has been inspected yet.

Use `VIOFO A329T` as the public app model name. Treat channel count as variant metadata behind the scenes.

## Source References

- Official front and telephoto collection: <https://www.viofo.com/collections/front-telephoto-dashcam>
- Official A329T 2CH product link from VIOFO collection: <https://www.viofo.com/products/viofo-a329t-2ch-4k-60fps-2k-telephoto-dashcam>
- Official A329T 3CH product link from VIOFO collection: <https://www.viofo.com/products/viofo-a329t-3ch-4k-front-2k-telephoto-camera-2k-rear-camera-sony-starvis-2-sensor>

VIOFO lists A329T as its telephoto system, pairing a front camera with a telephoto camera. VIOFO also lists A329T 2CH and A329T 3CH configurations.

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

## Open Questions

- Confirm folder layout with a real A329T card.
- Confirm whether normal front/rear/telephoto files use `F/R/T`.
- Confirm whether parking files use `PF/PR/PT` or another suffix family.
- Confirm whether protected files live under `DCIM/Movie/RO` like A329S.
- Identify safe model-detection evidence, such as firmware filename or non-unique model strings.
