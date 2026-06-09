# Rove R2-4K Pro Research

## Sources

- App-submitted Learn Card package `fb0592df-9c64-40cf-9627-cc5e49fb13e1`, received `2026-06-09T04:06:32Z`.
- Rove support article: <https://hc1.gorgias.help/en-US/what-file-format-and-codec-does-the-dashcam-use-for-video-recordings-3564147>
- Rove R2-4K Pro manual mirror: <https://www.manualslib.com/manual/3130610/Rove-R2-4k-Pro.html>
- Existing private NAS metadata reference in `docs/video-metadata-reference.md`.

## Submitted Card Layout

The submitted scan identified a single root recording folder:

- `Video`

The scan contained 25 MP4 clips and no submitted support/config filenames.

## Filename Pattern

Observed examples:

- `2025_0221_103453_0001.MP4`
- `2025_0221_103519_0002.MP4`
- `2025_0221_111525_0025.MP4`

Pattern:

```text
YYYY_MMDD_HHMMSS_SEQUENCE.MP4
```

The pattern contains a filename timestamp and sequence number, but no channel or mode token.

## Media Reference

Rove support documents Rove dashcams, including the R2-4K Pro, as recording MP4 files with H.264 or H.265 depending on model and settings.

The R2-4K Pro manual lists 3840x2160 at 30 fps as a supported recording mode.

Existing NAS metadata reference measured Rove R2-4K Pro driving clips as HEVC 3840x2160 30 fps at about 36.9 Mbps.

## Implementation Notes

- Add profile support conservatively from the submitted `Video/` folder and filename pattern.
- Do not infer parking/event/photo folder layouts from this scan because they were not present.
- Keep codec/resolution/bitrate as supplemental media metadata only, not model identity proof.
