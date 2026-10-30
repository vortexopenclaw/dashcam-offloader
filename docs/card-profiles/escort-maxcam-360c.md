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
| Codec | H.264 | assumed |
| Resolution | 1920×1080 | assumed |
| Frame rate | 30 fps | assumed |
| Container | MOV | confirmed |

The [historical PR #5 reconciliation](../research/card-spec-pr5-reconciliation.md#maxcam-measurements-pending-corroboration) preserves branch-reported 1440p measurements pending corroboration. Those reports do not upgrade the assumptions above or establish factory defaults.

---

## Features

- **Radar/laser/MRCD detection:** Yes (combined device)
- **GPS lockout:** Yes (stored in DATA/gps_userdb.bin)
- **Parking mode:** Yes — requires hardwire power kit
- **App:** Drive Smarter

---

## Detection Notes

Primary signal: `Normal/MAXcam360c/` folder, with `Event/MAXcam360c/` as supporting structural evidence when present. The literal string "MAXcam360c" as a subfolder is unique among all profiled cameras. Volume label `NO NAME` is generic; do not use it for detection. Do not read or publish `DATA/serial_num.txt` or `DATA/gps_userdb.bin` contents for detection: they contain a device serial number and user GPS lockout data. Prefer model-named recording folders and clip patterns. This guidance does not change the YAML profile's presence-only supporting signals.

PR #5 reports that `MasterVersionInfo_SW_v1.13_HW_v1.01.bin` was manually copied for a firmware update. Keep that [historical provenance warning](../research/card-spec-pr5-reconciliation.md#maxcam-measurements-pending-corroboration); a copied update file is not proof of recorder identity or installed firmware and must not become a normal-card requirement.
