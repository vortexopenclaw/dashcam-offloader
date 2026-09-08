# Video Metadata Reference

Running log of codec, resolution, frame rate, and bitrate data across the profiled cameras we have actual sample footage for. Measurements below come from `ffprobe` runs on mounted archive clips under `/Volumes/Dashcams/` unless noted otherwise.

Bitrates vary with scene complexity, firmware version, HDR mode, and camera settings. Values here are representative baselines from the sampled clips.

For cross-camera comparisons and parking-mode bitrate drops, see [Video Quality Master Chart](video-quality-master-chart.md).

Validation rule: use files copied straight from the dashcam whenever possible, such as `Driving Clips`, `Parking Clips`, `Sample clips`, or raw card folders. Exclude produced YouTube exports, review videos, b-roll of the camera, app screen recordings, IR camera clips, website screenshots, thumbnails, and phone/camera footage.

## Source Key

| Source | Meaning |
|---|---|
| `ffprobe` | Measured directly from real footage |
| `mfr_spec` | From manufacturer product page or manual |
| `assumed` | Inferred from hardware platform or era; not verified by sample footage |

---

## BlackVue Elite 9

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | HEVC | 3840x2160 | 30 | ~60.0 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | HEVC | 2560x1440 | 30 | ~25.0 Mbps | MP4 | `ffprobe` |
| PF / IF | parking | HEVC | 3840x2160 | 30 | ~56-60 Mbps | MP4 | `ffprobe` |
| PR | parking | HEVC | 2560x1440 | 30 | ~25.0 Mbps | MP4 | `ffprobe` |

**Notes:** Mounted sample set showed 61-second clips for the main driving and parking files. The front channel is 4K UHD and the rear is 1440p.

## BlackVue Elite 8

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| Sample clips | driving | H.264 | 3840x2160 | 30 | ~56 Mbps | MP4 | `ffprobe` |

**Notes:** The mounted archive exposed only a small `C####` sample set in this pass, so the clip mix is not yet a full channel map. Treat this as a measured sample baseline, not a complete profile validation.

## BlackVue DR770X Box

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving / parking / impact | H.264 | 1920x1080 | 60 / 59.94 | ~16.0 Mbps | MP4 | `ffprobe` |
| O (interior) | driving / parking / impact | H.264 | 1920x1080 | 30 / 29.97 | ~10.0 Mbps | MP4 | `ffprobe` |
| R (rear) | driving / parking / impact | H.264 | 1920x1080 | 30 / 29.97 | ~10.0 Mbps | MP4 | `ffprobe` |

**Notes:** The real app-submitted Learn Card package confirmed `BlackVue/Record`, `BlackVue/Config`, exact DR770X Box model metadata, and four `NF` clips with an unset-camera-clock style `19991231` date. The NAS archive at `/Volumes/Dashcams/BlackVue DR770X Box` adds 38 direct camera clips in `Driving Clips` and `Parking Clips` for media measurements and 3-channel examples. Observed mode letters are `M`, `N`, `P`, and `I`; observed channel letters are `F`, `O`, and `R`.

## BlackVue DR900S-2CH

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 1920x1080 | 30 | ~14.7 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 1920x1080 | 30 | ~10.5 Mbps | MP4 | `ffprobe` |
| F / R | parking | H.264 | 1920x1080 | 30 | ~10.5-12.6 Mbps | MP4 | `ffprobe` |

**Notes:** The archive contains a mix of driving, parking, and sample clips. Representative clips are 60 to 180 seconds long, with 1080p H.264 as the dominant format.

## BlackVue DR970X-2CH Plus

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| MF (main/front) | driving | HEVC | 3840x2160 | 30 | ~60.0 Mbps | MP4 | `ffprobe` |

**Notes:** The mounted archive includes real driving clips plus a lot of b-roll. Only the camera-looking `YYYYMMDD_HHMMSS_MODECHANNEL` files were used for this row.

## BlackVue DR750X-2CH Plus

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| NF / MF (front) | driving | H.264 | 1920x1080 | 30 / 60 | ~25.1 Mbps at 60 fps | MP4 | `ffprobe` |
| NR (rear) | driving | H.264 | 1920x1080 | 30 | ~10.4 Mbps | MP4 | `ffprobe` |

