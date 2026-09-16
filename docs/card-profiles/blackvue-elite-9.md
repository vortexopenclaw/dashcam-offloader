# BlackVue Elite 9

## Status

Validated profile based on one directly sampled 2CH card, one privacy-sanitized 2CH app submission, and official BlackVue Elite 9 manual/firmware references. The newest scan used firmware 1.010 with parking configured for motion and impact detection only.

Use `BlackVue Elite 9` as the public app model name. Treat channel count as variant metadata behind the scenes.

## Source References

- Official manual: <https://manual.blackvue.com/docs/elite-9-series/>
- Official overview: <https://manual.blackvue.com/docs/elite-9-series/getting-started/overview-6/>
- Official key features: <https://manual.blackvue.com/docs/elite-9-series/getting-started/key-features-6/>
- Official Elite 8, 9, 10 firmware update: <https://blackvue.com/blogs/update/firmware-update-elite-8-9-10-updates-1190778>

The official manual describes the Elite 9 as a 2CH BlackVue dash cam with front 4K UHD and rear 2K QHD cameras. BlackVue's firmware update page groups Elite 8, Elite 9, and Elite 10 as related models, but shared filename structure should still be validated with real cards.

## Card Layout

Real-card observed:

- `BlackVue/Record` - video recordings. 3050 visible MP4 files.
- `BlackVue/Config/version.bin` - model and firmware metadata, safe non-unique model signal.
- `BlackVue/Config/micom_version.bin` - model and firmware metadata, safe non-unique model signal.
- `BlackVue/Config/smart_gsensor_version.bin` - model and firmware metadata, safe non-unique model signal.
- `BlackVue/Config/config.ini` - private settings and network config, exclude by default.
- `BlackVue/Config/bt_ssid.bin` - private Bluetooth/network metadata, exclude by default.
- `BlackVue/System` - present on the sample card, no visible files found during this pass.

## Filename Patterns

Visible MP4 files use:

`YYYYMMDD_HHMMSS_MODECHANNEL.mp4`

Examples:

- `BlackVue/Record/20260505_090047_NF.mp4`
- `BlackVue/Record/20260505_090047_NR.mp4`
- `BlackVue/Record/20260604_143519_PF.mp4`
- `BlackVue/Record/20260604_143519_PR.mp4`
- `BlackVue/Record/20260604_144033_IF.mp4`
- `BlackVue/Record/20260604_144033_IR.mp4`

Observed and user-confirmed mode letters:

- `N` - normal or continuous recording.
- `P` - parking motion detection. The firmware 1.010 submission confirms `20260913_185449_PF.mp4` is motion-triggered footage, not time-lapse.
- `I` - parking impact detection while the camera is parked; `IF` is the front-camera variant and `IR` is the paired rear-camera variant.

BlackVue also uses the same `P` filename code for time-lapse parking files. The
filename therefore cannot distinguish the two modes by itself. Resolve `P`
clips from the allowlisted `EV_PARKING_MODE` value in `config.ini`: observed
value `0` is motion detection, while value `1` selects the camera's time-lapse
parking option. If that safe setting is unavailable or unknown, keep the label
as **Parking Motion Or Timelapse** rather than guessing from filename cadence or
file size. `I` remains parking impact in either parking mode.

Observed channel letters:

- `F` - front.
- `R` - rear.

Observed suffix counts:

- `NF` - 538 files.
- `NR` - 538 files.
- `PF` - 531 files.
- `PR` - 531 files.
- `IF` - 456 files.
- `IR` - 456 files.

## Related-File Grouping

Group related files by date, time, and mode letter. The channel letter should not be part of the grouping key.

Observed groups:

- 1525 total groups.
- 538 complete `NF/NR` pairs.
- 531 complete `PF/PR` pairs.
- 456 complete `IF/IR` pairs.
- No incomplete front/rear pairs were observed on this sample card.

## Timestamps

Use the `YYYYMMDD_HHMMSS` filename timestamp as the recording time. On the firmware 1.010 card, Finder showed filesystem modification times seven hours earlier than the camera-local filename time. This is consistent with BlackVue writing filesystem timestamps on a UTC basis while the filename carries the configured camera clock. The app should display the filename time and apply it to downloaded-file modification metadata rather than propagating the misleading card-filesystem value.

## Channel Variants

- 2CH - front and rear. Validated from the sampled card.

## Model Detection

Best observed non-unique model signals:

- `BlackVue/Config/version.bin` contains `model = ELITE 9`.
- `BlackVue/Config/micom_version.bin` contains `model = ELITE 9 v1.008(rev650)`.
- `BlackVue/Config/smart_gsensor_version.bin` contains `model = ELITE 9 v1.008(rev650)`.

Supporting signal:

- MP4 `cprt` metadata contains model and firmware fields. It also contains private fields such as product serial, temperature, and GPS-related state, so an importer must extract only safe fields and ignore or redact the rest.

Weak signal:

- Volume label `BLACKVUE`. This is useful as a hint only because users can rename volumes.

## Exclude By Default

- `.Trashes/**`
- `.fseventsd/**`
- `.Spotlight-V100/**`
- `._*`
- `BlackVue/Config/config.ini`
- `BlackVue/Config/bt_ssid.bin`
- `BlackVue/System/**`

## Open Questions

- Validate Elite 8 with a real card and compare filename structure and model metadata.
- Validate Elite 10 when a card or reliable sample becomes available.
- Validate how the same `I` suffix is represented when an impact happens during normal driving.
