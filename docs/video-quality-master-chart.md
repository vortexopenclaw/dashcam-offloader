# Video Quality Master Chart

Quick cross-camera reference for channel layout, measured file metadata, and parking-mode quality behavior.

This chart is for research and comparison, not model identification. Resolution, bitrate, codec, and frame rate can be user-configurable and firmware-dependent. Prefer real card-origin clips over product-page claims.

## Validation Rules

- Keep marketed resolution separate from measured file resolution.
- Treat 3840x2160 files as "file-level 4K" only. This does not prove native 4K optical detail.
- Flag likely interpolation risk when a camera is marketed as 4K but the sensor, frame-rate behavior, or bitrate suggests upscaled/lower-detail capture.
- Use direct dashcam files only. Exclude review exports, b-roll, phone footage, thumbnails, and app screen recordings.
- Store parking-mode rows separately because low-bitrate continuous, impact/event, motion, and time-lapse modes can behave very differently.
- Re-measure after firmware updates or bitrate setting changes.

## Front 4K30 Driving Comparison

Representative front-channel driving rows where measured files are 3840x2160 at about 30 fps.

| Camera | Channels In Sample | Front Codec | Front File Resolution | FPS | Front Driving Bitrate | Source | Quality Notes |
|---|---:|---|---|---:|---:|---|---|
| BlackVue Elite 9 | 2 | HEVC | 3840x2160 | 30 | ~60.0 Mbps | ffprobe | Strong 4K-file bitrate; rear measured 1440p at ~25 Mbps. |
| BlackVue DR970X-2CH Plus | 2 | HEVC | 3840x2160 | 30 | ~60.0 Mbps | ffprobe | Front row only from camera-looking clips in mixed archive. |
| VIOFO A329T | 3 | H.264 | 3840x2160 | 30 | ~65.5 Mbps | ffprobe | Highest measured H.264 front bitrate in current log; telephoto and rear 1440p at ~27 Mbps. |
| VIOFO A329S | 3 | H.264 | 3840x2160 | 30 | ~53-66 Mbps | ffprobe | Front channel stays high even in 3CH sample. |
| VIOFO A139 Pro | 3 | HEVC | 3840x2160 | 30 | ~53.3 Mbps | ffprobe | Rear/interior 1080p; parking codec varies. |
| VIOFO A129 Pro | 2 | HEVC | 3840x2160 | 30 | ~51.2 Mbps | ffprobe | Older 4K front plus 1080p rear sample. |
| VIOFO A229 Pro | 3 | H.264 | 3840x2160 | 30 | ~36.0 Mbps | ffprobe | Rear 1440p at ~24 Mbps, interior 1080p at ~15.6 Mbps. |
| VIOFO A229 Ultra | 3 | H.264 | 3840x2160 | 30 | ~36.0 Mbps | ffprobe | Front and rear both measured 4K; interior 1080p. |
| VIOFO A119M Pro | 1 | H.264 | 3840x2160 | 30 | ~36.9 Mbps | ffprobe | Single-channel 4K sample. |
| Thinkware U3000 Pro | 2 | HEVC | 3840x2160 | 30 | ~30.0 Mbps | ffprobe | Rear 1440p at ~10 Mbps; parking motion can drop sharply. |
| Thinkware U3000 | 2 | HEVC | 3840x2160 | 30 | ~30.0 Mbps | ffprobe | Similar front driving bitrate to U3000 Pro in sample. |
| Thinkware U1000 Plus | 2 | HEVC | 3840x2160 | 30 | ~24.0 Mbps | ffprobe | Rear 1080p at ~6 Mbps. |
| Vantrue N4 Pro S | 3 | HEVC | 3840x2160 | 30 | ~31.9 Mbps | ffprobe | Front highest; interior 1080p ~9.8 Mbps, rear 1440p ~14.3 Mbps. |
| Vantrue E1 Pro | 1 | H.264 | 3840x2160 | 30 | ~31.9 Mbps | ffprobe | Time-lapse parking can keep 4K30 at same bitrate in sample. |
| 70mai 4K Omni X800 | 1-2 mixed archive + 2CH card layout | HEVC | 3840x2160 | 30 | ~31.9-60.3 Mbps | ffprobe/card scan | X800 and 4K Omni are the same product family; clean card confirms layout, archive still informs media specs. |
| Rove R2-4K Dual | 2 | HEVC | 3840x2160 | 30 | ~20.0 Mbps | ffprobe | 4K file at relatively low bitrate. |
| Rove R2-4K Pro | 1 | HEVC | 3840x2160 | 30 | ~36.9 Mbps | ffprobe | Real app submission confirmed root Video folder and filename family. |

