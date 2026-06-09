# BlackVue DR770X Box

Seed profile based on a remote Learn Card submission. No raw video was uploaded or inspected.

## Evidence

- Remote feedback key: `feedback/2026-06-09/33413829-0ada-445d-91a0-91238dffbcaf.json`
- Volume label: `BLACKVUE`
- Root folder: `BlackVue`
- Footage folder: `BlackVue/Record`
- Settings/model folder: `BlackVue/Config`
- Exact model evidence:
  - `BlackVue/Config/version.bin`
  - `BlackVue/Config/micom_version.bin`

The scanner initially scored nearby BlackVue sibling profiles from shared folder and filename evidence. The remote Learn Card scan then identified the unsupported model from exact BlackVue metadata as `DR770X Box`, so this seeded profile keys on that exact model string.

## Observed Remote Samples

- `BlackVue/Record/19991231_170101_NF.mp4`
- `BlackVue/Record/19991231_170201_NF.mp4`
- `BlackVue/Record/19991231_170301_NF.mp4`
- `BlackVue/Record/19991231_170401_NF.mp4`

Observed suffixes:

- `N` = normal / driving
- `F` = front

The profile also accepts the shared BlackVue Box-family `R` rear suffix and `E`, `M`, and `P` mode tokens, but those were not present in this remote submission and need future evidence.

## Safe Settings Seen

The remote scan included a sanitized `config.ini` setting summary with keys such as:

- `VideoQuality`
- `AutoParking`
- `RearParkingMode`
- `OptionRearParkingMode`
- `LockEvent`
- `PARKINGSENSOR1`
- `PARKINGSENSOR2`
- `PARKINGSENSOR3`
- `MOTIONSENSOR`
- `TimeZone`
- `GpsSync`
- `UseGpsInfo`

The app and maintainer tooling must keep private config fields excluded, including Wi-Fi/AP fields, Bluetooth identifiers, serial-like values, cloud credentials, and raw full config files.

## Limitations

- Media resolution, codec, frame rate, and bitrate are unmeasured because remote Learn Card submissions do not upload video bytes.
- The submitted card only contained four front driving clips.
- Rear/interior/channel variants need additional remote submissions or local/NAS samples.