**Notes:** This archive has comparison clips mixed with DR750S/DR750 LTE footage, so model labels in file descriptions matter. The measured DR750X Plus front sample was 1080p60.

## BlackVue DR750S-2CH

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 1920x1080 | 30 | ~12.6 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 1920x1080 | 30 | ~10.5 Mbps | MP4 | `ffprobe` |
| F / R | parking | H.264 | 1920x1080 | 30 | ~10.5-12.6 Mbps | MP4 | `ffprobe` |

**Notes:** Main clip family uses `NF`/`NR` naming. Parking files also exist with `PF`/`PR`.

## BlackVue DR650S-2CH

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 1920x1080 | 30 | ~10.5 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 1280x720 | 30 | ~5.2 Mbps | MP4 | `ffprobe` |
| F / R | parking / event | H.264 | 1920x1080 / 1280x720 | 30 | ~5.2-10.5 Mbps | MP4 | `ffprobe` |

**Notes:** The rear stream is 720p in the sampled archive. Some comparison and screen-capture files also exist in the folder, but they are not dashcam footage.

## Thinkware U3000 Pro

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | HEVC | 3840x2160 | 30 | ~30.0 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | HEVC | 2560x1440 | 30 | ~10.0 Mbps | MP4 | `ffprobe` |
| F | parking (motion) | HEVC | 2560x1440 | 30 | ~5.0 Mbps | MP4 | `ffprobe` |
| R | parking (motion) | HEVC | 2560x1440 | 30 | ~5.0-6.4 Mbps | MP4 | `ffprobe` |
| F | parking (event) | HEVC | 3840x2160 | 30 | ~12.0 Mbps | MP4 | `ffprobe` |
| F | manual | HEVC | 3840x2160 | 30 | ~30.0 Mbps | MP4 | `ffprobe` |

**Notes:** The sampled card contains REC, MOT, MAN, and PAK clips. Parking event clips are short and keep 4K resolution.

## Thinkware U3000

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | HEVC | 3840x2160 | 30 | ~30.0 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | HEVC | 2560x1440 | 30 | ~10.0 Mbps | MP4 | `ffprobe` |
| F | parking (motion) | HEVC | 2560x1440 | 30 | ~12.0 Mbps | MP4 | `ffprobe` |
| R | parking (motion) | HEVC | 2560x1440 | 30 | ~5.0-6.4 Mbps | MP4 | `ffprobe` |
| F | parking (manual) | HEVC | 3840x2160 | 30 | ~30.0 Mbps | MP4 | `ffprobe` |

**Notes:** The mounted archive shows REC, MOT, MAN, and PAK clips. Front camera clips are 4K in the sampled set.

## Thinkware U1000 Plus

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving / manual | HEVC | 3840x2160 | 30 | ~24.0 Mbps | MP4 | `ffprobe` |
| R (rear) | driving / manual | HEVC | 1920x1080 | 30 | ~6.0 Mbps | MP4 | `ffprobe` |
| F (front) | parking motion / event | HEVC | 3840x2160 | 30 | ~10.0-12.1 Mbps | MP4 | `ffprobe` |
| R (rear) | parking motion | HEVC | 1920x1080 | 30 | ~3.0 Mbps | MP4 | `ffprobe` |

**Notes:** NAS sample patterns include `REC_YYYYMMDD_HHMMSS_F/R`, `MAN_YYYYMMDD_HHMMSS_F/R`, `MOT_YYYYMMDD_HHMMSS_F/R`, and `PAK_YYYYMMDD_HHMMSS_F`.

## Thinkware Q800 Pro

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 2560x1440 | 30 | ~15.9 Mbps | MP4 | `ffprobe` |

**Notes:** The sampled archive contains many produced review/b-roll files. This row uses a camera-looking `REC_YYYY_MM_DD_HH_MM_SS_F` driving clip.

## Thinkware F800 Pro

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving / manual | H.264 | 1920x1080 | 30 | ~10.0 Mbps | MP4 | `ffprobe` |
| F / R | parking event | H.264 | 1920x1080 | ~10.7 | ~3.5 Mbps | MP4 | `ffprobe` |

**Notes:** Sampled files use Thinkware-style `REC_`, `MAN_`, and `PAK_` prefixes.

