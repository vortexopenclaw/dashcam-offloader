# VIOFO T340 4CH card evidence

## Normal bitrate / Low Power parking sample reviewed 2026-10-07

The owner confirms four-channel recording, **Normal** driving bitrate and **Low Power** parking. HDR is on for front and interior, off for rear and telephoto. These are owner-reported settings, not settings extracted from the video.

The sanitized app submission contains **256 MP4 files**, 64 per camera: 29 driving and 35 parking per camera. Eight video-spec groups measured **H.264 at 30 fps** throughout. Values below are encoded-video bitrate ranges, in decimal Mbps, reported by the app (`app_submission`), not independently re-measured with ffprobe.

| Camera | Resolution | HDR (owner-confirmed) | Normal driving Mbps | Low Power parking Mbps |
|---|---|---|---|---|
| front | 3840x2160 | on | 31.940932-31.953844 | 4.094852-4.096339 |
| interior | 2560x1440 | on | 14.329020-14.336068 | 4.094864-4.097066 |
| rear | 2560x1440 | off | 14.333394-14.335724 | 4.094978-4.095841 |
| telephoto | 2560x1440 | off | 14.332282-14.335972 | 4.095185-4.096227 |

The three 2K cameras have essentially equal bitrate despite the mixed HDR settings in this configuration. This is not a controlled HDR toggle test and cannot prove that HDR never changes bitrate. Combined encoded-video bitrate is approximately **74.95 Mbps driving** and **16.38 Mbps parking**. Low Power preserves the measured resolution and frame rate while lowering encoded bitrate; the front drops about 87% and each 2K camera about 71%.

No paired file-size/duration measurements were supplied. These values do **not** certify whole-file storage rate or recording time; audio, container overhead and padding remain unmeasured. Low Power is the owner-confirmed setting, not independent evidence of continuous, motion or impact triggering. Redacted folder paths do not validate the inferred card layout. Keep this Normal-setting sample separate from the older Max-setting ranges below.

## Historical Max-setting sample

A private **submitted sanitized** scan reviewed 2026-09-30 identified the owner's camera as VIOFO T340, 4CH. Separately supplied filename examples follow the generalized `YYYY_MMDD_HHMMSS_SEQUENCE_[F/R/I/T].MP4` family. These support F/R/I/T suffixes and per-file sequence, but the sanitized scan itself has no filename or folder evidence. The owner confirmed the **Max** driving bitrate setting; the broad historical ranges below are not one controlled settings comparison. No source card was available for a fresh read-only rescan.

The sanitized scan counted **387 items: 371 MP4 and 16 JPG**. App-assigned channel counts are front 107, interior 108, rear 91, unknown 81. These totals include photos; unknown 81 is **not** a proven telephoto count. The app classified 305 items as Driving, 8 Driving Event, 40 Parking Continuous / Low Bitrate, 8 Parking Motion Detection, 10 Parking Impact Detection, and 16 JPEG. These are app classifications, not camera-settings confirmations.

Its 20 video-spec groups measured H.264 at 30 fps. The table lists MP4 counts and sampled bitrate ranges in Mb/s (rounded from bits/s):

| App mode | Front 3840x2160 | Interior 2560x1440 | Rear 2560x1440 | Unknown 2560x1440 |
|---|---|---|---|---|
| Driving | 85, 32.0-65.0 | 86, 14.3-27.0 | 72, 14.3-40.1 | 62, 14.3-32.7 |
| Driving Event | 2, 53.2-53.3 | 2, 27.0 | 2, 27.0 | 2, 27.0 |
| Parking Continuous / Low Bitrate | 10, 10.64-10.65 | 10, 8.19-8.22 | 10, 8.19-8.21 | 10, 8.19-8.21 |
| Parking Motion Detection | 2, 10.64-10.65 | 2, 8.19-8.23 | 2, 8.19-8.24 | 2, 8.19-8.21 |
| Parking Impact Detection | 3, 13.2-31.8 | 3, 8.29-14.4 | 2, 11.6-14.4 | 2, 11.1-14.3 |

**Review flags:** The older scan fell back to a generic profile after an A329T candidate. The `T` mapping is supported by owner-provided example names and the T340 four-camera layout, not proven by that sanitized aggregate alone. The T340 folder layout and parking PF/PR/PI/PT suffixes remain inferred and experimental. Lower parking bitrate cannot establish the selected parking subtype. A newly submitted scan with bounded camera-shaped basenames can validate suffix samples, but cannot prove a camera setting without owner confirmation. Do not publish private raw submissions or personal filenames.

The official [VIOFO T340-series description](https://www.viofo.com/blogs/viofo-car-dash-camera-guide-faq-and-news/meet-the-new-viofo-lineup-t340-series-t330-series-a149-pro-duo-bp60) confirms front, interior, rear and telephoto cameras. The experimental profile requires a full four-channel F/R/I/T set to favor T340 over three-channel siblings on an unlabeled card. A sibling without I must not be claimed as T340.
