# Sony A7 III (ILCE-7M3) — Card Profile

**Type:** Mirrorless camera (1CH)  
**Manufacturer:** Sony Corporation  
**Model code:** ILCE-7M3  
**Source:** Two real cards sampled (video+photo card; video-only card)

---

## Card Structure

```
[root]  (volume label: "Untitled" by default — not a detection signal)
├── PRIVATE/
│   ├── SONY/
│   │   └── SONYCARD.IND          ← Sony card indicator
│   ├── AVCHD/
│   │   └── BDMV/                 ← AVCHD legacy skeleton (present even if unused)
│   └── M4ROOT/
│       ├── MEDIAPRO.XML          ← media manifest with systemKind="ILCE-7M3"
│       ├── STATUS.BIN
│       ├── CLIP/
│       │   ├── C0001.MP4             ← XAVC S video clip
│       │   └── C0001M01.XML          ← clip metadata sidecar
│       └── THMBNL/
│           └── C0001T01.JPG          ← clip thumbnail
├── DCIM/                              (absent on video-only cards)
│   └── 100MSDCF/
│       ├── A7307789.ARW           ← Sony ARW raw photo
│       └── A7307789.JPG           ← JPEG photo (if RAW+JPEG mode)
└── AVF_INFO/                          ← AVF metadata files
```

**DCIM/ is absent on video-only cards.**

---

## Detection — Model Identification

**Do not use volume label.** Default is `Untitled` — too generic.

Use `PRIVATE/M4ROOT/MEDIAPRO.XML`:

```xml
<System systemKind="ILCE-7M3" masterVersion="XAVC-M4@1.10.00"/>
```

`systemKind="ILCE-7M3"` is the definitive A7 III fingerprint. Present immediately after the first recording on any freshly formatted card.

Alternatively, any `PRIVATE/M4ROOT/CLIP/C####M01.XML`:

```xml
<Device manufacturer="Sony" modelName="ILCE-7M3" serialNo="4294967295"/>
```

Both confirmed on real cards, including a video-only card.

---

## Filename Patterns

| Type | Pattern | Example |
|------|---------|--------|
| Video | `C####.MP4` | `C0001.MP4` |
| Video sidecar | `C####M01.XML` | `C0001M01.XML` |
| Thumbnail | `C####T01.JPG` | `C0001T01.JPG` |
| Photo (ARW) | `A73#####.ARW` | `A7307789.ARW` |
| Photo (JPEG) | `A73#####.JPG` | `A7307789.JPG` |

- `C####` — 4-digit sequential clip number (global)
- `A73` — A7 III model-specific prefix
- `#####` — 5-digit photo sequence (independent from clips)
- No date/time in filenames — use `CreationDate` in XML sidecar

---

## XML Sidecar (C####M01.XML)

Present for every clip. Contains:
- `CreationDate` — ISO 8601 with timezone
- `videoCodec` — e.g., `AVC_3840_2160_HP@L51`
- `captureFps` / `formatFps` — e.g., `29.97p`
- `VideoLayout` — pixel width, line count, aspect ratio
- `audioCodec` — `LPCM16`
- `Device/@modelName` — `ILCE-7M3`
- `CaptureGammaEquation` — color profile (e.g., `rec709`, `rec709-xvycc`)

---

## Video Specifications

| Mode | Codec | Resolution | FPS | Container |
|------|-------|------------|-----|-----------|
| 4K | H.264 | 3840×2160 | 23.98 / 25 / 29.97 | XAVC S (MP4) |
| 1080P | H.264 | 1920×1080 | 23.98 / 25 / 29.97 / 50 / 59.94 | XAVC S (MP4) |
| 1080P slow-mo | H.264 | 1920×1080 | 119.88 | XAVC S (MP4) |

Codec confirmed from XML sidecar (`AVC_3840_2160_HP@L51`). Audio: LPCM16 stereo. Max bitrate: 100 Mbps (Sony spec).

---

## Photo Specifications

- 24.2 MP full-frame sensor, 6000×4000
- `A73` prefix = A7 III model code
- Formats: ARW (Sony RAW), JPEG
- Camera can shoot RAW-only, JPEG-only, or RAW+JPEG
- Sampled card: ARW only
- DCIM/ absent when no photos taken
