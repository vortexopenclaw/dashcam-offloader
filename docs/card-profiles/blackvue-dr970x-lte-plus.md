# BlackVue DR970X LTE Plus

Validated profile based on read-only inspection of real 2CH cards before and
after the firmware 2 update.

## Detection

Exact `model = DR970X LTE Plus` text in either of these safe model metadata
files is required for automatic selection:

- `BlackVue/Config/version.bin`
- `BlackVue/Config/micom_version.bin`

The shared BlackVue folders and volume label are not sufficient to distinguish
this camera from sibling models. User-changeable Wi-Fi and Bluetooth names are
never model evidence.

## Card And Filename Behavior

- Recordings are stored under `BlackVue/Record`.
- Filenames follow `YYYYMMDD_HHMMSS_MODECHANNEL.mp4`.
- Observed modes are normal, event, manual, and parking.
- Observed channels are Front and Rear.
- Firmware 1.x and 2.x retain the same model marker and recording layout.

## Privacy

The profile excludes the complete config and system trees from import. It does
not read or log Wi-Fi credentials, cloud configuration, Bluetooth identifiers,
or LTE modem identifiers.