## Thinkware FA200

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | parking timelapse | H.264 | 1920x1080 | ~10 | ~3.3 Mbps | MP4 | `ffprobe` |
| R (rear) | parking motion | H.264 | 1280x720 | ~15 | ~3.0 Mbps | MP4 | `ffprobe` |

**Notes:** The NAS sample shows `TIM_` and `MOT_` parking families, including front/rear pairs.

## VIOFO A229 Pro

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 3840x2160 | 30 | ~36.0 Mbps | MP4 | `ffprobe` |
| I (interior) | driving | H.264 | 1920x1080 | 30 | ~15.6 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 2560x1440 | 30 | ~24.0 Mbps | MP4 | `ffprobe` |
| PF | parking | H.264 | 3840x2160 | 30 | ~4.1 Mbps | MP4 | `ffprobe` |
| PI | parking | H.264 | 1920x1080 | 30 | ~3.9 Mbps | MP4 | `ffprobe` |
| PR | parking | H.264 | 2560x1440 | 30 | ~4.1 Mbps | MP4 | `ffprobe` |

**Notes:** The temporary 3CH card at `/Volumes/Untitled` confirmed 210 complete normal F/I/R triplets, 1866 complete parking PF/PI/PR triplets, 1 locked F/I/R triplet, and 1 photo F/I/R triplet. Treat the ~4 Mbps PF/PI/PR rows as low-bitrate parking-mode evidence, not normal driving bitrate.

## VIOFO A229 Plus

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 2560x1440 | 30 | ~28.7 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 2560x1440 | 30 | ~23.8 Mbps | MP4 | `ffprobe` |
| I (interior) | driving | H.264 | 1920x1080 | 30 | ~15.6 Mbps | MP4 | `ffprobe` |

**Notes:** Fresh-format sample set. No parking clips were included in this mounted pass.

## VIOFO A229 Ultra

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 3840x2160 | 30 | ~36.0 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 3840x2160 | 30 | ~34.4 Mbps | MP4 | `ffprobe` |
| I (interior) | driving | H.264 | 1920x1080 | 30 | ~15.6 Mbps | MP4 | `ffprobe` |
| PF | parking | H.264 | 2560x1440 | 30 | ~12.3 Mbps | MP4 | `ffprobe` |

**Notes:** Front and rear are both 4K in this sample set, which is the key distinction from A229 Pro.

## VIOFO A329S

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 3840x2160 | 30 | ~53-66 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 2560x1440 | 30 | ~23.8 Mbps | MP4 | `ffprobe` |
| I (interior) | driving | H.264 | 1920x1080 | 30 | ~15.6 Mbps | MP4 | `ffprobe` |
| PF | parking | H.264 | 3840x2160 | 30 | ~53.3 Mbps | MP4 | `ffprobe` |
| PI | parking | H.264 | 1920x1080 | 30 | ~8.2 Mbps | MP4 | `ffprobe` |
| PR | parking | H.264 | 2560x1440 | 30 | ~23.8 Mbps | MP4 | `ffprobe` |

**Notes:** The mounted archive shows both driving and parking clips with the expected front/rear/interior split. Parking clips can still preserve full 4K on the front channel.

## VIOFO A329T

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 3840x2160 | 30 | ~65.5 Mbps | MP4 | `ffprobe` |
| T (telephoto) | driving | H.264 | 2560x1440 | 30 | ~27.0 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 2560x1440 | 30 | ~27.0 Mbps | MP4 | `ffprobe` |
| PF | parking | H.264 | 3840x2160 | 30 | ~4.2 Mbps | MP4 | `ffprobe` |
| PT | parking | H.264 | 2560x1440 | 30 | ~4.1-4.2 Mbps | MP4 | `ffprobe` |
| PR | parking | H.264 | 2560x1440 | 30 | ~4.1 Mbps | MP4 | `ffprobe` |

**Notes:** The telephoto channel is explicitly visible in the sampled filenames. Parking clips stay at very low bitrates compared with driving footage.

## VIOFO A139 Pro

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | HEVC | 3840x2160 | 30 | ~53.3 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | HEVC | 1920x1080 | 30 | ~16.4 Mbps | MP4 | `ffprobe` |
| I (interior) | driving | HEVC | 1920x1080 | 30 | ~13.5-16.4 Mbps | MP4 | `ffprobe` |
| PF | parking | H.264 / HEVC | 2560x1440 | 30 | ~9.9-14.8 Mbps | MP4 | `ffprobe` |
| PR | parking | HEVC | 1920x1080 | 30 | ~6.6-8.2 Mbps | MP4 | `ffprobe` |
| PI | parking | H.264 / HEVC | 1920x1080 | 30 | ~6.6-8.2 Mbps | MP4 | `ffprobe` |

