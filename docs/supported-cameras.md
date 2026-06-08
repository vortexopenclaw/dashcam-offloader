# Supported Cameras

## Seeded

- Thinkware U3000 Pro - profile drafted from one real card and official documentation.
- Thinkware U3000 - profile drafted from one real card. 2-channel (F/R), no interior cabin support.
- Vueroid S1 4K Infinite - base model profile with 1CH, 2CH, and 3CH variants. One real 3CH sample card inspected.
- VIOFO A329S - base model profile. One real 3CH sample card inspected.
- VIOFO A329T - related telephoto model profile drafted from official VIOFO product references and user-provided filename evidence. No real card inspected yet.
- BlackVue Elite 9 - base model profile. One real 2CH sample card inspected.
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
- Escort M1 - profile drafted from one real card and official user manual. Single-channel front only. Distinct card layout: all footage in Escort_M1/ subfolder (not DCIM/). Filename pattern YYYY_MMDD_HHMMSS_SEQ.MOV. No parking mode.

## Intake Queue

(none)

## Support Definitions

- **Documented:** folder and mode meanings are documented.
- **Sampled:** at least one real card has been inspected.
- **Official reference:** manufacturer pages or manuals confirm the model, variant, or channel role, but no card has been inspected yet.
- **Classified:** filename timestamp, mode, and channel rules are known.
- **Validated:** rules have been checked against enough files or cards to trust automation.
- **Known unsupported:** model is listed in the app but needs a submitted card intake package before automation support.
- **Other:** user-entered model outside the prebuilt dropdown.