## Parking Bitrate Drop Examples

These rows compare measured front-channel driving quality against measured parking-mode front-channel files where both exist.

| Camera | Driving Front | Parking Front | Approx Drop | Parking Mode Evidence | Notes |
|---|---:|---:|---:|---|---|
| VIOFO A229 Pro | ~36.0 Mbps | ~4.1 Mbps | ~89% lower | PF/PI/PR parking files | Low-bitrate parking behavior in submitted card. |
| VIOFO A329S | ~53-66 Mbps | ~53.3 Mbps | none to mild | PF/PI/PR parking files | Front parking sample can preserve full front bitrate. |
| VIOFO A329T | ~65.5 Mbps | ~4.2 Mbps | ~94% lower | PF/PT/PR parking files | Parking clips stay very low bitrate across channels. |
| VIOFO A139 Pro | ~53.3 Mbps | ~9.9-14.8 Mbps | ~72-81% lower | PF/PI/PR parking files | Parking codec can vary between H.264 and HEVC. |
| VIOFO A129 Pro | ~51.2 Mbps | ~8.4-26.6 Mbps | variable | PF parking files | Mixed parking variants in sampled archive. |
| VIOFO A119 Mini 2 | ~26.6-28.8 Mbps | ~3.8 Mbps | ~86% lower | parking motion | Time-lapse row measured ~30.3 Mbps, so subtype matters. |
| VIOFO A119M Pro | ~36.9 Mbps | ~3.8-8.4 Mbps | ~77-90% lower | parking files | Parking drops to 1440p in sampled archive. |
| Thinkware U3000 Pro | ~30.0 Mbps | ~5.0 Mbps | ~83% lower | MOT parking motion | Parking event row measured 4K at ~12 Mbps. |
| Thinkware U3000 | ~30.0 Mbps | ~12.0 Mbps | ~60% lower | MOT parking motion | Manual 4K row measured ~30 Mbps. |
| Thinkware U1000 Plus | ~24.0 Mbps | ~10.0-12.1 Mbps | ~50-58% lower | parking motion/event | Parking front can stay 4K but lower bitrate. |
| Vantrue N4 Pro S | ~31.9 Mbps | ~31.9 Mbps | none in sample | parking files | Current sample preserves front channel bitrate. |
| Vantrue E1 Pro | ~31.9 Mbps | ~4.9-5.0 Mbps | ~84-85% lower | parking motion | Time-lapse parking stays 4K30 at ~31.9 Mbps in sample. |
| Vantrue N4 | ~10.6-15.6 Mbps | ~0.7-1.3 Mbps | ~88-96% lower | A/B parking files | Parking drops to 720p in sampled archive. |
| BlackVue Elite 9 | ~60.0 Mbps | ~56-60 Mbps | none to mild | PF/IF parking files | Rear parking stayed ~25 Mbps. |
| BlackVue DR750S-2CH | ~12.6 Mbps | ~10.5-12.6 Mbps | none to mild | PF/PR parking files | Parking rows look close to driving bitrate. |
| Thinkware F800 Pro | ~10.0 Mbps | ~3.5 Mbps | ~65% lower | PAK parking event | Parking event row measured at lower frame rate. |
| Thinkware FA200 | not measured | ~3.3 Mbps | unknown | TIM parking timelapse | Time-lapse row only; no driving baseline in current chart. |

## Channel And Resolution Summary

