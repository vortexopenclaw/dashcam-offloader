# DJI Mini 3 Pro — Card Profile

**Type:** Drone (1CH)  
**Manufacturer:** DJI  
**GPS:** Yes (per-frame in SRT sidecar)  
**Source:** Real card sampled

---

## Card Structure

```
[root]  (volume label: "DJI Mini 3" — may vary; not reliable for detection)
├── DCIM/
│   └── 100MEDIA/                  ← all media (video + photos)
│       ├── DJI_NNNN.MP4             ← video clips
│       ├── DJI_NNNN.SRT             ← per-frame telemetry sidecar
│       ├── DJI_NNNN.JPG             ← JPEG photo
│       └── DJI_NNNN.DNG             ← RAW photo (if enabled)
└── MISC/
    └── THM/
        └── 100/
            ├── DJI_NNNN.THM           ← thumbnail
            └── DJI_NNNN.SCR           ← preview screenshot
```

When DCIM/100MEDIA fills (999 files), camera creates DCIM/101MEDIA and continues.

---

## Filename Patterns

| Type | Pattern | Example |
|------|---------|--------|
| Video | `DJI_NNNN.MP4` | `DJI_0001.MP4` |
| SRT sidecar | `DJI_NNNN.SRT` | `DJI_0001.SRT` |
| Photo (JPEG) | `DJI_NNNN.JPG` | `DJI_0009.JPG` |
| Photo (RAW) | `DJI_NNNN.DNG` | `DJI_0009.DNG` |
| Thumbnail | `DJI_NNNN.THM` | `DJI_0001.THM` |

No date or time in filename. Date/time comes from SRT sidecar and video metadata.

---

## Sequence Behavior

Global counter shared across all media types (video, JPEG, DNG). Increments monotonically regardless of power cycle. A photo occupies the next number after the preceding video clip.

---

## SRT Telemetry Sidecar

Every video clip has a paired `.SRT` file with per-frame telemetry at ~33ms intervals (30fps):

- **GPS:** latitude, longitude
- **Altitude:** relative (above takeoff) and absolute (above sea level)
- **Camera:** ISO, shutter speed, aperture (fnum ×100), EV, color temperature, focal length (mm ×10), digital zoom ratio
- **Timestamp:** per-frame UTC datetime

---

## Video Specifications

| Mode | Codec | Resolution | FPS | Max Bitrate |
|------|-------|------------|-----|-------------|
| 4K (≤30fps) | H.264 or H.265 | 3840×2160 | 24/25/30 | 150 Mbps |
| 4K (≥48fps) | H.265 only | 3840×2160 | 48/50/60 | 150 Mbps |
| 2.7K | H.264 or H.265 | 2720×1530 | 24–60 | — |
| 1080P | H.264 or H.265 | 1920×1080 | 24–60 | — |
| 1080P slow-mo | H.264 or H.265 | 1920×1080 | 120 | — |

Source: manufacturer spec. Codec not confirmed from ffprobe.

---

## Photo Specifications

- 48 MP sensor
- JPEG confirmed on sampled card
- DNG (Adobe RAW) supported per manual — not observed on sampled card

---

## Detection Notes

Primary signals: `DCIM/100MEDIA/` + `DJI_NNNN.SRT` sidecar files alongside MP4s. SRT presence is highly specific to DJI drone footage. Volume label is unreliable. No date in filenames. No Normal/ folder or Escort-style structure.
