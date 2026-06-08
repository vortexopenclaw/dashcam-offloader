# Video Metadata Reference

Running log of codec, resolution, frame rate, and bitrate data across all profiled cameras. Useful for estimating storage requirements, planning transcoding pipelines, and reasoning about file size expectations.

## Source Key

| Source | Meaning |
|--------|---------|
| `ffprobe` | Measured directly from real footage |
| `file_size_est` | Estimated from observed file sizes (±20%) |
| `mfr_spec` | From manufacturer product page or manual |
| `sidecar_xml` | Parsed from a per-clip or per-card XML sidecar file |
| `assumed` | Inferred from hardware platform or era; not verified |

Bitrates vary with scene complexity, firmware version, HDR mode, and camera settings. Values here are baselines for default settings unless noted.

---

## VIOFO A229 Pro

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | H.265 | 2592×1944 | 30 | — | MP4 | `mfr_spec` |
| R (rear) | driving | H.265 | 2560×1440 | 30 | — | MP4 | `mfr_spec` |
| I (interior) | driving | H.265 | 1920×1080 | 30 | — | MP4 | `mfr_spec` |
| PF/PR/PI | parking | H.265 | varies | — | — | MP4 | `assumed` |

**Notes:** Resolutions from VIOFO product page. Bitrates not measured. HDR mode available on front channel — bitrate likely higher when enabled. Parking mode clips have three sub-modes (event detection, time-lapse, low bitrate) with different bitrate profiles; none measured.

---

## VIOFO A229 Plus

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | H.265 | 2560×1440 | 30 | — | MP4 | `mfr_spec` |
| R (rear) | driving | H.265 | 2560×1440 | 30 | — | MP4 | `mfr_spec` |
| I (interior) | driving | H.265 | 1920×1080 | 30 | — | MP4 | `mfr_spec` |

**Notes:** Bitrates not measured. Card was freshly formatted — no long-session data available for size estimation.

---

## VIOFO A229 Ultra

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | H.265 | 3840×2160 | 30 | — | MP4 | `ffprobe` (footage) |
| R (rear) | driving | H.265 | 3840×2160 | 30 | — | MP4 | `ffprobe` (footage) |
| I (interior) | driving | H.265 | 1920×1080 | 30 | — | MP4 | `ffprobe` (footage) |

**Notes:** Resolutions confirmed from private archive sample (ffprobe). Bitrates not logged. Front and rear are both 4K UHD — distinguishing feature from A229 Pro (4K front, 2K rear).

---

## VIOFO A329S

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | H.265 | 2592×1944 | 30 | — | MP4 | `mfr_spec` |
| R (rear) | driving | H.265 | 2560×1440 | 30 | — | MP4 | `mfr_spec` |
| I (interior) | driving | H.265 | 1920×1080 | 30 | — | MP4 | `mfr_spec` |

**Notes:** Same platform as A229 Pro. Codec/resolution assumed to match; not independently confirmed from ffprobe.

---

## VIOFO A229 Pro / A329S Parking Mode Sub-types

Parking clips for the A229/A329 family go to `DCIM/Movie/Parking/` and share the same filename pattern as driving clips (`PF`/`PR`/`PI` channel codes). Three sub-modes exist but are not distinguishable by folder or filename alone:

| Mode | Description | Expected Bitrate Relative to Driving |
|------|-------------|---------------------------------------|
| Event detection | Full-quality clip triggered by motion | ~same as driving |
| Time-lapse | Reduced-fps timelapse | much lower |
| Low bitrate | Continuous but reduced quality | lower |

None of these sub-mode bitrates have been measured. Differentiation may require probing fps or video stream bitrate.

---

## VIOFO A139 Pro

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | H.265 | — | — | — | MP4 | `assumed` |
| R (rear) | driving | H.265 | — | — | — | MP4 | `assumed` |
| I (interior) | driving | **H.265** | 1920×1080 | — | — | MP4 | `ffprobe` (footage) |

