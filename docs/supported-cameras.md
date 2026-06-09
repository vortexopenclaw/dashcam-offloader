# Supported Cameras

## Seeded

- Thinkware U3000 Pro - profile drafted from one real card and official documentation.
- Thinkware U3000 - profile drafted from one real card. 2-channel (F/R), no interior cabin support.
- Botslab G980H - profile drafted from an app learning submission and real 4CH card sample. Detected from `MISC/G980HMCN5291.TXT`; unknown `360CARDVR` cards should not be assigned this model without exact marker evidence.
- Vueroid H1 - profile drafted from an app learning submission and one real 1CH card sample. Detected from `CONFIG/config.bin` model text.
- Vueroid S1 4K Infinite - base model profile with 1CH, 2CH, and 3CH variants. One real 3CH sample card inspected.
- VIOFO A329S - base model profile. One real 3CH sample card inspected.
- VIOFO A329T - related telephoto model profile drafted from official VIOFO product references and user-provided filename evidence. No real card inspected yet.
- BlackVue Elite 9 - base model profile. One real 2CH sample card inspected.
- BlackVue DR770X Box - profile drafted from a real app-submitted Learn Card package and private archive direct camera clips. 3-channel evidence (F/O/R = front/interior/rear), 1080p H.264 NAS samples, BlackVue-style mode/channel suffixes.
- BlackVue DR970X Plus - profile drafted from one real 2CH sample card. Firmware v2.008.
- VIOFO A229 Pro - profile drafted from one real 3CH sample card and official VIOFO A229 Pro manual (V26.01.09).
- VIOFO A229 Plus - profile drafted from one real 3CH sample card (fresh format). 2K front and rear, 1080P interior.
- VIOFO A229 Ultra - profile drafted from a private archive sample (no direct card scan). 4K front and rear, 1080P interior. OSD OCR confirmed.
- VIOFO A139 Pro - profile drafted from a private archive sample (no direct card scan). 3-channel. Distinct filename pattern: no sequence number (YYYY_MMDD_HHMMSS_CHANNEL). Mixed codec: HEVC interior.
- VIOFO A119M Pro - profile drafted from a private archive sample (no direct card scan). Single-channel front only. Distinct filename pattern: YYYYMMDDHHMMSS_SEQUENCE (no underscore separators in date/time).
- VIOFO A119 Mini 2 - profile drafted from one real card and official manual V25.12.18. Single-channel front only. Same filename pattern as A119M Pro. Distinct folder structure: parking recordings in DCIM/Parking/ (not DCIM/Movie/Parking/).
- Vantrue N4 Pro S - profile drafted from one real card. 3-channel (A/B/C = Front/Interior/Rear), 4K/1080P/2.5K resolutions.
- Vantrue N4 S - profile drafted from one real card. 3-channel (A/B/C), uniform 2.5K across all channels (balanced bitrates).
- Vantrue E1 Pro - profile drafted from one real single-channel card and official manual. Observed Normal driving clips, motion-detection parking clips, parking event clips, and model-specific `GPS/E1PRO_Settings.ini`.
- 70mai M310 - profile drafted from a private archive sample and real card scan. Single-channel front only. Distinct filename pattern: MODE_PREFIX + YYYYMMDD-HHMMSS-SEQUENCE + lowercase .mp4. OSD shows date/time only (no model name). Folder structure confirmed: Normal/, Parking/, Lapse/, Event/, Photo/.
- Cansonic UltraDash Z3+ Standard Edition - profile drafted from a private archive sample and official product page. Dual front-lens camera (L = wide 140°, R = telephoto 164ft) + optional B rear camera (R1). Distinct filename pattern: YYYYMMDD_HHMMSS_CHANNEL (no sequence number, 8-digit date). All channels 2K QHD.
- Cansonic UltraDash Z4 Standard Edition - profile drafted from real app submission and direct card scan. 3CH L/R/B clips in VIDEO/ and P-prefixed protected parking clips in PROTECTED/. Sample card shows 4K L/R and 2K B H.264 video.
- Rove R2-4K Pro - profile drafted from a real app-submitted Learn Card package, Rove documentation, and supplemental NAS metadata. Single-channel front. Submitted card used Video/ with YYYY_MMDD_HHMMSS_SEQUENCE.MP4 filenames.
- Escort M1 - profile drafted from one real card and official user manual. Single-channel front only. Distinct card layout: all footage in Escort_M1/ subfolder (not DCIM/). Filename pattern YYYY_MMDD_HHMMSS_SEQ.MOV. No parking mode.
- Cobra Road Scout - profile drafted from one real card and official owner's manual. Single-channel front only. Combined radar detector + dashcam. Footage in DCIM/RoadScout/. Filename pattern YYYYMMDD_NNNN_VID.MOV with daily-reset sequence. No parking mode. Permanent rom.bin at card root.
- Escort M2 - profile drafted from one real card and official user manual. Single-channel front only. Footage in Normal/, events in Event/, photos in Photo/. Filename pattern YYYYMMDD_NNNN_CAM.MP4 with per-date 4-digit sequence. GPS sidecar (.map) paired with every clip.
- Escort MAXcam 360c - profile drafted from one real card. Single-channel front only. Combined radar detector + dashcam. Footage in Normal/MAXcam360c/. Filename pattern YYYYMMDD_NNNN_VID.MOV. GPS and g-sensor sidecars (_gps.bin, _gsensor.bin) appear after GPS lock.
- DJI Mini 3 Pro - profile drafted from one real card. Single-channel drone. DCIM/100MEDIA/ layout. Filename pattern DJI_####.MP4 with shared global sequence across video and photo. SRT telemetry sidecar paired with every clip.
- Sony Alpha A7 III (ILCE-7M3) - profile drafted from two real cards (one video+photo, one video-only). Mirrorless camera using Sony M4ROOT/XAVC S format. Model detected via PRIVATE/M4ROOT/MEDIAPRO.XML systemKind field. Video codec confirmed H.264 (AVC_3840_2160_HP@L51). Photos are ARW raw files. DCIM/ absent on video-only cards.
- BlackVue Elite 8 - profile drafted from one real 2CH sample card and official BlackVue Elite 8 manual. Both front and rear at 2K QHD (2560x1440) @ 30fps H.264. Detected via config.ini ap_ssid field (BlackVueElite8-). Filename pattern matches Elite 9 family.
- DJI RC (RM330) - profile drafted from one real card. Companion device (remote controller), not a camera. Android-based, runs DJI Fly (dji.go.v5). Detected via Android/data/dji.go.v5/ folder structure. Primary content is live-view OcuSync transmission caches (MediaCaches/). Full-resolution drone footage stays on the drone's own microSD.
- VIOFO WM1 - private archive sample with OSD OCR confirmed. Single-channel pattern: YYYYMMDDHHMMSS_SEQUENCE, with P suffix observed for parking.
- VIOFO VS1 - private archive sample with OSD OCR confirmed. Single-channel pattern: YYYYMMDDHHMMSS_SEQUENCE, with P suffix observed for parking.
- VIOFO T130 - private archive sample with OSD OCR confirmed. 3-channel F/I/R pattern: YYYY_MMDD_HHMMSS_CHANNEL.
- VIOFO A129 Duo - filename-only seed from private archive samples. Dual-channel F/R pattern: YYYY_MMDD_HHMMSS_SEQUENCE_CHANNEL.
- VIOFO A129 Plus Duo - filename-only seed from private archive samples. Dual-channel F/R and parking PF/PR patterns observed across older/newer filename generations.
- VIOFO A129 Pro - filename-only seed from private archive samples. Dual-channel F/R plus PF/PR parking patterns observed.
- Nextbase 622GW - filename-only seed from private archive samples. Front/rear pattern: YYMMDD_HHMMSS_SEQUENCE_FH/RH.
- Thinkware U1000 - filename-only seed from private archive samples. Older underscore-separated Thinkware pattern: REC_YYYY_MM_DD_HH_MM_SS_F/R.
- Thinkware U1000 Plus - filename-only seed from private archive samples. Compact Thinkware pattern: REC_YYYYMMDD_HHMMSS_F/R, plus MAN/MOT/PAK variants.
- Vantrue N4 - filename-only seed from private archive samples. Older Vantrue pattern: YYYY_MM_DD_HHMMSS_MODE_CHANNEL.
- Vantrue N5 - filename-only seed from private archive samples. 4-channel A/B/C/D pattern: YYYYMMDD_HHMMSS_SEQUENCE_MODE_CHANNEL.
- Vantrue E360 - filename-only seed from private archive samples. Panoramic A channel plus C channel observed.
- 70mai 4K Omni - filename-only seed from private archive samples. NO/PA/EV mode prefix with F/R channel suffix observed.

## Intake Queue

- Nextbase iQ - private archive folder did not include enough raw camera filenames for a profile.
- Vantrue N4 Pro - private archive folder only showed edited/b-roll filenames, not raw camera filenames.
- 70mai T800 - private archive folder only showed edited/b-roll filenames, not raw camera filenames.

## Support Definitions

- **Documented:** folder and mode meanings are documented.
- **Sampled:** at least one real card has been inspected.
- **Official reference:** manufacturer pages or manuals confirm the model, variant, or channel role, but no card has been inspected yet.
- **Classified:** filename timestamp, mode, and channel rules are known.
- **Validated:** rules have been checked against enough files or cards to trust automation.
- **Known unsupported:** model is listed in the app but needs a submitted card intake package before automation support.
- **Other:** user-entered model outside the prebuilt dropdown.
