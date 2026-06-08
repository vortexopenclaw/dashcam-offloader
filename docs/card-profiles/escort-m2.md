# Escort M2 — Card Profile

**Type:** Dashcam (1CH)  
**Manufacturer:** ESCORT INC. (©2025)  
**App:** Drive Smarter  
**GPS:** Yes (proprietary .map sidecar)  
**Source:** Real card sampled

---

## Card Structure

```
[root]  (volume label: M2)
├── Normal/
│   ├── YYYYMMDD_NNNN_CAM.MP4     ← loop-recorded driving clips
│   └── YYYYMMDD_NNNN_CAM.map     ← paired GPS sidecar
├── Photo/
│   └── YYYYMMDD_NNNN_CAM_IMG.JPG ← still photos
└── Event/                         (optional — absent if no events)
    └── YYYYMMDD_NNNN_CAM.MP4
```

---

## Filename Patterns

| Type | Pattern | Example |
|------|---------|--------|
| Video | `YYYYMMDD_NNNN_CAM.MP4` | `20240328_0004_CAM.MP4` |
| GPS sidecar | `YYYYMMDD_NNNN_CAM.map` | `20240328_0004_CAM.map` |
| Photo | `YYYYMMDD_NNNN_CAM_IMG.JPG` | `20210807_0030_CAM_IMG.JPG` |

- `YYYYMMDD` — date only; no time component in filename
- `NNNN` — 4-digit per-day sequence, resets to 0001 each day
- `CAM` — channel token (always CAM; 1-channel device)

---

## Sequence Behavior

Per-date, shared across all folders. Normal/, Photo/, and Event/ clips from the same day increment the same counter.

---

## GPS Sidecar (.map)

Every video clip in Normal/ has a paired `.map` file with the same base name. ESCORT proprietary format. All clips on the sampled card had a paired .map file.

---

## Video Specifications

| Setting | Value | Confirmed |
|---------|-------|-----------|
| Codec | H.264 | assumed |
| Resolution | 1920×1080 | manual spec |
| Frame rate | 30 fps | assumed |
| Container | MP4 | confirmed |
| Clip duration | 1 / 2 / 3 min | manual spec |

1280×720 also available per manual settings.

---

## Features

- **Parking mode:** Yes — requires hardwire power kit
- **ADAS:** FCWS, LDWS
- **Speed alerts:** Via Drive Smarter app

---

## Detection Notes

Primary signals: volume label `M2` + `Normal/` at root with `.map` sidecars + `.MP4` extension. The `.MP4` extension distinguishes from Escort M1 (`.MOV`) and Cobra Road Scout (`.MOV`). `Normal/MAXcam360c/` subfolder absent — distinguishes from MAXcam 360c. DCIM/ absent — distinguishes from DJI and most other cameras.