**Notes:** The mounted archive shows mixed codec behavior across parking clips, which is worth keeping in mind when building transcode rules.

## VIOFO A139

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 2560x1440 | 30 | ~27.0 Mbps | MP4 | `ffprobe` |
| I (interior) | driving | H.264 | 1920x1080 | 30 | ~16.4 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 1920x1080 | 30 | ~16.4 Mbps | MP4 | `ffprobe` |

**Notes:** Driving clips use the `YYYY_MMDD_HHMMSS_F/I/R` filename family.

## VIOFO T130

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 2560x1440 | 30 | ~27.7 Mbps | MP4 | `ffprobe` |
| I (interior) | driving | H.264 | 1920x1080 | 30 | ~9.0 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 1920x1080 | 30 | ~12.3-12.4 Mbps | MP4 | `ffprobe` |

**Notes:** NAS sample patterns use `YYYY_MMDD_HHMMSS_F/I/R`.

## VIOFO A129 Duo

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 1920x1080 | 30 | ~16.4 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 1920x1080 | 30 | ~16.4 Mbps | MP4 | `ffprobe` |

**Notes:** Sampled camera-looking files use `YYYY_MMDD_HHMMSS_SEQF/R`. The folder also contains unrelated b-roll clips.

## VIOFO A129 Plus Duo

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 2560x1440 | 30 | ~11.6-29.6 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 1920x1080 | 30 | ~18.4 Mbps | MP4 | `ffprobe` |
| PF | parking | H.264 / HEVC | 2560x1440 | 30 | ~8.4-9.8 Mbps | MP4 | `ffprobe` |

**Notes:** The NAS sample shows both compact `YYYYMMDDHHMMSS_SEQF/R/PF` and VIOFO-style `YYYY_MMDD_HHMMSS_PF` filename variants.

## VIOFO A129 Pro

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | HEVC | 3840x2160 | 30 | ~51.2 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | HEVC | 1920x1080 | 30 | ~13.9 Mbps | MP4 | `ffprobe` |
| PF | parking | H.264 / HEVC | 3840x2160 | 30 | ~8.4-26.6 Mbps | MP4 | `ffprobe` |

**Notes:** Sampled files include both no-sequence and sequence-bearing parking filename variants.

## VIOFO A119 v3

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 2560x1440 | 30 | ~25.8 Mbps | MP4 | `ffprobe` |
| F (front) | parking | H.264 | 2560x1440 | 30 | ~8.4 Mbps | MP4 | `ffprobe` |

**Notes:** Parking samples use the same timestamp/sequence family with a `P` suffix.

## VIOFO A119 Mini

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 2560x1440 | 60 | ~26.6 Mbps | MP4 | `ffprobe` |

**Notes:** The sampled A119 Mini driving clip is 1440p60, distinct from the A119 Mini 2 rows below.

## VIOFO A119 Mini 2

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 2560x1440 | 30 / 60 | ~26.6-28.8 Mbps | MP4 | `ffprobe` |
| F (front) | parking timelapse | H.264 | 2560x1440 | 30 | ~30.3 Mbps | MP4 | `ffprobe` |
| F (front) | parking motion | H.264 | 2560x1440 | 30 | ~3.8 Mbps | MP4 | `ffprobe` |

**Notes:** Direct clips from `Driving Footage` and `Parking Footage` confirm the camera stays at 1440p. Earlier 1080p/HEVC samples were excluded because they were not direct A119 Mini 2 dashcam recordings.

## VIOFO A119M Pro

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 3840x2160 | 30 | ~36.9 Mbps | MP4 | `ffprobe` |
| F (front) | parking | H.264 | 2560x1440 | 30 | ~3.8-8.4 Mbps | MP4 | `ffprobe` |

**Notes:** The sampled archive includes both 4K driving and 1440p parking clips.

## 70mai M310

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | HEVC | 2304x1296 | 30 | ~12.0 Mbps | mp4 | `ffprobe` |
| F (front) | parking / lapse | HEVC | 2304x1296 | 30 | ~12.0 Mbps | mp4 | `ffprobe` |

