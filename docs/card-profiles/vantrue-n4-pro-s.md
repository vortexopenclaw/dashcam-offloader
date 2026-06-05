# Vantrue N4 Pro S Card Profile

**Camera Model:** Vantrue N4 Pro S  
**Channels:** 3 (Front, Interior, Rear)  
**Profile Date:** 2026-06-05  
**Evidence Source:** Real SD card at `/Volumes/N4 Pro S`  

## Folder Structure

| Folder | Mode | Description |
|--------|------|-------------|
| `Normal/` | N | Continuous driving recording |
| `Event/` | E | Impact or emergency event recording |
| `Parking/` | P | Parking mode (motion or time-lapse) |
| `Photo/` | P | Photo snapshots (JPG format) |
| `GPS/` | - | GPS trajectory logs (CSV format, one per day) |

## Filename Pattern

**Format:** `YYYYMMDD_HHMMSS_SEQ_MODE_CH.EXT`

**Example:** `20251211_184930_01110_N_A.MP4`

**Breakdown:**
- `YYYYMMDD` - Date (e.g., `20251211` = December 11, 2025)
- `HHMMSS` - Time (e.g., `184930` = 18:49:30 / 6:49:30 PM)
- `SEQ` - Sequence number (5 digits, e.g., `01110`)
- `MODE` - Recording mode:
  - `N` = Normal driving (continuous)
  - `E` = Event (impact/emergency)
  - `P` = Parking mode
- `CH` - Channel identifier:
  - `A` = Front channel (primary, highest bitrate)
  - `B` = Interior channel (medium bitrate)
  - `C` = Rear channel (medium bitrate)
- `EXT` - File extension (`.MP4` for video, `.JPG` for photos)

**macOS Resource Fork Files:**  
Files prefixed with `._` (e.g., `._20251211_184930_01110_N_A.MP4`) are macOS metadata/resource forks and should be excluded from offload operations.

## Channel Mapping

Based on file size analysis of matching clips:

| Channel | Position | Relative Bitrate | Notes |
|---------|----------|------------------|-------|
| A | Front | Highest (~243 MB example) | Primary forward view |
| B | Interior | Medium (~77 MB example) | Cabin/interior view |
| C | Rear | Medium (~111 MB example) | Rear window view |

**Note:** Channel assignment (A/B/C) is consistent across all folders. All three channels record simultaneously for each timestamp/sequence.

## GPS Log Format

**Location:** `GPS/YYYYMMDD.dat`  
**Format:** CSV with `\r\n` line endings  
**Fields per line:**
```
YYYYMMDDHHMMSS,LAT,N/LON,W,altitude,speed
```

**Example:**
```
#
20250101000000,0.000000,N,0.000000,E,0.000,0.000
20250101000001,0.000000,N,0.000000,E,0.000,0.000
```

- Field 1: Timestamp (YYYYMMDDHHMMSS)
- Field 2-3: Latitude + N/S hemisphere
- Field 4-5: Longitude + E/W hemisphere
- Field 6: Altitude (meters)
- Field 7: Speed (likely km/h or m/s - needs verification)

## Recording Behavior

**Normal Mode:**
- Continuous loop recording
- Files are approximately 1 minute each (based on sequence increments)
- All 3 channels record simultaneously
- Example file count observed: 1,523 normal clips

**Event Mode:**
- Triggered by G-sensor impact or manual button press
- Locks footage to prevent overwrite
- All 3 channels saved for each event
- Example file count observed: 195 event clips

**Parking Mode:**
- Activated when camera detects vehicle is parked
- May be motion-triggered or time-lapse
- All 3 channels saved (though some clips may only have channel A based on motion)
- Example file count observed: 4,044 parking clips

**Photos:**
- Manual snapshot or parking snapshot feature
- All 3 channels captured simultaneously
- Stored as JPG files
- Naming follows same pattern as video

## Detection Rules

**Model Detection:**
- Folder structure: `Normal/`, `Event/`, `Parking/`, `Photo/`, `GPS/`
- Filename pattern: `^\d{8}_\d{6}_\d{5}_[NEP]_[ABC]\.(MP4|JPG)$`
- GPS files: `GPS/*.dat` with CSV format starting with `#` header

**Exclusions:**
- macOS resource forks: `._*`
- System folders: `.Spotlight-V100/`, `.fseventsd/`

## Comparison to Other Vantrue Models

The N4 Pro S follows Vantrue's standard folder naming convention (similar to N4 Pro), with the key difference being the 3-channel configuration (A/B/C) versus 2-channel models (A/B for front/rear or front/interior).

## Profile Schema Version

This profile conforms to the dashcam-offloader profile schema v1.0.