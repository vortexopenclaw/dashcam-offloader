# Escort M1 — Card Profile

## Overview

The Escort M1 is a single-channel front-facing dashcam from ESCORT Inc. (Ohio). It uses a clean, predictable card layout — all footage lives inside an `Escort_M1/` subfolder, split between normal loop recordings and locked clips. The subfolder name is distinctive enough to serve as a high-confidence detection signal on its own.

---

## Card Structure

```
<card root>/
└── Escort_M1/
    ├── MOVIE/            # Normal loop-recorded driving clips
    └── LockedVideo/      # G-sensor and manually locked clips
```

No files are written to the card root during normal operation. A firmware update file (`FW96658A.bin`) appears at the card root only during a firmware update, and is deleted automatically afterward.

---

## Filename Pattern

```
YYYY_MMDD_HHMMSS_SEQ.MOV
```

| Component | Format | Example |
|-----------|--------|---------|
| Year | 4 digits | `2020` |
| Month + Day | 4 digits | `0611` |
| Time | 6 digits (HHMMSS) | `155517` |
| Sequence | Zero-padded, ≥3 digits | `007` |
| Extension | Uppercase `.MOV` | |

Example filename: `2020_0611_155517_007.MOV`

Both `MOVIE/` and `LockedVideo/` use the same filename pattern. The folder alone determines whether a clip is normal or locked.

---

## Folders

### `Escort_M1/MOVIE/`
Normal loop-recorded clips from continuous driving sessions. Old clips are overwritten when the card fills up (oldest first).

### `Escort_M1/LockedVideo/`
Protected clips that are not overwritten by loop recording. Clips land here via:
- **G-sensor (impact detection)**: triggered automatically by a hard impact or sudden stop
- **Emergency button**: manual lock via the dedicated button on the camera

If an impact occurs within 30 seconds of a file boundary, the adjacent clip is also locked.

---

## Sequence Number

The sequence counter is **global and monotonic** — it increments continuously across both `MOVIE/` and `LockedVideo/` folders. A clip with a higher sequence number was always recorded later, regardless of which folder it's in.

Sequence numbers are zero-padded to at least 3 digits. At very high values the field may grow beyond 3 digits.

---

## Video Specs

| Setting | Default | Options |
|---------|---------|---------|
| Resolution | 1920×1080 (1080P) | 1080P, 720P 60fps, 720P 30fps |
| Frame rate | 30 fps | 30 fps (1080P), 60 fps (720P) |
| Codec | H.264 | — |
| Container | MOV | — |
| Clip length | Configurable | 1, 3, or 5 minutes |

---

## Channels

Single-channel (front only). No rear or interior camera support. No channel suffix in filenames.

---

## Parking Mode

Not supported. The M1 records only when powered through the vehicle's ignition. There is no hardwire kit or parking mode available for this model.

---

## On-Screen Display (OSD)

The camera supports a **Video Stamp** overlay (date/time burned into the frame), enabled by default. Three date format options: `YYYY/MM/DD`, `MM/DD/YYYY`, or `DD/MM/YYYY`. Whether the model name is also burned in is not confirmed.

---

## Detection Notes

The `Escort_M1/` subfolder name is highly specific and sufficient for high-confidence detection. No other profiled camera uses this structure.

The `.MOV` extension (uppercase) and absence of a channel letter in the filename cleanly distinguish the M1 from all VIOFO profiles, which use `.MP4` and a channel suffix (`_F`, `_R`, etc.).

---

## Hardware

- **Manufacturer**: ESCORT Inc., Beavercreek, Ohio, USA
- **SoC**: Novatek NT96658
- **Lens**: 160° FOV
- **Companion app**: Escort M1 App (iOS / Android)
- **Wi-Fi**: Yes (for live view and configuration)

---

## Validation Status

| Item | Status |
|------|--------|
| Card structure | ✅ Real card sampled |
| Filename pattern | ✅ Real card sampled |
| Sequence behavior | ✅ Confirmed global monotonic |
| Codec / resolution | ⚠️ Not confirmed from ffprobe (H.264 assumed) |
| OSD model name burn-in | ❓ Not confirmed |