**Notes:** The mounted archive also contains unrelated 4K b-roll and screen captures, but the actual dashcam footage is 1296p.

## Vantrue N4 Pro S

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| A (front) | driving | HEVC | 3840x2160 | 30 | ~31.9 Mbps | MP4 | `ffprobe` |
| B (interior) | driving | HEVC | 1920x1080 | 30 | ~9.8 Mbps | MP4 | `ffprobe` |
| C (rear) | driving | HEVC | 2560x1440 | 30 | ~14.3 Mbps | MP4 | `ffprobe` |
| A | parking | HEVC | 3840x2160 | 30 | ~31.9 Mbps | MP4 | `ffprobe` |
| B | parking | HEVC | 1920x1080 | 30 | ~9.8 Mbps | MP4 | `ffprobe` |

**Notes:** The sample set clearly separates A/B/C channels and keeps the front channel at the highest bitrate.

## Vantrue N4 S

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| A (front) | driving | HEVC | 2560x1440 | 30 | ~14.3 Mbps | MP4 | `ffprobe` |
| B (interior) | driving | HEVC | 2560x1440 | 30 | ~14.3 Mbps | MP4 | `ffprobe` |
| C (rear) | driving | HEVC | 2560x1440 | 30 | ~14.3 Mbps | MP4 | `ffprobe` |

**Notes:** Uniform 2.5K across all channels is the defining difference from the N4 Pro S sample.

## Vantrue E1 Pro

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving / event | H.264 | 3840x2160 | 30 | ~31.9 Mbps | MP4 | `ffprobe` |
| F (front) | parking timelapse | H.264 | 3840x2160 | 30 | ~31.9 Mbps | MP4 | `ffprobe` |
| F (front) | parking motion | H.264 | 1920x1080 | 15 | ~4.9-5.0 Mbps | MP4 | `ffprobe` |

**Notes:** Direct camera clips from `Driving Clips` and `Parking Clips` confirm this is a 4K camera. `N` and `E` driving/event clips are 4K30; `T` parking timelapse clips are also 4K30; `P` motion-detection parking clips drop to 1080p15.

## Vantrue N4

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| A (front) | driving / event | HEVC | 2560x1440 | 30 | ~10.6-15.6 Mbps | MP4 | `ffprobe` |
| B (interior) | driving / event | HEVC | 1920x1080 | 30 | ~3.2-8.1 Mbps | MP4 | `ffprobe` |
| C (rear) | event | HEVC | 1920x1080 | 30 | ~3.7-11.7 Mbps | MP4 | `ffprobe` |
| A / B | parking | HEVC | 1280x720 | 30 | ~0.7-1.3 Mbps | MP4 | `ffprobe` |

**Notes:** Sampled filenames use `YYYY_MM_DD_HHMMSS_MODE_CHANNEL`, with observed `N`, `E`, and `P` mode tokens.

## Vantrue N5

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| A (front) | driving | HEVC | 2560x1440 | 30 | ~14.8199 Mbps | MP4 | `ffprobe` |
| B (interior_front) | driving | HEVC | 1920x1080 | 30 | ~10.3459 Mbps | MP4 | `ffprobe` |
| C (interior_rear) | driving | HEVC | 1920x1080 | 30 | ~10.3459 Mbps | MP4 | `ffprobe` |
| D (rear) | driving | HEVC | 1920x1080 | 30 | ~10.3459 Mbps | MP4 | `ffprobe` |

**Storage-rate verification (2026-09-08):** Complete original driving-channel set, using file size divided by duration including container overhead. Exact quality menu setting not saved.

## Vantrue E360

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| A (360/interior/front composite) | driving / event | H.264 | 5184x1944 | 30 | ~28.7 Mbps | MP4 | `ffprobe` |
| C | event | H.264 | 2560x1440 | 30 | ~14.4 Mbps | MP4 | `ffprobe` |

**Notes:** The sampled 360-channel file is an ultrawide 5184x1944 stream.

## 70mai 4K Omni X800

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | HEVC | 3840x2160 | 30 | ~56.4826 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | HEVC | 1920x1080 | 30 | ~10.9992 Mbps | MP4 | `ffprobe` |

