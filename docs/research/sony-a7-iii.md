# Sony Alpha A7 III (ILCE-7M3) — Research Notes

## Sources

- Two real card scans:
  - Card 1: user-named volume, video clips + ARW photos
  - Card 2: freshly formatted, volume "Untitled", one video clip, no photos
- Sony A7 III User Manual: https://www.sony.com/electronics/support/res/manuals/5074/9c2e7c425d271c4406096edb2267b53a/50740222M.pdf
- MEDIAPRO.XML and C####M01.XML data confirmed from both real cards

## Card Scan Findings

### Confirmed from real cards

- Default volume label: `Untitled` — do NOT use for detection (generic, user-renames)
- Folder structure: `PRIVATE/M4ROOT/CLIP/`, `PRIVATE/M4ROOT/THMBNL/`, `PRIVATE/SONY/SONYCARD.IND`
- Video clips: `C####.MP4` (4-digit sequential, global)
- Video XML sidecar: `C####M01.XML` (NonRealTimeMeta) — present for every clip
- Clip thumbnail: `C####T01.JPG` in THMBNL/
- Media manifest: `PRIVATE/M4ROOT/MEDIAPRO.XML` — contains `systemKind="ILCE-7M3"` and per-clip codec/fps/resolution
- AVCHD skeleton: `PRIVATE/AVCHD/BDMV/` present even when AVCHD unused
- Additional files on fresh card: `PRIVATE/M4ROOT/STATUS.BIN`, `AVF_INFO/AVIN0001.BNP`, `AVF_INFO/AVIN0001.INP`, `AVF_INFO/PRV00001.BIN`
- Photo naming: `A73#####.ARW` ("A73" = A7 III model prefix; 5-digit independent sequence)
- DCIM/100MSDCF/ absent on video-only card — only created after photos are taken
- Codec confirmed from XML: `AVC_3840_2160_HP@L51` (H.264 High Profile Level 5.1)
- Resolution confirmed: 3840×2160
- FPS confirmed: 29.97p
- Audio confirmed: LPCM16 stereo
- Model confirmed: `ILCE-7M3` in both `MEDIAPRO.XML systemKind` and `C####M01.XML Device/@modelName`

### Not confirmed from card

- Bitrate (100 Mbps from Sony spec; not measured)
- 1080P mode clip appearance (only 4K clips observed)
- S-Log2/S-Log3 footage (not observed; would show in CaptureGammaEquation)
- JPEG photos (only ARW observed; user shooting RAW-only)

## Key Detection Path

`PRIVATE/M4ROOT/MEDIAPRO.XML` is the recommended detection entry point:
- Always created after first recording on any card (confirmed on freshly formatted card)
- Contains `systemKind="ILCE-7M3"` at a fixed XPath
- Also lists each clip with videoType, fps, duration — useful for pre-scan metadata without opening individual XMLs

Fallback: any `PRIVATE/M4ROOT/CLIP/C####M01.XML`:
- Contains `<Device modelName="ILCE-7M3"/>` in every sidecar

## MEDIAPRO.XML Structure

```xml
<MediaProfile xmlns="http://xmlns.sony.net/pro/metadata/mediaprofile">
  <Properties>
    <System systemKind="ILCE-7M3" masterVersion="XAVC-M4@1.10.00"/>
    <Attached mediaKind="AffordableMemoryCard" mediaName=""/>
  </Properties>
  <Contents>
    <Material uri="./CLIP/C0001.MP4" type="MP4"
      videoType="AVC_3840_2160_HP@L51" audioType="LPCM16"
      fps="29.97p" dur="180" ch="2" aspectRatio="16:9">
      <RelevantInfo uri="./CLIP/C0001M01.XML" type="XML"/>
      <RelevantInfo uri="./THMBNL/C0001T01.JPG" type="JPG"/>
    </Material>
  </Contents>
</MediaProfile>
```

## Open Questions

1. Bitrate not measurable from XML — requires ffprobe
2. Does S-Log2/S-Log3 show `CaptureGammaEquation` value different from `rec709`?
3. What does 1080P slow-motion (119.88fps) look like in MEDIAPRO.XML — same videoType prefix?
4. Does AVCHD-mode recording write to `PRIVATE/AVCHD/` instead of M4ROOT/?
5. JPEG photo naming — always `A73#####` or could it vary (e.g., if custom filename prefix is set)?
