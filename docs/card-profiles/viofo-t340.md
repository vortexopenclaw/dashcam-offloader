# VIOFO T340 4CH card evidence

## High bitrate / Low Bitrate parking sample reviewed 2026-10-07

The owner confirms **High** driving bitrate, **Low Bitrate** parking and manual emergency button events. This scan contains **100 media items**: 40 Driving MP4, 20 Protected MP4, 28 Parking MP4 and 12 JPG. Each camera has 10 driving, five protected and seven parking videos, plus three photos. All 12 video groups report H.264 at 30 fps; front is 3840x2160 and interior/rear/telephoto are 2560x1440. HDR and firmware were not recorded with this submission; do not silently carry settings forward.

| Camera | High driving Mbps | Protected Mbps | Low Bitrate parking Mbps |
|---|---|---|---|
| front | 36.847188-36.867416 | 36.800028-36.872988 | 4.094099-4.099248 |
| interior | 21.297184-21.324242 | 21.297322-21.302340 | 4.094853-4.099727 |
| rear | 21.297310-21.314644 | 21.288770-21.299056 | 4.094983-4.098455 |
| telephoto | 21.297458-21.317968 | 21.289786-21.298966 | 4.095149-4.096421 |

Parking is approximately **4.095 Mbps per camera**, effectively matching the earlier Normal-driving sample. However, the earlier owner label was **Low Power**, whereas this one is **Low Bitrate**. These are not automatically equivalent settings: VIOFO lists Low Power Impact Detection separately from Low Bitrate Recording. This proves matching observed parking rates across these two scans, not a controlled Normal-versus-High comparison of an identically confirmed parking setting. Low and Max driving with confirmed Low Bitrate parking remain to be tested. Protected videos retain approximately the High driving bitrate; their sampled duration range is 8.533333-60 seconds, which does not establish a fixed emergency-event window or buffering policy.

The bounded basename sample includes 72 MP4 and eight JPG names. MP4 suffix counts are 11 each F/R/I/T and seven each PF/PR/PI/PT; JPG suffix counts are two each F/R/I/T. Their generalized family is `YYYY_MMDD_HHMMSS_SEQUENCE[F/R/I/T/PF/PR/PI/PT].MP4` and `YYYY_MMDD_HHMMSS_SEQUENCE[F/R/I/T].JPG`, with no separator between sequence and suffix. These validate the sampled channel suffixes and filename family, including parking P prefixes. There is no separate emergency token among the sampled names, but names are not linked to recording categories and the sample is incomplete. Therefore an emergency-specific naming rule, exact protected folder, event-to-clip grouping and all-four-camera synchronization remain unverified. Folder paths, directory summaries and clip-group summaries were stripped or absent. Do not claim `DCIM/Movie/RO` is card-validated from this scan.

No paired file-size/duration samples are present. Independent minimum/maximum sizes and durations cannot be paired to certify storage rate. The recording-time calculator is unchanged. Other parking-mode filename conventions, mode switching and event behavior still need setting-labeled structural scans.

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

**Review flags:** The older scan fell back to a generic profile after an A329T candidate. The `T` mapping was supported by owner-provided example names and the four-camera layout, not proven by that historical aggregate alone. The newer High-setting scan validates sampled F/R/I/T and PF/PR/PI/PT suffixes, but folder layout remains inferred and experimental. Lower parking bitrate cannot establish the selected parking subtype. Do not publish private raw submissions or personal filenames.

The official [VIOFO T340-series description](https://www.viofo.com/blogs/viofo-car-dash-camera-guide-faq-and-news/meet-the-new-viofo-lineup-t340-series-t330-series-a149-pro-duo-bp60) confirms front, interior, rear and telephoto cameras. The experimental profile requires a full four-channel F/R/I/T set to favor T340 over three-channel siblings on an unlabeled card. A sibling without I must not be claimed as T340.