**Storage-rate verification (2026-09-08):** Probed original driving files using complete file size divided by duration. Only native NO-prefixed files used. Front and rear came from separate clips. The 2CH estimate adds their rates, not a measured matched pair. A separate 4K60 front sample is cataloged as its own mode. Do not infer a controlled FPS-only comparison.

## Escort M1

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 1920x1080 | 30 | ~11.9 Mbps | MOV | `ffprobe` |
| F (front) | driving | H.264 | 1920x1080 | 30 | ~16.4 Mbps | MOV | `ffprobe` |

**Notes:** The mounted archive contains several 180-second driving clips. The model appears to stay at 1080p H.264 in the sampled footage.

## Escort M2

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 1920x1080 | 30 | ~8.2 Mbps | MP4 | `ffprobe` |
| F (front) | parking | HEVC | 3840x2160 | 30 | ~60.0 Mbps | MP4 | `ffprobe` |
| F (front) | event | H.264 | 1920x1080 | 30 | ~8.2 Mbps | MP4 | `ffprobe` |

**Notes:** The archive contains both `CAM` and `PF` families. Parking clips can be 4K HEVC in this sample set.

## Cobra Road Scout

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving / SOS | H.264 | 1920x1080 | 30 | ~14.3-14.4 Mbps | MOV | `ffprobe` |

**Notes:** The archive shows consistent 180-second SOS clips at 1080p.

## Cansonic UltraDash Z3+ Standard Edition

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| L (wide front) | driving | HEVC | 2560x1440 | 30 | ~14.3 Mbps | MP4 | `ffprobe` |
| R (telephoto front) | driving | HEVC | 2560x1440 | 30 | ~14.3 Mbps | MP4 | `ffprobe` |
| B (rear) | driving | H.264 | 2560x1440 | 30 | ~11.9 Mbps | MP4 | `ffprobe` |

**Notes:** The archive also contains 4K `C####` clips, but the primary dashcam footage in this pass is 2K QHD across the named channels.

## Rove R2-4K

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | parking impact | H.264 | 2880x2160 | 24 | ~24.6 Mbps | MP4 | `ffprobe` |

**Notes:** The mounted folder has limited raw dashcam footage and several phone/menu clips. The measured camera-looking parking clip uses `YYYY_MMDD_HHMMSS_SEQ`.

## Rove R2-4K Dual

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | HEVC | 3840x2160 | 30 | ~25.0237 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | HEVC | 1920x1080 | 30 | ~11.1216 Mbps | MP4 | `ffprobe` |

**Storage-rate verification (2026-09-08):** Probed original driving files using complete file size divided by duration. Matched front/rear pair at 20240903-210812. Both files are 60.340789 seconds.

## Rove R2-4K Pro

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | HEVC | 3840x2160 | 30 | ~36.9 Mbps | MP4 | `ffprobe` |

**Notes:** The driving clips use `YYYY_MMDD_HHMMSS_SEQ`. A real app-submitted Learn Card package for R2-4K Pro also confirmed a root `Video/` folder with 25 MP4 clips using this filename pattern.

## Not Found In This Pass

No mounted media files were found for these models in this archive pass:

- 70mai T800 raw card-origin clips; the folder currently exposes produced/review-style media only
- DJI Mini 3 Pro
- Sony A7 III

Those rows stay on manual/spec-driven data until we get real footage samples.

## Vueroid S1 4K Infinite

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 3840x2160 | 30 | ~55.021 Mbps | MP4 | `ffprobe` |
| I (interior) | driving | H.264 | 1920x1080 | 30 | ~17.196 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 2560x1440 | 30 | ~25.222 Mbps | MP4 | `ffprobe` |

**Storage-rate measurement (2026-09-08):** Direct INF driving clips from a complete 3CH set (20250922_114903), each 60.032 seconds. Front/interior/rear file sizes: 412876800 / 129040384 / 189267968 bytes. Rates above use complete file size divided by duration, including preallocated padding, not just encoded video. Video streams measured about 48 / 15 / 22 Mbps. A later complete 2CH pair (20260603_212826) confirmed the same front/rear file sizes and duration. Excluded shortened 46.528-second end clips from the baseline. Quality menu selection is unconfirmed. Reduced-channel estimates assume unchanged per-channel file allocation.

### A119 Mini 2 — isolated 60 fps storage-rate check (2026-09-08)

