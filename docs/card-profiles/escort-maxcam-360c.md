# Escort MAXcam 360c — Card Profile

**Type:** Combo radar detector + dashcam (1CH)  
**Manufacturer:** ESCORT Inc. (©2021)  
**FCC ID:** QKLMXCAM  
**App:** Drive Smarter  
**GPS:** Yes (proprietary _gps.bin sidecar + GPS lockout database)  
**Source:** Real card sampled

---

## Card Structure

```
[root]  (volume label: NO NAME — generic, not a detection signal)
├── Normal/
│   └── MAXcam360c/
│       ├── YYYYMMDD_NNNN_VID.MOV         ← loop-recorded clips
│       ├── YYYYMMDD_NNNN_VID_gps.bin     ← GPS sidecar (after GPS lock)
│       ├── YYYYMMDD_NNNN_VID_gsensor.bin  ← G-sensor sidecar
│       └── .deleted.MOV                   ← deleted clip placeholder
├── Event/
│   └── MAXcam360c/
│       └── YYYYMMDD_NNNN_SOS.MOV          ← G-sensor / locked clips
├── DATA/
│   ├── serial_num.txt                   ← camera serial number
│   └── gps_userdb.bin                   ← radar GPS lockout database
└── System Volume Information/
```

---

## Filename Patterns

| Type | Pattern | Example |
|------|---------|--------|
| Normal video | `YYYYMMDD_NNNN_VID.MOV` | `20251011_0052_VID.MOV` |
| Event video | `YYYYMMDD_NNNN_SOS.MOV` | `20250127_0012_SOS.MOV` |
| GPS sidecar | `YYYYMMDD_NNNN_VID_gps.bin` | `20251011_0052_VID_gps.bin` |
| G-sensor sidecar | `YYYYMMDD_NNNN_VID_gsensor.bin` | `20251011_0052_VID_gsensor.bin` |

- `YYYYMMDD` — date; no time component
- `NNNN` — 4-digit per-day sequence, resets to 0001 each day
- `_VID` — normal loop; `_SOS` — event/emergency

---

## Sequence Behavior

Per-date, shared across Normal/MAXcam360c/ and Event/MAXcam360c/ on the same date.

---

## GPS/G-sensor Sidecars

Not present for every clip — begin appearing once GPS receiver acquires satellite lock. Early clips recorded before GPS lock have no sidecars. Both `_gps.bin` and `_gsensor.bin` start at the same clip.

---

## Ancillary Files

- `DATA/serial_num.txt` — plain-text serial number (device-created)
- `DATA/gps_userdb.bin` — GPS lockout database for the radar detector
- `Normal/MAXcam360c/.deleted.MOV` — placeholder for overwritten/deleted clips; not a real video

---

## Video Specifications

| Setting | Value | Confirmed |
|---------|-------|-----------|
| Codec | H.264 | confirmed |
| Resolution | 2560×1440 | confirmed |
| Frame rate | 30 fps | confirmed |
| Container | MOV | confirmed |

Mounted `/Volumes/NO NAME` pass on 2026-06-08 measured:

- Normal clip `Normal/MAXcam360c/20251010_0047_VID.MOV`: H.264 2560x1440 30 fps, about 28.6 Mbps, 60.1 seconds.
- Event clip `Event/MAXcam360c/20250127_0012_SOS.MOV`: H.264 2560x1440 30 fps, about 28.4 Mbps, 60.1 seconds.
- Parsed files: 65 normal driving clips and 1 locked/event clip.

Safe version file:

- `MasterVersionInfo_SW_v1.13_HW_v1.01.bin`: `MasterVersion:1.13`, `Main:R22`, `Antenna:R07`, `DSP:2.11`, `BLE:R07`, `HW_VERSION:1.01`.

---

## Features

- **Radar/laser/MRCD detection:** Yes (combined device)
- **GPS lockout:** Yes (stored in DATA/gps_userdb.bin)
- **Parking mode:** Yes — requires hardwire power kit
- **App:** Drive Smarter

---

## Detection Notes

Primary signal: `Normal/MAXcam360c/` folder. The literal string "MAXcam360c" as a subfolder is unique among all profiled cameras. Volume label `NO NAME` is generic — do not use. `DATA/serial_num.txt` and `DATA/gps_userdb.bin` provide supporting evidence.
