# VIOFO T330W (T330-family rear-camera variant)

Status: experimental, owner-submitted card samples and three owner-provided frame observations. Firmware reported by owner: `1.0_260910`.

## Exact model recognition

The owner-provided front, rear, and interior frames show the **`VIOFO T330W`** on-screen model stamp near the bottom center. The model stamp is user-configurable and may be disabled. Probe front `F` footage with bottom-strip OCR; only an exact model-stamp match should disambiguate this camera from VIOFO A229/A329 siblings. A generic VIOFO card layout or filename suffix is **not** proof of T330W.

T330 and T330W share the same main-camera family; the attached rear camera is a variant. The non-W model's exact OSD stamp has not yet been confirmed. Do not assume a W stamp identifies a different main platform or assume identical measured rear bitrate without testing.

## Card evidence

Three sanitized learning submissions from one owner confirmed `DCIM/Movie`, `DCIM/Movie/Parking`, `DCIM/Movie/RO`, and `DCIM/Photo` with three-channel F/I/R and PF/PI/PR suffixes. The first completed scan (84 files) was originally labeled normal-bitrate driving by the owner, who later corrected the setting name to **Medium**; it also included low-bitrate parking. The second (36 files) was owner-labeled high-bitrate driving and 1-fps Night Vision time-lapse parking. The third (60 files) retained all earlier 36 and added Maximum driving and Auto Event Detection test clips. These settings can coexist on a card; sample clips by folder/channel and do not extrapolate a setting to all files.

The second submission's `RO` parking clips have 30-fps playback, with two recording starts 30 minutes apart and one 60-second clip per channel; this is consistent with 1-fps capture over 30 minutes. The owner reports no audio on those clips, but the sanitized scan does not include audio-track presence. Do **not** label all RO clips as impact events or all RO clips as time lapse: use model-specific media timing/audio context or a confirmed setting. The profile folder mapping stays protected/neutral pending that classification fix.

## Mixed-settings card measurements reviewed 2026-10-11

Source: owner-labeled sanitized 0.1.29 scan received 2026-10-11 and retained in the private submission store (anonymous numerical evidence digest `70d8b5b34c973767872de30349d986c1700c2983c809374cbcf2563b05a03419`). It selected `viofo-t330w` through the exact on-video model-stamp OCR on an actual card. The 60-file scan contains 45 driving MP4, nine `RO` MP4, and six JPG. **All 36 files** in the preceding complete scan remain present with unchanged sizes; 24 items were added (18 driving, three `RO`, three JPG). The owner changed High driving to Maximum and 1-fps Night Vision time-lapse to Auto Event Detection at approximately 19:25, without formatting. The last earlier driving triplet starts at 19:24:41 and the first later triplet at 19:26:23. Settings attribution is based on that owner report, clip times, and separated bitrate bands, not on the RO folder alone.

The structured evidence databases `web/recording-time/storage-evidence.json` here and `docs/data/storage-evidence.json` in the camera-profile repository each retain **63 anonymous, paired size/duration/video-bitrate samples**, separated by `settingsLabel` and source digest: 33 from the earlier Medium/low-rate scan and 30 from this High/Maximum/time-lapse/Auto Event mixed-card scan. The private submissions retain per-file sizes, and their video summary groups preserve the full sampled bitrate ranges. Numbers below are decimal Mbps and exact whole-file bytes; video-track rates exclude audio, padding, and container overhead. Counts are *sampled clips* per channel, not all 54 videos in the latest scan.

