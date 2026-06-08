# DJI Mini 3 Pro — Research Notes

## Sources

- Real card scan (volume label: DJI Mini 3)
- Official DJI Mini 3 Pro User Manual v1.6 (DJI, 2024): https://dl.djicdn.com/downloads/DJI_Mini_3_Pro/UM/20240105/2/DJI_Mini_3_Pro_User_Manual_v1.6_EN.pdf
- Web research: file structure, SRT telemetry format, video specs

## Card Scan Findings

### Confirmed from real card

- Volume label: `DJI Mini 3` (may vary; not a reliable detection signal)
- Folders: `DCIM/100MEDIA/`, `MISC/THM/100/`
- Video pattern: `DJI_NNNN.MP4` (4-digit global sequence, no date component)
- SRT sidecar: `DJI_NNNN.SRT` paired with every video clip
- Photo: `DJI_NNNN.JPG` (shares sequence with video)
- Thumbnails: `MISC/THM/100/DJI_NNNN.THM` and `.SCR`
- SRT content confirmed: GPS lat/lon, relative/absolute altitude, ISO, shutter, aperture, EV, color temp, focal length, digital zoom (per-frame, ~33ms intervals)

### Not confirmed from card

- Codec (H.264 vs H.265 depends on selected recording mode; not ffprobe confirmed)
- DNG photo format (supported per manual; not observed on sampled card)

## SRT Format Sample

Each SRT entry contains:
```
SrtCnt : N, DiffTime : 33ms
[datetime]
[iso : 190] [shutter : 1/120.0] [fnum : 170] [ev : 0] [ct : 5589]
[color_md : default] [focal_len : 240] [dzoom_ratio: 10000, delta:0]
[latitude: XX.XXXXXX] [longitude: -XXX.XXXXXX]
[rel_alt: 0.000 abs_alt: 161.236]
```

Notes: `fnum` = aperture × 100 (170 = f/1.7). `focal_len` = mm × 10 (240 = 24mm). `dzoom_ratio` = zoom × 10000 (10000 = 1.0×).

## Manual Specs (v1.6)

- Video: H.264/H.265, 4Kd60fps max, 150 Mbps max bitrate
- 4K≤30fps: H.264 or H.265; 4K≥48fps: H.265 only
- Slow motion: 1080P 120fps
- HDR: 4K 30fps (H.265)
- Photos: 48MP, JPEG and DNG
- Color profiles: Normal, D-Cinelike
- microSD: up to 2 TB (exFAT); also 2 GB internal storage in some configs
- Weight: 249g (sub-250g class)

## Open Questions

1. Codec per clip confirmation (H.264 vs H.265) requires ffprobe or in-clip metadata
2. Volume label when formatted in-drone vs. on computer — "DJI Mini 3" observed; may differ
3. DNG photo format not seen on sampled card — card was set to JPEG
4. Does DJI embed any model identifier in the MP4 metadata? (Would allow model confirmation without just folder structure)