**Notes:** Mixed codec confirmed — interior channel uses HEVC. Front and rear codec/resolution not individually confirmed from ffprobe; H.265 assumed. This camera has the unusual property of using a different codec for the interior vs. other channels, which is worth checking when building transcoding pipelines.

---

## VIOFO A119M Pro

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | H.264 | 1920×1080 | 30 | — | MP4 | `assumed` |

**Notes:** Single-channel 1080P. Codec assumed H.264 (older hardware, pre-H.265 mainstream). Not confirmed from ffprobe.

---

## VIOFO A119 Mini 2

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | H.265 | 2560×1440 | 30 | — | MP4 | `mfr_spec` |

**Notes:** Single-channel 2K. Resolution from VIOFO product page. Bitrate not measured.

---

## 70mai M310

| Channel | Mode | Codec | Resolution | FPS | Duration | Container | Source |
|---------|------|-------|------------|-----|----------|-----------|--------|
| F (front) | driving | H.265 | 2304×1296 | 30 | 60s | mp4 | `ffprobe` |
| F (front) | parking | H.265 | — | — | — | mp4 | `assumed` |

**Notes:** Codec, resolution, and fps confirmed from ffprobe (private archive sample + card scan). Segment duration is 60 seconds (not 1/3/5 min like most cameras). Bitrate not logged. Parking mode sub-types (motion detection in `Parking/`, time-lapse in `Lapse/`) likely have different bitrates — not measured. Extension is lowercase `.mp4`.

---

## Cansonic UltraDash Z3+ Standard Edition

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| L (wide front) | driving | — | 2560×1440 | 30 | — | MP4 | `mfr_spec` |
| R (telephoto front) | driving | — | 2560×1440 | 30 | — | MP4 | `mfr_spec` |
| B (rear, optional) | driving | — | 2560×1440 | 30 | — | MP4 | `mfr_spec` |

**Notes:** All channels listed as 2K QHD on product page. Codec not confirmed. Bitrates not measured.

---

## Vantrue N4 Pro S

| Channel | Mode | Codec | Resolution | FPS | Approx File Size | Container | Source |
|---------|------|-------|------------|-----|-----------------|-----------|--------|
| A (front) | driving | — | 3840×2160 | 30 | — | MP4 | `mfr_spec` |
| B (interior) | driving | — | 1920×1080 | 30 | — | MP4 | `mfr_spec` |
| C (rear) | driving | — | 2560×1440 | — | — | MP4 | `mfr_spec` |

**Notes:** Profile confirms A has the highest bitrate, B and C are medium. Resolutions from Vantrue product page. Codec not confirmed from ffprobe. Actual bitrates not measured.

---

## Vantrue N4 S

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| A (front) | driving | — | 2560×1440 | — | — | MP4 | `mfr_spec` |
| B (interior) | driving | — | 2560×1440 | — | — | MP4 | `mfr_spec` |
| C (rear) | driving | — | 2560×1440 | — | — | MP4 | `mfr_spec` |

**Notes:** Uniform 2.5K across all three channels is the distinguishing spec vs. N4 Pro S. Codec not confirmed. Bitrates not measured.

---

## Vantrue E1 Pro

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | — | 1920×1080 | 30 | — | MP4 | `mfr_spec` |
| F (front) | parking (motion) | — | — | — | — | MP4 | `assumed` |

**Notes:** Single-channel. Codec and bitrate not confirmed. Parking mode confirmed present from card scan (separate folders for motion-detection and event clips).

---

## BlackVue DR970X Plus

| Channel | Mode | Codec | Resolution | FPS | Bitrate (est) | Obs. File Size | Clip Duration | Container | Source |
|---------|------|-------|------------|-----|---------------|----------------|---------------|-----------|--------|
| F (front) | driving | — | 3840×2160 | — | ~20–21 Mbps | ~464 MB | — | mp4 | `file_size_est` |
| R (rear) | driving | — | 1920×1080 | — | ~3–4 Mbps | ~83 MB | — | mp4 | `file_size_est` |

