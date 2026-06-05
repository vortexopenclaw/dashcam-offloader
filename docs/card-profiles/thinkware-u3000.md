# Thinkware U3000 Card Profile

**Camera Model:** Thinkware U3000 (non-Pro)  
**Channels:** 2 (Front, Rear)  
**Profile Date:** 2026-06-05  
**Evidence Source:** Real SD card at `/Volumes/U3000`  

## Model Detection

**Highest-confidence evidence:**
- `SETTING/lang/ver.dat` contains `Device Name:U3000`
- `SETTING/setup.cfg` references `U3000` and `SETTING\U3000_Setting.exe`
- Firmware folder: `u3000_0_1.02.03/` containing `U3000_boot.bin` and `U3000_pkg.bin`

**Weak evidence:**
- Volume label was `U3000`, but volume labels are user-renamable

**Do not use:**
- `device.uid` for model identification (unique device identifier)
- `DCIM/FWA329S.bin` - firmware update file, not reliable for model detection

## Folder Structure

| Folder | Mode | Prefix | Description |
|--------|------|--------|-------------|
| `cont_rec/` | Continuous | `REC` | Normal driving recording |
| `evt_rec/` | Driving Event | `EVT` | Impact or emergency event recording |
| `motion_timelapse_rec/` | Parking Motion/Timelapse | `MOT` | Parking mode motion or time-lapse |
| `parking_rec/` | Parking Event | `PAK` | Parking incident recording |
| `manual_rec/` | Manual | unknown | Manual recording (folder exists, may be empty) |
| `sos_rec/` | SOS | unknown | SOS recording (folder exists, may be empty) |

**Note:** The U3000 (non-Pro) does **not** have an `incabin_rec` folder. This distinguishes it from the U3000 Pro which supports an interior IR camera.

## Filename Patterns

**Format:** `PREFIX_YYYYMMDD_HHMMSS_CH.MP4`

**Examples:**
- `REC_20250929_143201_F.MP4` - Continuous driving, front channel
- `REC_20250929_143201_R.MP4` - Continuous driving, rear channel
- `PAK_20250929_143805_F.MP4` - Parking event, front channel
- `PAK_20250929_143805_R.MP4` - Parking event, rear channel
- `MOT_20250929_144643_F.MP4` - Parking motion, front channel
- `MOT_20250929_144643_R.MP4` - Parking motion, rear channel

**Pattern breakdown:**
- `PREFIX` - Recording mode:
  - `REC` = Continuous driving
  - `EVT` = Driving event/impact
  - `MOT` = Parking motion or time-lapse
  - `PAK` = Parking incident
- `YYYYMMDD` - Date
- `HHMMSS` - Time (24-hour format)
- `CH` - Channel:
  - `F` = Front (higher bitrate, ~258 MB per file observed)
  - `R` = Rear (lower bitrate, ~107 MB per file observed)

## Channel Mapping

| Channel | Position | Relative Bitrate | Example File Size |
|---------|----------|------------------|-------------------|
| F | Front | Higher | ~258 MB per clip |
| R | Rear | Lower | ~107 MB per clip |

**Note:** Both channels record simultaneously for each timestamp. Front channel has significantly higher bitrate than rear.

## Configuration Files

**Location:** `SETTING/`

| File | Purpose |
|------|---------|
| `setup.cfg` | Binary config with model info (`U3000_Setting.exe` reference) |
| `default.cfg` | Default configuration |
| `lang/ver.dat` | Language pack version, contains `Device Name:U3000` |
| `TW_SERVER_INFO.txt` | Thinkware server connection info |

## Firmware Files

**Location:** `u3000_0_1.02.03/` (firmware version folder)

| File | Purpose |
|------|---------|
| `U3000_boot.bin` | Bootloader firmware |
| `U3000_pkg.bin` | Main firmware package |

**Note:** The firmware folder name includes the version number (e.g., `u3000_0_1.02.03`). This can be used as secondary model detection.

## System Files (Exclude from Offload)

- `device.uid` - Unique device identifier (privacy-sensitive)
- `SETTING/**` - Configuration files
- `THUMBNAIL/**` - Thumbnail cache
- `driveinfo/**` - Drive information
- `.TWSYS/` - Thinkware system folder
- `.Spotlight-V100/` - macOS Spotlight index
- `.fseventsd/` - macOS file system events
- `._*` - macOS resource fork files

## Comparison: U3000 vs U3000 Pro

| Feature | U3000 | U3000 Pro |
|---------|-------|-----------|
| Channels | 2 (F/R) | 3 (F/R + Interior) |
| In-cabin folder | No | Yes (`incabin_rec/`) |
| Firmware path | `u3000_0_<ver>/` | `U3000PRO_Setting.exe` in `SETTING/` |
| ver.dat device name | `U3000` | `U3000PRO` |

## Detection Rules

**Model Detection:**
- Folder structure matches Thinkware pattern
- `SETTING/lang/ver.dat` contains `Device Name:U3000` (not `U3000PRO`)
- No `incabin_rec` folder present
- Firmware in `u3000_0_<ver>/` format

**Exclusions:**
- macOS resource forks: `._*`
- System folders: `.TWSYS/`, `.Spotlight-V100/`, `.fseventsd/`
- Config/thumbnail folders: `SETTING/`, `THUMBNAIL/`, `driveinfo/`
- Privacy files: `device.uid`

## Open Questions

- Filename pattern for manual recordings (folder exists but was empty on sample)
- Filename pattern for SOS recordings (folder exists but was empty on sample)
- Whether any protected/event-lock status is represented by filesystem flags

## Profile Schema Version

This profile conforms to the dashcam-offloader profile schema v1.0.