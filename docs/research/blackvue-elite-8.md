# BlackVue Elite 8 Research Notes

## Official Sources Checked

- Product page: <https://blackvuenorthamerica.com/products/blackvue-elite-8-2ch-front-rear-2k-qhd-dash-cam>
- Overview: <https://blackvue.com/elite-8-info/>
- Elite 8, 9, 10 firmware update: <https://blackvue.com/blogs/update/firmware-update-elite-8-9-10-updates-1190778>
- Retail listing: <https://www.blackboxmycar.com/products/blackvue-elite-8-2-channel-2k-hdr-cloud-dash-cam>

## Findings

- The Elite 8 is a 2CH cloud dash cam with dual Sony IMX675 STARVIS 2 sensors.
- Both front and rear record at 2K QHD (2560x1440) @ 30fps with Dual HDR.
- Codec is H.264 per manufacturer spec and third-party reviewer confirmation.
- Key distinction from the Elite 9: the Elite 9 has 4K front + 2K rear; the Elite 8 has 2K on both channels but upgrades the rear to Sony STARVIS 2 (the Elite 9 rear uses STARVIS 1).
- The firmware update page groups Elite 8, Elite 9, and Elite 10 as a related family, consistent with the shared filename structure observed on real cards.
- The WiFi SSID follows the format `BlackVueElite8-XXXXXX` where the suffix is a device-specific hex identifier.

## Real-Card Evidence

The real Elite 8 sample at `/Volumes/BlackVue` confirmed:

- Main video folder: `BlackVue/Record`.
- Filename pattern: `YYYYMMDD_HHMMSS_MODECHANNEL.mp4` — matches Elite 9 exactly.
- Observed mode letter on this card: `N` (normal) only.
- Observed channel letters: `F` and `R`.
- Complete front/rear pairing for all observed clips.
- Config folder present: `BlackVue/Config/` with `version.bin`, `micom_version.bin`, `smart_gsensor_version.bin`, `config.ini`, and `bt_ssid.bin`.
- `config.ini` is plaintext and contains `ap_ssid=BlackVueElite8-XXXXXX` — the WiFi SSID embeds the model name.
- The binary version files could not be read as text during this scan. Based on the Elite 9 pattern (where `version.bin` contains `model = ELITE 9`), they are expected to contain `model = ELITE 8`, but this is inferred and not yet verified by binary substring read.
- No `BlackVue/System` folder observed on this card.

## Detection Decision

The Elite 9 uses `version.bin`, `micom_version.bin`, and `smart_gsensor_version.bin` as high-confidence signals because they contain a plaintext model string that can be matched by binary substring read.

For the Elite 8, those same files are present on the card but their content was not confirmed during this scan. `config.ini` is used as the primary high-confidence detection signal because it is plaintext, directly readable, and unambiguously contains `ap_ssid=BlackVueElite8-`, which distinguishes the Elite 8 from the Elite 9 and other BlackVue models.

The binary version files are included as supporting signals based on the consistent Elite family pattern, pending direct verification.

## Privacy Notes

- Do not ingest or export `BlackVue/Config/config.ini` by default — it contains private settings, hashed WiFi credentials, and network-related values.
- Do not ingest or export `BlackVue/Config/bt_ssid.bin` by default.
- Do not store product serial or GPS/private fields from MP4 `cprt` metadata.
