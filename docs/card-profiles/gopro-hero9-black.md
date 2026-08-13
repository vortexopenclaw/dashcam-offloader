# GoPro HERO9 Black

## Status

- Profile: `profiles/gopro-hero9-black.yaml`
- Status: Seeded from two real HERO9 Black cards and official GoPro references.
- Detection confidence: High when `MISC/version.txt` safely reports `camera type: HERO9 Black`.

## Card Layout

Observed HERO9 cards use:

- `DCIM/100GOPRO/`
- `MISC/version.txt`

GoPro media can overflow into later numbered folders such as `DCIM/101GOPRO/`, so the scanner imports every matching `DCIM/*GOPRO` folder instead of only `100GOPRO`.

The user-provided HERO9 cards were both mounted with stale `U3000PRO` volume labels from prior use in another camera. Treat volume labels as weak sanity-check evidence only, never as proof of the GoPro model.

## Safe Model Evidence

`MISC/version.txt` is strong GoPro evidence because it contains safe model and firmware fields:

- `camera type`
- `firmware version`

The same file can also contain private serial, Wi-Fi MAC, and related identifiers. App submissions and docs must only preserve safe model/firmware fields and must not store or publish private identifiers.

## Media Naming

Video files use GoPro chaptered names such as:

- `GH010001.MP4`
- `GX010001.MP4`
- `GXAA9552.MP4`
- `GXAB9555.MP4`, `GXAB9556.MP4`, ...

Photo and raw photo files use names such as:

- `GOPR0001.JPG`
- `G0010001.JPG`
- `GOPR0001.GPR`

Sidecars such as `.LRV` and `.THM` are excluded from copy/import.

## Recording Modes

The profile supports these user-facing recording-type buckets:

- Continuous / regular video
- Looping
- Time Lapse
- TimeWarp
- Time Lapse / TimeWarp fallback
- Photos / burst-style photos / raw photos

Filename alone is not enough to distinguish normal GoPro video from time-lapse or TimeWarp video because GoPro reuses the same GH/GX MP4 naming family. Prefer safe sampled metadata when available, then duration/run heuristics.

Useful observed/default behavior:

- HERO9 continuous recording is commonly 5K30.
- HERO9 5K30 high-bitrate chapters are approximately 4 GB, around five minutes per chapter.
- HERO9 5-minute looping creates one-minute chapters.
- The user's loop chunks can share a four-character prefix such as `GXAB` or `GXAD`, followed by adjacent sequence numbers.
- One sampled workflow uses 4K30 five-minute loops for driving captures.

## Loop Combining

When GoPro looping chunks share the same `DCIM/*GOPRO` folder, four-character prefix, and adjacent numeric sequence, the app should show them as one download item such as `GXAD9565-9570.MP4`.

The combined item preserves the source list internally and uses a lossless/passthrough MP4 export during copy so the final file is one continuous loop instead of several one-minute chunks.

Do not group normal GoPro chapter files only because they are adjacent. Loop grouping should require a loop-like run: same prefix, adjacent sequence, compatible durations, and matching GoPro media folder.

## UI Behavior

GoPro is an action camera profile, not a multichannel dashcam profile:

- Regular video should display as `Regular Recording`, not `Driving`.
- The channel filter should be hidden for single-lens GoPro media.
- If a 360 GoPro card exposes a `360_primary` channel, the app still treats it as a single primary media stream for filter purposes.

## Defaults

For GoPro cards, regular/continuous and looping videos should be selected by default. Time Lapse, TimeWarp, and photos should remain visible but unchecked by default unless the user changes saved local preferences.

## Startup Scan

Mounted GoPro cards should scan automatically when they appear in the source list, so `MISC/version.txt` detection and HERO model display are available before the user clicks the card.

## Learning Submission

Learning submissions should include sanitized filename sequence summaries. For GoPro, those summaries must preserve enough pattern data to see full loop groups such as `GXAB9555` through `GXAB9560` without sending video bytes, thumbnails, serial numbers, Wi-Fi identifiers, or private `version.txt` fields.