**Notes:** File sizes observed directly from real card (profile YAML). Clip duration not confirmed; estimates assume ~3 min clips (180s). Bitrate estimates: F ≈ 464MB × 8 / 180s ≈ 20.6 Mbps; R ≈ 83MB × 8 / 180s ≈ 3.7 Mbps. Front:rear size ratio is ~5.6×. Codec not confirmed (H.264 or H.265 unknown). Resolution from product page — not ffprobe confirmed.

---

## BlackVue Elite 9

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | — | — | — | — | mp4 | `assumed` |
| R (rear) | driving | — | — | — | — | mp4 | `assumed` |

**Notes:** Real card sampled but no video metadata logged. All values need ffprobe measurement.

---

## BlackVue Elite 8

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | H.264 (AVC) | 2560×1440 | 30 | — | mp4 | `mfr_spec` |
| R (rear) | driving | H.264 (AVC) | 2560×1440 | 30 | — | mp4 | `mfr_spec` |

**Notes:** Codec H.264 (AVC) and resolution 2K QHD (2560×1440) @ 30fps confirmed from official BlackVue Elite 8 product specifications page. Both channels record at the same resolution with Dual HDR — distinguishing feature from Elite 9 (4K front + 2K rear). Bitrate not measured; needs ffprobe confirmation.

---

## Thinkware U3000 Pro

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | — | — | — | — | — | `assumed` |

**Notes:** Real card sampled but no video metadata logged. High-end model — likely 4K front. All values need ffprobe measurement.

---

## Thinkware U3000

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | — | — | — | — | — | `assumed` |
| R (rear) | driving | — | — | — | — | — | `assumed` |

**Notes:** 2CH real card sampled. No video metadata logged. All values need ffprobe measurement.

---

## Vueroid S1 4K Infinite

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | H.265 | 3840×2160 | 30 | — | MP4 | `mfr_spec` |
| R (rear) | driving | H.265 | 1920×1080 | 30 | — | MP4 | `mfr_spec` |
| B (rear 2) | driving | H.265 | — | — | — | MP4 | `assumed` |
| PF | parking (motion) | H.265 | — | 30 | — | MP4 | `ffprobe` (inferred from fps probe) |
| PF | parking (timelapse) | H.265 | — | 5 | — | MP4 | `ffprobe` (inferred from fps probe) |

**Notes:** Parking mode detection confirmed via frame rate probe: 30fps = motion detection, 5fps = timelapse. Both modes use same folder and filename prefix. 4K front spec from product page. Actual bitrates not measured.

---

## Escort M1

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | H.264 | 1920×1080 | 30 | — | MOV | `assumed` |

**Notes:** Codec, resolution, and fps not confirmed — ffprobe unavailable during card scan. H.264 1080P 30fps assumed from Novatek NT96658 platform and 2020 era. Manual lists 720P 60fps and 720P 30fps as alternatives.

---

## Escort M2

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | H.264 | 1920×1080 | 30 | — | MP4 | `assumed` |
| F (front) | photo | — | — | — | — | JPG | — |

**Notes:** Codec and resolution not confirmed from ffprobe. H.264 1080P 30fps assumed from platform era and manual description. Video container is `.MP4`. GPS sidecar (`.map`) paired with every clip. Photos stored as JPG in `Photo/`.

---

## Escort MAXcam 360c

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | — | — | — | — | MOV | `assumed` |

**Notes:** Codec and resolution not confirmed. Card sampled but no video metadata logged. Files use `.MOV` container in `Normal/MAXcam360c/`. GPS sidecar (`_gps.bin`) and g-sensor sidecar (`_gsensor.bin`) present after GPS lock. All values need ffprobe measurement.

---

## DJI Mini 3 Pro

| Channel | Mode | Codec | Resolution | FPS | Max Bitrate | Container | Source |
|---------|------|-------|------------|-----|-------------|-----------|--------|
| F | video (4K ≤30fps) | H.264 or H.265 | 3840×2160 | up to 30 | 150 Mbps | MP4 | `mfr_spec` |
| F | video (4K ≥48fps) | H.265 required | 3840×2160 | 48 or 60 | 150 Mbps | MP4 | `mfr_spec` |
| F | video (2.7K) | H.264 or H.265 | 2720×1530 | up to 60 | — | MP4 | `mfr_spec` |
| F | video (1080P) | H.264 or H.265 | 1920×1080 | up to 60 | — | MP4 | `mfr_spec` |
| F | photo | — | 48 MP | — | — | JPG / DNG | `mfr_spec` |

