# Cobra Road Scout — Card Profile

## Overview

The Cobra Road Scout is a combined radar detector and dashcam on a single windshield-mounted unit. It connects to the Cobra iRadar app for live crowd-sourced alerts and to the Cobra Drive HD app for footage review. On the storage side it behaves like a simple single-channel dashcam: all footage goes into one folder, with no separate subfolders for locked or event clips.

---

## Card Structure

```
<card root>/
├── rom.bin               # Permanent — likely DEFENDER database or radar firmware
└── DCIM/
    └── RoadScout/        # All video clips (normal, locked, emergency)
```

Volume label: **NO NAME** (generic default — not branded by Cobra).

---

## Filename Pattern

```
YYYYMMDD_NNNN_VID.MOV
```

| Component | Format | Example |
|-----------|--------|---------|
| Date | 8 digits (YYYYMMDD) | `20230311` |
| Sequence | Zero-padded 4 digits, resets per day | `0003` |
| Suffix | Always `_VID` | |
| Extension | Uppercase `.MOV` | |

Example: `20230311_0003_VID.MOV`

The `_VID` suffix is unusual — most dashcams use a channel letter or mode code at that position. All files use the same pattern regardless of recording mode.

---

## Folder Layout

### `DCIM/RoadScout/`

All clips land here — continuous loop recordings, G-sensor impact locks, and emergency manual locks (MARK hold). There is no separate subfolder for locked or event clips. Locked clips are protected from loop overwrite but remain in the same folder with the same filename structure.

---

## Sequence Number

The sequence counter resets to `0001` at the start of each day. It is **not** a global counter — ordering clips across days requires combining date + sequence together, not sequence alone. Zero-padded to 4 digits.

---

## `rom.bin` at Card Root

A file named `rom.bin` is permanently present at the card root. This is likely the DEFENDER speed camera and red light camera database, or the radar firmware blob. Unlike the firmware update files on other cameras (which are transient and auto-deleted after flashing), this file persists across normal use. It serves as a supporting detection signal.

---

## Video Specs

| Setting | Default | Options |
|---------|---------|---------|
| Codec | H.264 (assumed) | — |
| Resolution | 1920×1080 (assumed) | Unknown |
| Frame rate | 30 fps (assumed) | Unknown |
| Container | MOV | — |
| Clip length | 3 min (default) | 1, 3, 5 min |

> **Note:** Codec, resolution, and frame rate were not confirmed via ffprobe during the card scan. H.264 1080P 30fps is assumed based on the 2019 hardware era and the "HD" description in the manual.

---

## Channels

Single-channel front-facing only. No rear or interior camera. The `_VID` suffix in filenames has no channel meaning — it is just a fixed literal token.

---

## Locked Clips

The manual describes two locking mechanisms. Both leave clips in `DCIM/RoadScout/` — there is no separate locked folder.

**G-sensor**: Automatically locks the current clip when an impact is detected. Sensitivity is configurable from 1 (easiest) to 3 (hardest), default level 2.

**Emergency button (MARK hold)**: Manually triggers an emergency recording. The clip length follows the Loop Clip Time setting. Announced by voice: "Emergency Recording On."

---

## GPS

The device includes a GPS receiver (GPS satellite icon on the display). GPS data is embedded in the video file — the Cobra Drive HD app can display route overlays from recorded footage. The exact storage format (GPS track, metadata atom, etc.) was not confirmed from ffprobe.

---

## Parking Mode

Not supported. The Road Scout records only when powered through the SmartCord USB cable in the vehicle's 12V socket. No hardwire kit is documented.

---

## Radar Detector Integration

The Road Scout is a combined device. The radar detector component adds:
- X, K, Ka, and Laser band detection
- DEFENDER database (verified speed traps, red light cameras) — updated via Wi-Fi hotspot
- GPS filter for storing and suppressing fixed false-alert locations
- iRadar community alerts via Bluetooth + Wi-Fi

The `rom.bin` file on the card is likely the DEFENDER database.

---

## Detection Notes

The `DCIM/RoadScout/` path is specific and sufficient for high-confidence detection. The `_VID` filename suffix and persistent `rom.bin` at root are reliable supporting signals.

Volume label "NO NAME" should not be used for detection — it is the generic macOS/Windows default for unbranded formatted media.

---

## Hardware

- **Manufacturer**: Cobra Electronics Corp., Chicago, IL
- **FCC ID**: BBORDCAM
- **Year**: © 2019
- **Made in**: Philippines
- **Companion apps**: Cobra iRadar (radar/alerts), Cobra Drive HD (footage)
- **Connectivity**: Bluetooth + Wi-Fi (2.4GHz 802.11 b/g/n only)

---

## Validation Status

| Item | Status |
|------|--------|
| Card structure | ✅ Real card sampled |
| Filename pattern | ✅ Real card sampled |
| Sequence resets per date | ✅ Confirmed from card |
| Locked clips in same folder | ✅ No separate folder observed |
| Codec / resolution / fps | ⚠️ Not confirmed (H.264 1080P assumed) |
| GPS data format in video | ❓ Not confirmed |