| Owner-reported setting | Channel | Sample count | Video bitrate range (Mbps) | Whole-file size range (bytes) | Encoded playback duration range (s) | Paired 60-s file (bytes) |
|---|---|---:|---:|---:|---:|---:|
| High driving | front 4K30 | 4 | 36.780560–36.874132 | 50,331,648–278,921,216 | 10.50–60 | 278,921,216 |
| High driving | interior 2K30 | 4 | 21.294788–21.300250 | 28,338,864–161,480,704 | 10.50–60 | 161,480,704 |
| High driving | rear 2K30 | 4 | 21.293700–21.372390 | 28,433,556–161,480,704 | 10.50–60 | 161,480,704 |
| Maximum driving | front 4K30 | 3 | 40.956664–40.966788 | 119,537,664–310,378,496 | 23.10–60 | 310,378,496 |
| Maximum driving | interior 2K30 | 3 | 23.754904–23.788794 | 71,303,168–180,355,072 | 23.10–60 | 180,355,072 |
| Maximum driving | rear 2K30 | 3 | 23.754254–23.822754 | 71,303,168–180,355,072 | 23.10–60 | 180,355,072 |
| Night Vision 1-fps time-lapse (`RO`) | front 4K, nominal 30-fps playback | 2 | 40.960332–40.961492 | 102,760,448–310,378,496 | 19.83–60 | 310,378,496 |
| Night Vision 1-fps time-lapse (`RO`) | interior 2K, nominal 30-fps playback | 2 | 20.478652–20.478662 | 52,428,800–155,189,248 | 19.87–60 | 155,189,248 |
| Night Vision 1-fps time-lapse (`RO`) | rear 2K, nominal 30-fps playback | 2 | 20.465122–20.477616 | 52,428,800–155,189,248 | 19.83–60 | 155,189,248 |
| Auto Event Detection (`RO`) | front 4K30 | 1 | 49.156032 | 358,612,992 | 57.93 | not sampled |
| Auto Event Detection (`RO`) | interior 2K30 | 1 | 27.031126 | 197,132,288 | 57.97 | not sampled |
| Auto Event Detection (`RO`) | rear 2K30 | 1 | 27.023146 | 197,132,288 | 57.93 | not sampled |

The two full-minute triplets per driving setting measure **601,882,624 bytes/min (36.113 GB per encoded hour)** for High versus **671,088,640 bytes/min (40.265 GB per encoded hour)** for Maximum, across all three channels. These are representative complete-file rates at the observed settings, not a full-card average. The prior time-lapse triplet totals 620,756,992 bytes for 60 seconds **of playback**, not 60 seconds of parked wall time. Do not turn that into a parking retention estimate. The new Auto Event triplet is approximately 58 seconds per channel, not a measured full 60-second loop; event/idle duty cycle remains unknown. No audio-track measurement is captured by the sanitized scan. Previously observed low-bitrate parking-folder video around 4.1 Mbps per channel belongs to a separate setting generation, not either `RO` cohort. Owner-reported parking current is 529 mA low-bitrate and 607 mA average Auto Event Detection; supply voltage unknown, so watts cannot be inferred.

### Earlier Medium / low-rate card scan

The owner originally wrote “Normal” for the driving setting in this submission and later corrected it to **Medium**. Its measured files and original private note are unchanged; the reviewed settings label is Medium.

The earlier owner-labeled 84-file card scan supplies **33 paired samples** (private submission, anonymous evidence digest `68fc2f7e089aeb97dfffbf538da4b21c3870bee2a88ecf34a456995371ad01b1`). Preserve its Medium driving and low-bitrate parking separately from the later High/Maximum and time-lapse/Auto Event tests. The low-rate `RO` group was called an impact mode by generic scanner inference, **not confirmed by the owner**, so its trigger remains unknown.

| Observed cohort | Channel | Samples | Sampled video Mbps | Paired complete 60-s file |
|---|---|---:|---:|---:|
| Owner-labeled Medium driving | front | 4 | 31.947826–31.952090 | 243,269,632 bytes |
| Owner-labeled Medium driving | interior | 4 | 14.334801–14.356925 | 111,149,056 bytes |
| Owner-labeled Medium driving | rear | 4 | 14.334439–14.363250 | 111,149,056 bytes |
| Owner-labeled low-bitrate parking | front | 4 | 4.094630–4.096767 | 33,554,432 bytes |
| Owner-labeled low-bitrate parking | interior | 4 | 4.095199–4.095962 | 33,554,432 bytes |
| Owner-labeled low-bitrate parking | rear | 4 | 4.094958–4.096417 | 33,554,432 bytes |
| Low-rate `RO`, trigger unconfirmed | front | 3 | 4.095839–4.096074 | 33,554,432 bytes |
| Low-rate `RO`, trigger unconfirmed | interior | 3 | 4.095721–4.095886 | 33,554,432 bytes |
| Low-rate `RO`, trigger unconfirmed | rear | 3 | 4.095771–4.095891 | 33,554,432 bytes |

Complete 60-second three-channel Medium driving files total **465,567,744 bytes/min (27.934 GB/hour)**; low-bitrate parking files total **100,663,296 bytes/min (6.040 GB/hour) while actively recording**. The paired evidence also preserves shorter clips (15.3 seconds driving, 25.97 seconds parking) and their actual byte sizes. These are distinct from the later `RO` modes; none of these per-playback-hour rates establishes elapsed parked-time retention.

No raw user frames or footage are distributed in this repository. App OCR is local and sends neither frames nor OSD text in feedback.
