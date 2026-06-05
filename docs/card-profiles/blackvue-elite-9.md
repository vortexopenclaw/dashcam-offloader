# BlackVue Elite 9

## Status

Seed profile, based on one real 2CH sample card read-only scanned at `/Volumes/BLACKVUE` and official BlackVue Elite 9 manual/firmware references.

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

Observed mode letters:

- `N` - normal or continuous recording.
- `P` - parking recording.
- `I` - impact or event recording, provisional label until more BlackVue evidence confirms exact naming.

Observed channel letters:

- `F` - front.
- `R` - rear.

Observed suffix counts:

- `NF` - 1187 files.
- `NR` - 1187 files.
- `PF` - 253 files.
- `PR` - 253 files.
- `IF` - 85 files.
- `IR` - 85 files.

## Related-File Grouping

Group related files by date, time, and mode letter. The channel letter should not be part of the grouping key.

Observed groups:

- 1525 total groups.
- 1187 complete `NF/NR` pairs.
- 253 complete `PF/PR` pairs.
- 85 complete `IF/IR` pairs.
- No incomplete front/rear pairs were observed on this sample card.

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
- Confirm the exact BlackVue mode name for `I` recordings.
