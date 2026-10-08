# VIOFO T340 4CH card evidence

## Owner-confirmed settings vocabulary

Driving bitrate has four settings: **Low, Normal, High, Maximum**. Earlier
owner shorthand "Max" means Maximum. Keep **Low Bitrate** continuous parking
separate from **Low Power Impact Detection**, which waits in standby and wakes
for an impact. The owner expects impact-triggered Low Power recording to return
to full driving bitrate; a controlled, setting-labeled impact sample is still
needed to verify its bitrate on this firmware. Lower encoded bitrate alone
cannot identify the parking mode.

## Low bitrate structural sample reviewed 2026-10-08

The owner identifies the latest submission as **Low driving bitrate**, with
front/rear/interior/telephoto recording. The submission contains **2,104 media
items**: 2,032 driving MP4 (508 per camera), 36 parking MP4 (nine per camera),
20 protected-folder MP4 (four driving and one parking per camera), and 16 JPG.
All 16 video groups are H.264 at 30 fps, front 3840x2160 and other cameras
2560x1440. HDR, firmware, multiplexing and the exact parking setting were not
supplied for this scan. The latest owner's Low label applies to this scan,
not the earlier High resubmission.

| Camera | Low driving Mbps | Protected driving Mbps | Parking Mbps | Protected parking Mbps |
|---|---|---|---|---|
| front | 27.033812-27.064794 | 27.030366-27.044604 | 4.095301-4.095867 | 4.117371 |
| interior | 11.876286-11.878153 | 11.878194-11.878413 | 4.094853-4.095778 | 4.096414 |
| rear | 11.875882-11.878477 | 11.878027-11.878515 | 4.095137-4.095935 | 4.095149 |
| telephoto | 11.878389-11.879034 | 11.877543-11.878365 | 4.095119-4.095836 | 4.095510 |

Combined Low driving video is approximately **62.67 Mbps**, versus **74.95 Mbps
Normal** and **100.76 Mbps High** in the earlier four-channel scans. These are
app-reported encoded-video measurements, not an independent ffprobe analysis.
Parking remains about 4.095 Mbps per camera across these scans, but unmatched
or uncertain parking settings prevent a controlled mode-equivalence claim.

### Observed folder, filename and protection linkage

- `DCIM/Movie`: 2,032 driving MP4, sampled suffixes F/R/I/T.
- `DCIM/Movie/Parking`: 36 parking MP4, sampled suffixes PF/PR/PI/PT.
- `DCIM/Movie/RO`: 16 protected driving MP4 using F/R/I/T and four protected
  parking MP4 using PF/PR/PI/PT. No extra emergency suffix appears in these samples.
- `DCIM/Photo`: 16 JPG, including both F/R/I/T and PF/PR/PI/PT suffix families.

All 20 RO files are present in the bounded 120-file structural sample and
report `userImmutable=true`; the other 100 sampled media report false.
All sampled files report POSIX 0700, `filesystemReadOnly=false`,
`systemImmutable=false` and `volumeReadOnly=false`. Thus immutable lock evidence,
not missing POSIX write permissions, distinguishes the protected clips on this
mount. The scanner inspected these attributes without changing them.

The protected sample has four driving filename-timestamp sets and one parking
set, each containing all four camera roles. This supports four-channel grouping
by filename timestamp, not frame-exact synchronization, a fixed event window,
or proof of what triggered protection. The app calls the RO parking clips
`parking_impact_detection`; this is an **app inference**. Their low bitrate does
not demonstrate full-rate wake-up in Low Power Impact Detection, nor prove that
a physical impact rather than manual locking created them.

### Paired whole-file storage measurements

This scan supplies paired size/duration samples. Full 60-second Low driving
clips are 205,520,896 bytes front and 92,274,688 bytes per 2K camera: combined
**28.94 decimal GB/hour**. Low encoded-video-only storage is about **28.20 GB/hour**;
whole-file measurements include padding, audio and container overhead. Short
clips vary in whole-file rate and must not be substituted for full clips.
Full 60-second parking clips occupy 33,554,432 bytes per camera, or about
**8.05 decimal GB/hour combined**, versus about 7.37 GB/hour video-only.

The earlier High submission was resubmitted on 2026-10-08 with the same
100-item counts and video ranges. It adds paired samples but no folder
structure and is not an independent quality-setting test. Full 60-second
driving files occupy 278,921,216 bytes front and 161,480,704 bytes per 2K camera,
or **45.80 decimal GB/hour combined**. Keep these configuration-specific
measurements separate; no calculator preset was changed.

**Label conflict:** the original Normal submission's notes say "low bitrate
parking mode", while the earlier Discord description says "low power". Preserve
both labels as conflicting evidence rather than silently assigning a mode.

### Future configuration comparisons

The owner plans three-channel and multiplexing scans. Compare exact connected
camera roles, driving quality, parking mode, resolution/fps, HDR, firmware and
multiplexing setting independently. A higher front bitrate with three channels
and any multiplexing effect are hypotheses, not measured results yet.

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
