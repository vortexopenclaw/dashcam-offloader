# Rove R2-4K Pro

Seed profile based on a real app-submitted Learn Card package plus Rove documentation.

## App Submission Evidence

- Submitted at `2026-06-09T04:06:32Z`.
- User-entered camera: Rove R2-4K Pro.
- User-entered channel setup: `1CH front`.
- Initial app scan selected the generic `New Dashcam` fallback.
- Root folder observed: `Video`.
- 26 files scanned, 25 downloadable MP4 clips found.
- Submitted filename pattern: `YYYY_MMDD_HHMMSS_SEQUENCE.MP4`, for example `2025_0221_103453_0001.MP4`.
- No support/config filenames were submitted.
- No videos, photos, GPS traces, serial numbers, Wi-Fi details, device IDs, or full settings dumps were uploaded.

## Classification

- `Video/` is currently mapped as normal/front footage.
- The submitted scan did not include separate parking, event, locked, or photo folders, so those are intentionally not guessed.
- Filenames do not contain a channel token. Treat this sampled variant as a 1-channel front camera.

## Supplemental References

- Rove support says the R2-4K Pro records MP4 using H.264 or H.265 depending on model/settings.
- The R2-4K Pro manual lists 3840x2160 at 30 fps as a supported recording mode.
- Existing NAS metadata notes measured R2-4K Pro driving clips as HEVC 3840x2160 30 fps at about 36.9 Mbps.

## Open Questions

- Whether parking, event, locked, or photo recordings use separate folders on this exact model/card state.
- Whether H.264 clips use the same folder and filename pattern.
