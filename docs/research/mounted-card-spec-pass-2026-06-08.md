# Mounted Card Spec Pass - 2026-06-08

Read-only summary from the four mounted cards Ariel provided:

- VIOFO A229 Pro: `/Volumes/Untitled`
- Vueroid S1 4K Infinite: `/Volumes/S1-4K`
- Thinkware U3000 Pro: `/Volumes/U3000Pro`
- VIOFO A329S: `/Volumes/A329S`
- BlackVue Elite 9: `/Volumes/BLACKVUE`
- Escort MAXcam 360c: `/Volumes/NO NAME`
- BlackVue DR970X LTE Plus firmware 2.007 sample: `/Volumes/BLACKVUE`

The measurement pass used `scripts/analyze-mounted-card-specs.py`, which samples one representative clip per detected mode/channel, runs `ffprobe`, and extracts only safe config strings. Raw videos, raw config dumps, GPS traces, unique IDs, Wi-Fi fields, and credentials were not copied or printed.

## Summary Findings

- A229 Pro current card: 6225 parsed MP4 files. Driving and locked clips are 4K front, 1080p interior, 2K rear. Parking clips keep the same resolutions but drop to about 4 Mbps per channel.
- Vueroid S1 4K current card: 1082 parsed MP4 files. 3CH footage is 4K front, 1080p interior, 2K rear. `CONFIG/config.bin` exposes safe model/firmware strings including `S1-4K V1.04.2`.
- Thinkware U3000 Pro current card: 2237 parsed MP4 files. Driving clips are 4K30 front and 2K30 rear. Parking/event clips on this card are 15 fps. `SETTING` files expose safe model/version strings and timezone.
- A329S current card: 2927 parsed MP4 files. 3CH footage is 4K front plus 2K interior and 2K rear. Parking clips keep those resolutions but use lower bitrates. `RO` contains both normal and parking suffix families.
- BlackVue Elite 9 current card: 3050 parsed MP4 files. 2CH footage is HEVC 4K30 front and 2K30 rear across driving, parking, and impact/event modes. Safe model/firmware strings appear in `version.bin`, `micom_version.bin`, and `smart_gsensor_version.bin`.
- BlackVue DR970X LTE Plus firmware 2.007 card: 10 parsed MP4 files. 2CH footage is HEVC 4K30 front and 1080p30 rear across driving and parking samples. Front measured about 60.9-62.1 Mbps; rear measured about 10.9-11.6 Mbps. `ffprobe` did not expose HDR10-style color metadata tags despite the firmware/HDR update.
- Escort MAXcam 360c current card: 66 parsed MOV files. Single-channel driving and locked/event clips are H.264 2560x1440 30 fps at about 28.5 Mbps. `Normal/MAXcam360c` and `Event/MAXcam360c` are the reliable structural model signals.

## Config Handling

Keep using config files for safe model/settings evidence, not as footage:

- VIOFO `format.txt` files on the A229 Pro and A329S cards are empty and only useful as exclusion signals.
- Vueroid `CONFIG/config.bin` can be string-scanned for model and firmware/build strings.
- Thinkware `SETTING/default.cfg`, `SETTING/setup.cfg`, and `SETTING/lang/ver.dat` can be string-scanned for model, firmware/config version, language pack, and timezone.
- Thinkware `device.uid` must remain excluded from model detection and documentation.
- BlackVue Elite 9 `BlackVue/Config/version.bin`, `micom_version.bin`, and `smart_gsensor_version.bin` can be string-scanned for safe model and firmware evidence. Keep `config.ini`, Bluetooth/network files, product serials, and MP4 GPS/private fields excluded or field-redacted.
- BlackVue DR970X LTE Plus firmware 2.007 has `version.bin` and `micom_version.bin` with exact `DR970X LTE Plus` model strings. `modem_revision.bin` is not safe public evidence because LTE modem metadata can expose modem identifiers. `config.ini` is useful only after filtering for non-sensitive recording settings such as codec, quality, parking mode, and sensor levels.
- Escort MAXcam 360c has no confirmed default config/settings file for safe model extraction. `MasterVersionInfo_SW_v1.13_HW_v1.01.bin` was manually copied to the sampled card as a firmware update file, is not expected by default, and must not be used for make/model detection. Do not read or publish `DATA/serial_num.txt`; `DATA/gps_userdb.bin` is a radar GPS lockout database and should stay excluded from normal footage handling.

## Repeat Command

```bash
python3 scripts/analyze-mounted-card-specs.py --max-samples-per-group 1
```