**Notes:** H.265 is required at 4K 48fps and 60fps; codec is user-selectable at lower frame rates. Max bitrate 150 Mbps applies to 4K modes. SRT telemetry sidecar (GPS, altitude, ISO, shutter, aperture, focal length, digital zoom) paired with every video clip. Photos are 48 MP JPG; DNG raw also supported per manual but not observed on the sampled card.

---

## Sony Alpha A7 III (ILCE-7M3)

| Channel | Mode | Codec | Resolution | FPS | Audio | Container | Source |
|---------|------|-------|------------|-----|-------|-----------|--------|
| F (video) | video | H.264 (AVC High@L5.1) | 3840×2160 | 29.97 | LPCM16, 2ch | MP4 (M4ROOT) | `sidecar_xml` |
| — | photo | — | 24.2 MP | — | — | ARW | `mfr_spec` |

**Notes:** Video codec, resolution, fps, and audio confirmed from `PRIVATE/M4ROOT/MEDIAPRO.XML` (`videoType="AVC_3840_2160_HP@L51"`, `fps="29.97p"`) and per-clip `C####M01.XML` sidecar (`videoCodec="AVC_3840_2160_HP@L51"`, `captureFps="29.97p"`). This is the first camera in the database where codec and resolution are confirmed from a metadata sidecar rather than ffprobe. AVC_3840_2160_HP@L51 = H.264 High Profile Level 5.1. Audio is dual-channel LPCM16 (linear PCM). Container is Sony XAVC S / M4ROOT MP4 format. Photos are RAW (.ARW) at 24.2 MP. DCIM/ is absent on video-only cards.

---

## Cobra Road Scout

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---------|------|-------|------------|-----|---------|-----------|--------|
| F (front) | driving | H.264 | 1920×1080 | 30 | — | MOV | `assumed` |

**Notes:** Codec, resolution, and fps not confirmed — ffprobe unavailable during card scan. H.264 1080P 30fps assumed from 2019 hardware era and "HD" manual description. GPS data embedded in video file but format not confirmed.

---

## Gaps Summary

Cameras that have real card or footage samples but **no ffprobe-confirmed video metadata at all**:

| Camera | Needs |
|--------|-------|
| BlackVue Elite 9 | codec, resolution, fps, bitrate |
| BlackVue Elite 8 | bitrate |
| Thinkware U3000 | codec, resolution, fps, bitrate |
| Thinkware U3000 Pro | codec, resolution, fps, bitrate |
| Escort M1 | codec, resolution, fps, bitrate |
| Escort M2 | codec, resolution, fps, bitrate |
| Escort MAXcam 360c | codec, resolution, fps, bitrate |
| Cobra Road Scout | codec, resolution, fps, bitrate |
| Vantrue N4 Pro S | codec, bitrate |
| Vantrue N4 S | codec, resolution, fps, bitrate |
| Vantrue E1 Pro | codec, resolution, fps, bitrate |
| BlackVue DR970X Plus | codec, resolution (front), fps |
| Vueroid S1 4K Infinite | bitrate (all modes), rear resolution |
| DJI Mini 3 Pro | bitrate (all modes) |
| Sony Alpha A7 III | bitrate |

Cameras where bitrate is logged nowhere:
- Every camera in this list — bitrate measurements are the largest universal gap.

To fill these gaps: mount the camera card, run ffprobe on at least one clip per mode per channel, and record `codec_name`, `width`, `height`, `r_frame_rate`, `bit_rate`, and `size` from the video stream. HDR clips should be measured separately.

```bash
ffprobe -v quiet -print_format json -show_streams -show_format <clip.mp4>
```
