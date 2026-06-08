# BlackVue Elite 8

## Status

Seed profile, based on one real 2CH sample card read-only scanned at `/Volumes/BlackVue` and the official BlackVue Elite 8 manual.

Use `BlackVue Elite 8` as the public app model name. Treat channel count as variant metadata behind the scenes.

## Source References

- Official manual: <https://manual.blackvue.com/docs/elite-8-series/>
- Official specs: <https://manual.blackvue.com/docs/elite-8-series/technical-specifications/product-specifications/>
- Official key features: <https://manual.blackvue.com/docs/elite-8-series/getting-started/key-features/>
- Official firmware update (Elite 8/9/10 family): <https://blackvue.com/blogs/update/firmware-update-elite-8-9-10-updates-1190778>

The Elite 8 is a 2CH cloud dash cam with dual Sony IMX675 STARVIS 2 sensors, recording both front and rear at 2K QHD (2560x1440) @ 30fps with Dual HDR. It differs from the Elite 9 (4K front + 2K rear) in that both channels share the same 2K resolution. Codec is H.264 (AVC). Video format is MP4.

## Card Layout

Real-card observed:

- `BlackVue/Record` - video recordings.
- `BlackVue/Config/version.bin` - model and firmware metadata, binary file.
- `BlackVue/Config/micom_version.bin` - model and firmware metadata, binary file.
- `BlackVue/Config/smart_gsensor_version.bin` - model and firmware metadata, binary file.
- `BlackVue/Config/config.ini` - private settings and network config, exclude by default.
- `BlackVue/Config/bt_ssid.bin` - private Bluetooth/network metadata, exclude by default.
- No `BlackVue/System` folder observed on this card.

## Filename Patterns

Visible MP4 files use:

`YYYYMMDD_HHMMSS_MODECHANNEL.mp4`

This matches the Elite 9 pattern exactly.

Observed mode letters:

- `N` - normal or continuous recording (confirmed on card).
- `P` - parking recording (expected, not observed on this card).
- `I` - impact or event recording (expected, not observed on this card).

Observed channel letters:

- `F` - front.
- `R` - rear.

All clips on this card were normal driving recordings with both front and rear channels present. Parking and event files are expected to follow the same naming convention based on Elite 9 family behavior and the official manual's description of Parking Impact and Driving Impact recording modes.

## Related-File Grouping

Group related files by date, time, and mode letter. The channel letter should not be part of the grouping key.

## Channel Variants

- 2CH - front and rear. Validated from the sampled card.

## Model Detection

**Primary detection signals:**

- `BlackVue/Config/version.bin` - contains the BlackVue model field.
- `BlackVue/Config/micom_version.bin` - contains the BlackVue model field.
- `BlackVue/Config/smart_gsensor_version.bin` - contains the BlackVue model field.

**Additional supporting signal:**

- MP4 `cprt` metadata contains model and firmware fields. Extract only safe fields; do not store private fields such as product serial, temperature, or GPS-related state.
- `BlackVue/Config/config.ini` can document settings such as recording and parking configuration, but Wi-Fi SSID fields are user-changeable and must not be used for model identification.

**Weak signal:**

- Volume label `BLACKVUE`. Useful as a hint only because users can rename volumes.

## Exclude By Default

- `.Trashes/**`
- `.fseventsd/**`
- `.Spotlight-V100/**`
- `._*`
- `BlackVue/Config/config.ini`
- `BlackVue/Config/bt_ssid.bin`
- `BlackVue/System/**`

## Open Questions

- Confirm that `version.bin`, `micom_version.bin`, and `smart_gsensor_version.bin` contain `model = ELITE 8` via binary substring read.
- Validate parking and impact/event recordings with a card that has P and I mode clips.
- Confirm bitrate via ffprobe.
