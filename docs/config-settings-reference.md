# Config And Settings Reference

Internal notes for reading camera settings safely during profile research and sanitized feedback/card-learning submissions.

Do not copy or publish raw config dumps. Read only small known files, extract safe non-unique strings or fields, and drop Wi-Fi, password, SSID, serial, device ID, MAC, token, account, GPS, coordinate, license plate, and similar private values.

## Current Mounted Cards

### VIOFO A229 Pro

- Mounted card: `/Volumes/Untitled`
- Config-like files seen: `format.txt`
- Safe signal: `format.txt` is an empty 0-byte file.
- Use: exclusion signal only. It does not provide model, firmware, resolution, bitrate, or channel settings.

### Vueroid S1 4K Infinite

- Mounted card: `/Volumes/S1-4K`
- Config-like file: `CONFIG/config.bin`
- Safe strings observed:
  - `S1-4K V1.04.2`
  - `Mar  3 2026, 16:43:29`
  - `S1-4K`
- Use: strong model and firmware/build evidence when safely string-scanned.
- Do not copy `CONFIG/**` with normal footage. Include only redacted summaries in feedback/training payloads.

### Thinkware U3000 Pro

- Mounted card: `/Volumes/U3000Pro`
- Config-like files:
  - `SETTING/default.cfg`
  - `SETTING/setup.cfg`
  - `SETTING/lang/ver.dat`
  - `SETTING/TW_SERVER_INFO.txt`
  - `SETTING/U3000PRO_Setting.exe`
- Safe strings observed:
  - `SETTING/default.cfg`: `U3000PRO`, `SETTING\U3000PRO_Setting.exe`, timezone string
  - `SETTING/setup.cfg`: `U3000PRO`, `v1.00.04`, `SETTING\U3000PRO_Setting.exe`, `v62`, timezone string
  - `SETTING/lang/ver.dat`: `Device Name:U3000PRO`, language pack version/name, supported language list
  - `SETTING/TW_SERVER_INFO.txt`: Thinkware service hostnames and ports
- Use: high-confidence model evidence plus firmware/config version and timezone setting.
- Do not read `device.uid` for model detection or publish it.

### VIOFO A329S

- Mounted card: `/Volumes/A329S`
- Config-like files seen: `format.txt`
- Safe signal: `format.txt` is an empty 0-byte file.
- Use: exclusion signal only. Model detection should prefer folder/filename structure, OSD where available, and model-specific firmware file references such as `DCIM/FWA329S.bin` when present.

## Extraction Pattern

For profile research:

1. Enumerate only known small config/support files.
2. Skip unique identifiers and OS sidecars.
3. Run a printable string pass on binary config files.
4. Filter sensitive keys and values before recording any findings.
5. Store only safe summaries such as model string, firmware version, language pack version, timezone, resolution/bitrate mode, channel setup, codec mode, parking mode, audio on/off, and HDR/WDR state.

For app feedback/card-learning:

- Include redacted setting summaries only.
- Never include raw config dumps, video files, GPS traces, device IDs, Wi-Fi credentials, serial numbers, or account identifiers.