Two original driving clips (20230717111528_005186 and 20230721073714_005418)
were independently probed: both 2560x1440 at 60/1 fps, 60.000 seconds,
201729099 / 201730671 bytes, about 26.8972–26.8975 Mbps complete-file
storage rates. Video streams were about 26.6232 Mbps. Quality menu selection
was not recorded. These samples support a separate 60fps setting, not a claim
of maximum quality or a controlled comparison with 30fps manufacturer figures.

## Thinkware U1000

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | HEVC | 3840x2160 | 30 | ~27.6824 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | HEVC | 2560x1440 | 30 | ~14.2606 Mbps | MP4 | `ffprobe` |

**Storage-rate verification (2026-09-08):** Complete original driving-channel set, using file size divided by duration including container overhead. Exact quality menu setting not saved.

## BlackVue DR750-2CH LTE

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 1920x1080 | 60 | ~25.8395 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 1920x1080 | 30 | ~11.1116 Mbps | MP4 | `ffprobe` |

**Storage-rate verification (2026-09-08):** Original camera-named files from the driving archive, using complete file size divided by duration. Front and Rear from the same timestamp. Menu quality setting not retained.

## Nextbase 622GW

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 3840x2160 | 30 | ~48.4191 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 1920x1080 | 30 | ~14.8982 Mbps | MP4 | `ffprobe` |

**Storage-rate verification (2026-09-08):** Original camera-named files from the driving archive, using complete file size divided by duration. Front and Rear from the same timestamp. Menu quality setting not retained.
Matched 45.045-second FH/RH pair (201120_082835_077). Alexa-protected driving clip. Later 60.06-second front files measured about 50.28–53.08 Mbps of complete-file storage. The matched pair estimate is representative, not a fixed bitrate guarantee.

## Cobra SC 200D

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 2560x1600 | 30 | ~39.0032 Mbps | MP4 | `ffprobe` |

**Storage-rate verification (2026-09-08):** Original camera-named files from the driving archive, using complete file size divided by duration. Front-only recording evidence. Menu quality setting not retained.

## VIOFO A229

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 2560x1440 | 30 | ~31.5634 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 2560x1440 | 30 | ~25.7251 Mbps | MP4 | `ffprobe` |

**Storage-rate verification (2026-09-08):** Original camera-named files from the driving archive, using complete file size divided by duration. Front and Rear from the same timestamp. Menu quality setting not retained.

## VIOFO WM1

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 2560x1440 | 30 | ~27.9444 Mbps | MP4 | `ffprobe` |

**Storage-rate verification (2026-09-08):** Original camera-named files from the driving archive, using complete file size divided by duration. Front-only recording evidence. Menu quality setting not retained.

## VIOFO VS1

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 2560x1440 | 30 | ~25.6728 Mbps | MP4 | `ffprobe` |

**Storage-rate verification (2026-09-08):** Original camera-named files from the driving archive, using complete file size divided by duration. Front-only recording evidence. Menu quality setting not retained.

## VIOFO A329

| Channel | Mode | Codec | Resolution | FPS | Bitrate | Container | Source |
|---|---|---|---|---|---|---|---|
| F (front) | driving | H.264 | 3840x2160 | 60 | ~65.9904 Mbps | MP4 | `ffprobe` |
| R (rear) | driving | H.264 | 2560x1440 | 30 | ~27.4028 Mbps | MP4 | `ffprobe` |

**Storage-rate verification (2026-09-08):** Original camera-named files from the driving archive, using complete file size divided by duration. Front and Rear from the same timestamp. Menu quality setting not retained.

### Additional resolution/FPS witnesses (2026-09-08)

Vantrue N5 1944p option: complete 20240614_125501_00080_N_A/B/C/D set.
Front is 2592x1944 at 30fps, 123731968 bytes / 60 seconds. The three other
1080p30 cameras are 77594624 bytes each over about 60 seconds. Compared with
the 1440p baseline, this is a distinct observed configuration, not a bitrate
inferred from resolution.

70mai 4K Omni front 60fps option: native NO20250516-092136-001948F driving
file, HEVC 3840x2160 at 60/1fps, 243305578 bytes / 60.032 seconds. The 30fps
sample was NO20250501-153114-000028F. Quality/session differences mean the
storage difference must not be attributed to FPS alone.
