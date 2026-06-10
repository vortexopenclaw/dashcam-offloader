# GoPro HERO / MAX Camera

## Status

- Profile: `profiles/gopro-hero-action-camera.yaml`
- Status: Generic GoPro family fallback.
- Purpose: Support newer, older, and mission-oriented GoPro cards before dedicated per-model profiles exist.

## Detection Strategy

The best GoPro path is shared family detection:

1. Detect a GoPro-style card from safe structure and filenames.
2. Parse only safe fields from `MISC/version.txt`.
3. Match `camera type` against the internal GoPro catalog.
4. Use the shared GoPro media handler for import and classification.
5. Add a dedicated model profile only when a real card proves model-specific behavior.

This avoids duplicating scanner logic for every GoPro generation while still identifying the exact model when the card exposes it.

## Safe Version Fields

Allowed from `MISC/version.txt`:

- `camera type`
- `firmware version`

Do not submit, log publicly, or document private fields such as serial numbers, Wi-Fi MAC addresses, network names, account identifiers, or other device identifiers.

## Covered Candidate Families

The internal catalog includes known GoPro candidates across:

- HERO4 Black / Silver
- HERO5 Black through HERO13 Black
- HERO11 Black Mini
- HERO compact / LIT HERO
- MAX / MAX2
- Fusion
- MISSION 1 / MISSION 1 PRO / MISSION 1 PRO ILS and bundle variants

These catalog rows are internal hints, not claims that every model has a dedicated validated profile.

## Media Handling

The generic GoPro profile imports media from every matching `DCIM/*GOPRO` folder and handles common GoPro MP4/photo naming. It excludes sidecars and thumbnails by default.

When exact recording mode is uncertain, keep the file transferable and label conservatively instead of hiding it.

