# BlackVue Elite 8 Research Notes

## Official Sources Checked

- Official manual: <https://manual.blackvue.com/docs/elite-8-series/>
- Official specs: <https://manual.blackvue.com/docs/elite-8-series/technical-specifications/product-specifications/>
- Official overview: <https://manual.blackvue.com/docs/elite-8-series/getting-started/overview/>
- Official key features: <https://manual.blackvue.com/docs/elite-8-series/getting-started/key-features/>
- Official product page: <https://blackvuenorthamerica.com/products/blackvue-elite-8-2ch-front-rear-2k-qhd-dash-cam>
- Official overview (blackvue.com): <https://blackvue.com/elite-8-info/>
- Elite 8, 9, 10 firmware update: <https://blackvue.com/blogs/update/firmware-update-elite-8-9-10-updates-1190778>
- Retail listing: <https://www.blackboxmycar.com/products/blackvue-elite-8-2-channel-2k-hdr-cloud-dash-cam>

## Findings

- The Elite 8 is a 2CH cloud dash cam with dual Sony IMX675 STARVIS 2 sensors (approx. 5MP each).
- Both front and rear record at 2K QHD (2560x1440) @ 30fps with Dual HDR.
- Video codec confirmed as H.264 (AVC) from official product specifications page.
- Video format confirmed as MP4 from official product specifications page.
- Key distinction from the Elite 9: the Elite 9 has 4K front + 2K rear; the Elite 8 has 2K on both channels but upgrades the rear to Sony STARVIS 2 (the Elite 9 rear uses STARVIS 1).
- The firmware update page groups Elite 8, Elite 9, and Elite 10 as a related family, consistent with the shared filename structure observed on real cards.
- The default Wi-Fi SSID may follow the format `BlackVueElite8-XXXXXX`, but this is user-changeable and must not be used as model evidence.
- Parking recording modes: Power Saving (<1mA), Motion detection, Time-lapse.
- Smart event recording includes: Driving Impact, Parking Impact, Overspeed, Hard Acceleration, Hard Braking, Hard Cornering (with 10-sec pre-buffer).

## Real-Card Evidence

The real Elite 8 sample at `/Volumes/BlackVue` confirmed:

- Main video folder: `BlackVue/Record`.
- Filename pattern: `YYYYMMDD_HHMMSS_MODECHANNEL.mp4` — matches Elite 9 exactly.
- Observed mode letter on this card: `N` (normal) only.
- Observed channel letters: `F` and `R`.
- Complete front/rear pairing for all observed clips.
- Config folder present: `BlackVue/Config/` with `version.bin`, `micom_version.bin`, `smart_gsensor_version.bin`, `config.ini`, and `bt_ssid.bin`.
- `config.ini` is plaintext and may contain `ap_ssid=BlackVueElite8-XXXXXX`, but this is a user-changeable Wi-Fi AP name and is not reliable model evidence.
- The BlackVue model metadata files contain `model = ELITE 8` and are the reliable card-side model evidence.
- No `BlackVue/System` folder observed on this card.

## Detection Decision

The Elite 9 uses `version.bin`, `micom_version.bin`, and `smart_gsensor_version.bin` as high-confidence signals because they contain a plaintext model string that can be matched by binary substring read.

For the Elite 8, those same files are present on the card and should be matched by exact model strings. `config.ini` can help document recording settings, but Wi-Fi SSID/AP fields inside it are user-changeable and must not be used for model identification.

The binary version files are the primary BlackVue model signals. If they identify an unsupported model, the app should show it as a New Dashcam instead of choosing the closest supported BlackVue profile.

## Privacy Notes

- Do not ingest or export `BlackVue/Config/config.ini` by default — it contains private settings, hashed WiFi credentials, and network-related values.
- Do not ingest or export `BlackVue/Config/bt_ssid.bin` by default.
- Do not store product serial or GPS/private fields from MP4 `cprt` metadata.
