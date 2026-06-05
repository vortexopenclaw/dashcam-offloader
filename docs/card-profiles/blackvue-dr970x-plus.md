# BlackVue DR970X Plus Card Profile

**Camera Model:** BlackVue DR970X Plus  
**Channels:** 2 (Front, Rear)  
**Profile Date:** 2026-06-05  
**Evidence Source:** Real SD card at `/Volumes/BLACKVUE`  
**Firmware Version:** v2.008 (rev1568)  

## Model Detection

**Highest-confidence evidence:**
- `BlackVue/Config/version.bin` contains `model = DR970X Plus`
- `BlackVue/Config/micom_version.bin` contains `model = DR970X Plus v2.008(rev1568)`

**Do not use for identification:**
- `bt_ssid.bin` - Bluetooth SSID (user-configurable)
- AP SSID in config.ini - WiFi hotspot name (user-configurable)
- WiFi passwords, Cloud credentials - privacy-sensitive, user-configurable
- Volume label - user-renamable

## Folder Structure

| Folder | Mode | Description |
|--------|------|-------------|
| `BlackVue/Record/` | All modes | All video recordings (normal, event, parking) |
| `BlackVue/Config/` | - | Configuration files |
| `BlackVue/System/` | - | System files (empty on sample card) |

**Note:** BlackVue uses a single `Record/` folder for all recording modes, distinguished by filename mode codes rather than separate folders.

## Filename Pattern

**Format:** `YYYYMMDD_HHMMSS_MODE_CH.mp4`

**Examples:**
- `20260429_134137_PF.mp4` - Parking mode, front channel
- `20260429_134137_PR.mp4` - Parking mode, rear channel
- `20260318_120219_IF.mp4` - Impact/event, front channel
- `20260318_120219_IR.mp4` - Impact/event, rear channel
- `20260318_171835_NF.mp4` - Normal driving, front channel
- `20260318_171835_NR.mp4` - Normal driving, rear channel
- `20260318_173938_PF.mp4` - Parking mode, front channel
- `20260429_111513_EF.mp4` - Event, front channel

**Pattern breakdown:**
- `YYYYMMDD` - Date (e.g., `20260429` = April 29, 2026)
- `HHMMSS` - Time (24-hour format)
- `MODE` - Recording mode:
  - `N` = Normal driving (continuous loop)
  - `E` or `I` = Event/Impact (G-sensor triggered)
  - `P` = Parking mode (motion/impact while parked)
- `CH` - Channel:
  - `F` = Front (primary, highest bitrate)
  - `R` = Rear (secondary, lower bitrate)

**Note:** Both `E` and `I` prefixes observed for event recordings. May indicate different event types (manual vs G-sensor).

## Channel Mapping

| Channel | Position | Relative Bitrate | Example File Size (1-min) |
|---------|----------|------------------|---------------------------|
| F | Front | Highest | ~465 MB |
| R | Rear | Lower | ~83 MB |

**Bitrate ratio:** Front is approximately 5.6× higher than rear.

**Note:** Both channels record simultaneously for each timestamp. Front channel uses significantly higher bitrate for better license plate capture.

## Configuration Files

**Location:** `BlackVue/Config/`

| File | Purpose | Contains Model Info |
|------|---------|---------------------|
| `version.bin` | Firmware version | Yes - `model = DR970X Plus` |
| `micom_version.bin` | MICOM (microcontroller) version | Yes - `model = DR970X Plus` |
| `config.ini` | Camera settings | No (user-configurable) |
| `bt_ssid.bin` | Bluetooth SSID | No (user-configurable, privacy) |

**Privacy-sensitive files (exclude from offload/analysis):**
- `config.ini` - Contains WiFi passwords, cloud credentials, SSIDs
- `bt_ssid.bin` - Bluetooth pairing identifier

## Firmware Information

**Observed firmware:** v2.008 (rev1568)  
**MICOM version:** v2.01  

Firmware updates are typically applied via BlackVue Windows/Mac software or mobile app, not manual SD card files.

## Recording Modes

**Normal (N):**
- Continuous loop recording
- Overwrites oldest files when card is full
- Both channels record simultaneously

**Event (E/I):**
- Triggered by G-sensor impact or manual button press
- Files are protected from overwrite
- Separate event section in BlackVue viewer apps

**Parking (P):**
- Activated when camera detects vehicle is parked (hardwire kit required)
- Motion detection and/or impact monitoring
- Lower framerate/bitrate to conserve storage
- Both channels record when triggered

## System Files (Exclude from Offload)

- `BlackVue/Config/**` - All configuration files (privacy-sensitive)
- `BlackVue/System/**` - System cache/data
- `.Spotlight-V100/` - macOS Spotlight index
- `.fseventsd/` - macOS file system events
- `._*` - macOS resource fork files

## Detection Rules

**Model Detection:**
- Folder structure: `BlackVue/Record/`, `BlackVue/Config/`
- `BlackVue/Config/version.bin` contains `model = DR970X Plus`
- Filename pattern: `^\d{8}_\d{6}_[NEIP][FR]\.mp4$`

**Channel Detection:**
- 2CH variant: Both `F` and `R` channel files present
- 1CH variant (if exists): Only `F` channel files (not observed on this sample)

**Exclusions:**
- All files in `BlackVue/Config/` (privacy-sensitive)
- macOS metadata: `._*`, `.Spotlight-V100/`, `.fseventsd/`

## Comparison to Other BlackVue Models

The DR970X Plus is a premium 2-channel model with:
- 4K front sensor, 1080p rear
- Built-in WiFi and Bluetooth
- Cloud connectivity (LTE via optional module)
- Parking mode with hardwire kit

Other BlackVue models may use similar folder structures but differ in:
- Channel count (1CH, 2CH, or 3CH with interior)
- Model identifier in `version.bin`
- Firmware version numbering

## Open Questions

- What distinguishes `E` vs `I` event prefixes? (manual button vs G-sensor?)
- Does DR970X Plus have a 1CH-only variant?
- Are there additional mode codes beyond N, E, I, P?

## Profile Schema Version

This profile conforms to the dashcam-offloader profile schema v1.0.