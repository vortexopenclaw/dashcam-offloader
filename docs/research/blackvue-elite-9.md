# BlackVue Elite 9 Research Notes

## Official Sources Checked

- Manual: <https://manual.blackvue.com/docs/elite-9-series/>
- Overview: <https://manual.blackvue.com/docs/elite-9-series/getting-started/overview-6/>
- Key features: <https://manual.blackvue.com/docs/elite-9-series/getting-started/key-features-6/>
- Elite 8, 9, 10 firmware update: <https://blackvue.com/blogs/update/firmware-update-elite-8-9-10-updates-1190778>
- Parking-mode behavior: <https://media.blackvue.com/blackvue-dashcam-parking-mode/>

## Findings

- The official manual identifies the Elite 9 Series as a BlackVue 2CH dash cam.
- The official overview describes front 4K UHD and rear 2K QHD cameras powered by Sony STARVIS 2 sensors.
- The official key features page describes the Elite 9 as a 4K plus 2K cloud dash cam with Smart Parking Mode and event recording support.
- The official firmware update page groups Elite 8, Elite 9, and Elite 10 as related models. That supports a shared-family hypothesis, but real cards should still validate filename and metadata behavior for each model.

## Real-Card Evidence

The real Elite 9 sample at `/Volumes/BLACKVUE` confirmed:

- Main video folder: `BlackVue/Record`.
- Filename pattern: `YYYYMMDD_HHMMSS_MODECHANNEL.mp4`.
- Observed mode letters: `N`, `P`, and `I`.
- Observed channel letters: `F` and `R`.
- Complete front/rear pairing for all observed groups.
- Model metadata in `BlackVue/Config/version.bin`, `micom_version.bin`, and `smart_gsensor_version.bin`.

MP4 metadata also includes a `cprt` block with model and firmware fields, but that block includes private fields too. Use it only with field-level extraction and redaction.

BlackVue's current filename reference defines `P` as either parking motion or
parking time-lapse. The firmware 1.010 card's current `EV_PARKING_MODE=0`
setting agrees with user-confirmed motion clip `20260913_185449_PF.mp4`, but the
same card can retain older clips recorded under another parking-mode setting.
Do not apply the current setting card-wide.

The privacy-safe submission aggregates show that motion and time-lapse overlap
at 3840x2160/30 fps and roughly 60 Mbps front, and 2560x1440/30 fps and roughly
25 Mbps rear. File sizes and durations overlap too. BlackVue documents two
stronger per-clip signals: time-lapse `P` files are silent, and a one-minute
playback file covers about 30 minutes of real time. Use audio presence plus the
ratio between encoded duration and adjacent filename timestamps; preserve an
ambiguous label when those signals are insufficient.

## Privacy Notes

- Do not ingest or export `BlackVue/Config/config.ini` by default because it contains private settings and network-related values.
- Do not ingest or export `BlackVue/Config/bt_ssid.bin` by default.
- Do not store product serial or GPS/private fields from MP4 metadata.