| Camera | Observed Channels | Driving Resolution Summary | Driving Bitrate Summary | Parking Summary |
|---|---|---|---|---|
| BlackVue Elite 9 | F/R | F 4K30, R 1440p30 | F ~60 Mbps, R ~25 Mbps | Parking keeps similar bitrate in sample. |
| BlackVue DR770X Box | F/O/R | All 1080p; front can be 60 fps | F ~16 Mbps, O/R ~10 Mbps | Parking/impact use same basic 1080p family. |
| Thinkware U3000 Pro | F/R | F 4K30, R 1440p30 | F ~30 Mbps, R ~10 Mbps | Motion parking drops hard; event parking keeps 4K at ~12 Mbps. |
| Thinkware U3000 | F/R | F 4K30, R 1440p30 | F ~30 Mbps, R ~10 Mbps | Motion parking lower; manual parking can preserve full 4K bitrate. |
| VIOFO A229 Pro | F/I/R | F 4K30, I 1080p30, R 1440p30 | F ~36 Mbps, I ~15.6 Mbps, R ~24 Mbps | Low-bitrate parking around ~4 Mbps per channel. |
| VIOFO A229 Ultra | F/I/R | F 4K30, I 1080p30, R 4K30 | F ~36 Mbps, I ~15.6 Mbps, R ~34.4 Mbps | PF sample 1440p at ~12.3 Mbps. |
| VIOFO A329S | F/I/R | F 4K30, I 1080p30, R 1440p30 | F ~53-66 Mbps, I ~15.6 Mbps, R ~23.8 Mbps | Front parking can preserve full 4K bitrate. |
| VIOFO A329T | F/T/R | F 4K30, T/R 1440p30 | F ~65.5 Mbps, T/R ~27 Mbps | Parking drops to ~4 Mbps per channel. |
| VIOFO A139 Pro | F/I/R | F 4K30, I/R 1080p30 | F ~53.3 Mbps, I/R ~13.5-16.4 Mbps | Parking lower bitrate and mixed codec. |
| Vantrue N4 Pro S | A/B/C | A 4K30, B 1080p30, C 1440p30 | A ~31.9 Mbps, B ~9.8 Mbps, C ~14.3 Mbps | Parking front/interior measured similar to driving in current sample. |
| Vantrue N4 S | A/B/C | A/B/C all 1440p30 | ~14.3 Mbps each | Parking not represented in current row. |
| Vantrue E1 Pro | A/front | 4K30 | ~31.9 Mbps | Time-lapse keeps 4K30; motion drops to 1080p15 at ~5 Mbps. |
| Vantrue N4 | A/B/C | A 1440p30, B/C 1080p30 | A ~10.6-15.6 Mbps, B/C ~3.2-11.7 Mbps | Parking drops to 720p and under ~1.3 Mbps. |
| Vantrue E360 | A/C observed | A 5184x1944 ultrawide, C 1440p | A ~28.7 Mbps, C ~14.4 Mbps | Parking not represented in current row. |
| 70mai M310 | F | 2304x1296 30 fps | ~12 Mbps | Parking/lapse measured same resolution/bitrate in sample. |
| 70mai 4K Omni X800 | F/R mixed archive + 2CH card layout | F 4K30, R 1080p30 | F ~31.9-60.3 Mbps, R ~10.9 Mbps | X800 card confirms F/R layout; archive still provides provisional media measurements. |
| Cansonic UltraDash Z3+ | L/R/B | L/R/B all 1440p30 | L/R ~14.3 Mbps, B ~11.9 Mbps | Parking not represented in current row. |
| Rove R2-4K Dual | F | F 4K30 | ~20 Mbps | Protected/parking event stays ~20 Mbps in sample. |
| Rove R2-4K Pro | F | F 4K30 | ~36.9 Mbps | Parking not represented in current row. |

## Interpolation And Marketing Claim Watchlist

Use these checks when comparing "4K" dashcams:

- If a model advertises 4K but measured files are below 3840x2160, log the measured resolution first and keep the marketing claim in notes only.
- If measured files are 3840x2160 but bitrate is unusually low for the codec and scene type, flag for visual-detail review.
- If 4K is only available at reduced frame rate compared with 1440p, log both modes as separate quality settings.
- If channel count changes bitrate or frame rate, log each channel-count configuration separately.
- If parking mode changes resolution, frame rate, codec, or audio, treat each parking subtype as a separate row.
- If sensor details indicate native resolution below file-level 4K, mark the row as possible interpolation even if the MP4 is 3840x2160.

## Open Measurement Gaps

- Native sensor confirmation for many budget 4K-labeled models.
- Bitrate changes by quality setting within the same camera.
- Bitrate changes when the same model runs 1CH, 2CH, 3CH, or multiplex modes.
- Time-lapse frame cadence versus encoded FPS for cameras that store time-lapse as normal 30 fps video.
- Clean card-origin samples for Vueroid S1 4K Infinite, BlackVue Elite 10, BlackVue Elite 8 full front/rear set, Redtiger, and Wolfbox.
