# Vantrue N4 S Card Profile (REVISED)

**Camera Model:** Vantrue N4 S (user-provided volume label)  
**Hardware Capability:** 3-channel recording (Front, Interior, Rear)  
**Profile Date:** 2026-06-05  
**Evidence Source:** Real SD card at `/Volumes/N4 S`  
**Confidence Level:** MEDIUM - identified by folder/filename pattern matching; no explicit model metadata file found

## ⚠️ Critical Identification Limitations

**User-configurable settings (CANNOT be used for model identification):**
- Recording resolutions (users can change 4K → 2.5K → 1080P)
- Bitrate settings (users can adjust quality per channel)
- Channel enablement (users can switch 1CH/2CH/3CH modes)
- File sizes (depend on resolution/bitrate settings, not just hardware)

**Firmware files (NOT reliable for identification):**
- `.bin` files in root directory (e.g., `VT-N4S.bin`, `VT-RC09.bin`, `VT-RC18.bin`)
- These are manually added for firmware updates and won't be present by default
- macOS resource fork files (`._*.bin`) are metadata only

**What this means:**
- A card showing balanced ~110 MB/min files could be:
  - N4 S at 2.5K/2.5K/2.5K (native), OR
  - N4 Pro S configured to 2.5K on all channels, OR
  - Any 3CH Vantrue model with matching resolution settings
- File size patterns suggest uniform resolution, but this is a **setting**, not a hardware identifier
- Firmware filenames may hint at model but are **not present by default**

## Model Detection (Reliable Methods Only)

**Highest-confidence evidence (NOT present on this card):**
- Explicit model metadata file (e.g., `SETTING/lang/ver.dat` on Thinkware, `BlackVue/Config/version.bin`)
- Firmware filenames containing model (e.g., `N4PRO_*.bin`, `U3000_boot.bin`)

**Medium-confidence evidence (present on this card):**
- Folder structure: `Normal/`, `Event/`, `Parking/`, `Photo/`, `GPS/` → Vantrue N4 series pattern
- Filename pattern: `YYYYMMDD_HHMMSS_SEQ_MODE_CH.MP4` with sequence number → N4 series signature
- 3 channels observed (A/B/C) → Camera was operating in 3CH mode

**Low-confidence evidence (supporting only):**
- Volume label "N4 S" → User-renamable, not reliable
- Balanced file sizes → User-configurable resolution setting

**Working identification:**
- Labeled as "N4 S" based on **user-provided volume label** and folder/filename pattern matching
- Cannot definitively distinguish from N4 Pro S without explicit model metadata file
- Both models share identical folder structure and filename patterns

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

**Example:** `20251227_142226_00349_N_A.MP4`

**Breakdown:**
- `YYYYMMDD` - Date (e.g., `20251227` = December 27, 2025)
- `HHMMSS` - Time (24-hour format)
- `SEQ` - Sequence number (5 digits, e.g., `00349`) ← **Key Vantrue N4 series signature**
- `MODE` - Recording mode:
  - `N` = Normal driving (continuous)
  - `E` = Event (impact/emergency)
  - `P` = Parking mode
- `CH` - Channel identifier:
  - `A` = Front channel (always active when recording)
  - `B` = Interior channel (user-enableable)
  - `C` = Rear channel (user-enableable)
- `EXT` - File extension (`.MP4` for video, `.JPG` for photos)

**macOS Resource Fork Files:**  
Files prefixed with `._` are macOS metadata and should be excluded.

## Channel Configuration (User-Selectable)

The N4 S supports user selection of recording modes via camera settings:

- **3CH mode (observed on this card):** Front + Interior + Rear all active
- **2CH mode:** Front + Interior OR Front + Rear
- **1CH mode:** Front only (front channel always active; interior/rear disabled)

**Observed on sample card (3CH mode):**
- Channel A files: ~109 MB/min
- Channel B files: ~109 MB/min
- Channel C files: ~111 MB/min
- Pattern: A ≈ B ≈ C (balanced, suggesting uniform resolution setting)

**⚠️ Important:** These file sizes reflect the **user's current settings**, not hardware capabilities. The same camera could produce different file sizes if the user changes resolution settings.

## GPS Log Format

**Location:** `GPS/YYYYMMDD.dat`  
**Format:** CSV with `\r\n` line endings  
**Fields per line:** `YYYYMMDDHHMMSS,LAT,N/LON,W,altitude,speed`

**Example:**
```
#
20000101000000,0.000000,N,0.000000,E,0.000,0.000
```

## Detection Rules (Reliable Only)

**Model Family Detection (Medium Confidence):**
- Folder structure matches Vantrue N4 series: `Normal/`, `Event/`, `Parking/`, `Photo/`, `GPS/`
- Filename pattern: `^\d{8}_\d{6}_\d{5}_[NEP]_[ABC]\.(MP4|JPG)$` (sequence number is key signature)
- GPS files: `GPS/*.dat` with CSV format starting with `#` header

**Channel Mode Detection:**
- 3CH mode: A, B, and C channels present (as on this card)
- 2CH mode: Only A+B or A+C channels
- 1CH mode: Only A channel (front always present)

**Cannot Determine Without Explicit Metadata:**
- N4 S vs N4 Pro S vs N4 vs N4 Pro (all share same folder/filename patterns)
- User's resolution settings (require config file analysis or user confirmation)

**Exclusions:**
- macOS resource forks: `._*`
- System folders: `.Spotlight-V100/`, `.fseventsd/`

## Comparison to Related Models

| Feature | N4 S | N4 Pro S | N4 | N4 Pro |
|---------|------|----------|-----|--------|
| Folder structure | Same | Same | Same | Same |
| Filename pattern | Same | Same | Same | Same |
| GPS format | Same | Same | Same | Same |
| Hardware max resolution | 2.5K (all channels) | 4K/1080P/2.5K | 4K/1080P/1080P | 4K/1080P/2.5K |
| User-configurable | Yes (1CH/2CH/3CH) | Yes (1CH/2CH/3CH) | Yes | Yes |

**Key point:** All N4 series models share identical folder structures and filename patterns. Resolution/bitrate/channel count are user-configurable and cannot definitively identify the model without explicit metadata.

## Open Questions

- Does the N4 S have a model identification file that wasn't present on this specific card?
- Do firmware updates add model metadata files?
- How does the N4S LTE variant differ, if at all?
- Are there config files that explicitly state the model (requires user permission to read)?

## Profile Schema Version

This profile conforms to the dashcam-offloader profile schema v1.0.

## References

- `docs/research/vantrue-model-reference.md` - Vantrue model family overview
- `docs/card-profiles/vantrue-n4-pro-s.md` - N4 Pro S profile (same folder/filename pattern)
- Vantrue N4 S user manual: https://vantrue-app.vantruecam.com/files/manuals/n4s/Vantrue%20N4S%20User%20Manual%20English.pdf

## Revision Notes

**2026-06-05 (Initial):** Assumed model identification based on file size patterns (balanced bitrates).

**2026-06-05 (Revised per user feedback):** Removed bitrate/resolution-based identification as unreliable. These are user-configurable settings, not hardware characteristics. Model identification requires explicit metadata files or user confirmation. Labeled as "N4 S" based on user-provided volume label and folder/filename pattern matching to N4 series.
