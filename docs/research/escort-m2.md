# Escort M2 — Research Notes

## Sources

- Real card scan (volume label: M2)
- Official Escort M2 User Manual (AW-1210091-1A, ESCORT, 2025): https://cdn.shopify.com/s/files/1/1935/1881/files/AW-1210091-1A_ESCORT_M2_WEB_MANUAL.pdf?v=1747321014

## Card Scan Findings

### Confirmed from real card

- Volume label: `M2`
- Folders: `Normal/`, `Photo/` at card root
- Video pattern: `YYYYMMDD_NNNN_CAM.MP4`
- Photo pattern: `YYYYMMDD_NNNN_CAM_IMG.JPG`
- GPS sidecar: `.map` paired with every video clip in `Normal/`
- Sequence: per-date (two separate date sessions observed, each with independent sequences)
- `Event/` folder: not present on sampled card (no events during sampling)

### Not confirmed from card

- Video codec (H.264 assumed)
- Resolution (1080P listed in manual; 720P also available as setting)
- Frame rate (30 fps assumed)
- Clip duration (1/2/3 min configurable)

## Manual Notes

- Copyright: ©2025 ESCORT INC.
- App: Drive Smarter
- Parking mode: Yes, requires hardwire power kit (ACC + constant power)
- ADAS: FCWS, LDWS
- Loop recording: 1, 2, or 3 minute clips
- Resolutions: 1080P (default), 720P
- Event recording: G-sensor triggered + manual button lock
- Speed camera alerts via Drive Smarter app

## Open Questions

1. Exact .map file binary format — ESCORT proprietary; content not decoded
2. Does Event/ share the per-day counter with Normal/?
3. Codec confirmation requires ffprobe on a real clip
4. Does Photo/ share the same per-day sequence as Normal/ (i.e., if Normal/ has clips 0001–0029, does Photo/ continue from 0030)?
