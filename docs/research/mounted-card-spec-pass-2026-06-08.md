# Mounted Card Spec Pass - 2026-06-08

Read-only summary from the four mounted cards Ariel provided:

- VIOFO A229 Pro: `/Volumes/Untitled`
- Vueroid S1 4K Infinite: `/Volumes/S1-4K`
- Thinkware U3000 Pro: `/Volumes/U3000Pro`
- VIOFO A329S: `/Volumes/A329S`

The measurement pass used `scripts/analyze-mounted-card-specs.py`, which samples one representative clip per detected mode/channel, runs `ffprobe`, and extracts only safe config strings. Raw videos, raw config dumps, GPS traces, unique IDs, Wi-Fi fields, and credentials were not copied or printed.

## Summary Findings

- A229 Pro current card: 6225 parsed MP4 files. Driving and locked clips are 4K front, 1080p interior, 2K rear. Parking clips keep the same resolutions but drop to about 4 Mbps per channel.
- Vueroid S1 4K current card: 1082 parsed MP4 files. 3CH footage is 4K front, 1080p interior, 2K rear. `CONFIG/config.bin` exposes safe model/firmware strings including `S1-4K V1.04.2`.
- Thinkware U3000 Pro current card: 2237 parsed MP4 files. Driving clips are 4K30 front and 2K30 rear. Parking/event clips on this card are 15 fps. `SETTING` files expose safe model/version strings and timezone.
- A329S current card: 2927 parsed MP4 files. 3CH footage is 4K front plus 2K interior and 2K rear. Parking clips keep those resolutions but use lower bitrates. `RO` contains both normal and parking suffix families.

## Config Handling

Keep using config files for safe model/settings evidence, not as footage:

- VIOFO `format.txt` files on the A229 Pro and A329S cards are empty and only useful as exclusion signals.
- Vueroid `CONFIG/config.bin` can be string-scanned for model and firmware/build strings.
- Thinkware `SETTING/default.cfg`, `SETTING/setup.cfg`, and `SETTING/lang/ver.dat` can be string-scanned for model, firmware/config version, language pack, and timezone.
- Thinkware `device.uid` must remain excluded from model detection and documentation.

## Repeat Command

```bash
python3 scripts/analyze-mounted-card-specs.py --max-samples-per-group 1
```
