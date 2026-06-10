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

## Recording Types and Channels

GoPro-family cards should use action-camera language:

- Normal videos display as `Regular Recording`, not `Driving`.
- Loop clips display as `Looping`.
- Time Lapse and TimeWarp stay separate when metadata or strong heuristics can distinguish them.
- Single-lens HERO and Mission media should not show a channel filter.
- MAX/Fusion/MAX2 360 media may use an internal `360_primary` channel, but the app should still hide channel selection unless a future real card proves multiple independent media streams.

## Loop Groups

GoPro loop chunks can appear as adjacent one-minute files with the same four-character prefix, for example `GXAB9555.MP4` through `GXAB9560.MP4`. The app should group those as one loop item for download and use lossless/passthrough concatenation when copying.

## Learning Submissions

Learning submissions should include sanitized filename sequence summaries so maintainers can see complete GoPro prefix/sequence runs, overflow folders, and missing chunks without receiving media bytes or private device identifiers.
