# Escort MAXcam 360c — Research Notes

## Sources

- Real card scan (volume label: NO NAME)
- Official Escort MAXcam 360c User Manual (ESCORT, 2021): https://cdn.shopify.com/s/files/1/1935/1881/files/ESCORT_MAXCAM_360c_WEB_MANUAL.pdf?v=1651263457
- FCC ID: QKLMXCAM

## Card Scan Findings

### Confirmed from real card

- Volume label: `NO NAME` — generic, not a detection signal
- Folders: `Normal/MAXcam360c/`, `Event/MAXcam360c/`, `DATA/`
- Normal clip pattern: `YYYYMMDD_NNNN_VID.MOV`
- Event clip pattern: `YYYYMMDD_NNNN_SOS.MOV`
- GPS sidecar: `YYYYMMDD_NNNN_VID_gps.bin` (begins after GPS lock)
- G-sensor sidecar: `YYYYMMDD_NNNN_VID_gsensor.bin` (begins alongside _gps.bin)
- Ancillary: `DATA/serial_num.txt`, `DATA/gps_userdb.bin`
- Safe version evidence: `MasterVersionInfo_SW_v1.13_HW_v1.01.bin`
- Placeholder: `Normal/MAXcam360c/.deleted.MOV`
- Sequence: per-date; GPS sidecars began at a specific clip number mid-session (after GPS lock acquired)
- `.fseventsd/` and `System Volume Information/` also present (macOS and Windows artifacts)
- Current mounted-card pass parsed 65 normal driving clips and 1 locked/event clip.
- Representative normal and event clips are H.264 2560x1440 30 fps at about 28.4-28.6 Mbps.
- Safe version strings include `MasterVersion:1.13`, `Main:R22`, `Antenna:R07`, `DSP:2.11`, `BLE:R07`, and `HW_VERSION:1.01`.

### Not confirmed from card

- Proprietary `_gps.bin` / `_gsensor.bin` sidecar formats

## Manual Notes

- Combined radar+dashcam. Radar, laser, MultaRadar CD/CT (MRCD) detection.
- Copyright: ©2021 ESCORT Inc.
- GPS lockout: user-defined points stored in DATA/gps_userdb.bin
- Parking mode: Yes, motion detection. Requires hardwire power kit.
- App: Drive Smarter
- DEFENDER camera database integrated

## Notes on Non-Device Files

- `Normal/MAXcam360c/.deleted.MOV` is written by the device as a placeholder when a clip is overwritten by loop recording or manually deleted. Not a video file.
- `System Volume Information/` — created by Windows when the card is read on a Windows machine.
- `DATA/` files are device-created during normal operation.

## Open Questions

1. `_gps.bin` binary format — ESCORT proprietary; not decoded
2. Is GPS lock the only trigger for sidecars starting mid-session?
3. Does Event/ share the per-day sequence counter with Normal/?
4. Codec confirmation requires ffprobe on a real clip
