# Cansonic UltraDash Z3+ Standard Edition — Research Notes

## Sources

- Official product page: [cansonic.com/products/ultradash-z3-standard-dash-cam](https://cansonic.com/products/ultradash-z3-standard-dash-cam)
- Private archive sample
- No direct microSD card scan

## Manufacturer

Cansonic (Pasadena, CA). Taiwan-origin dashcam brand with a focus on dual-lens designs.
The UltraDash Z3+ is their flagship dual-lens model featuring a patented magnetic mount
and 180°-rotatable lenses.

## Camera Design

The Z3+ has **two physically rotatable front lenses** mounted on the same unit:

- **Left (L)**: Wide-angle, 140° FOV — captures the full road scene
- **Right (R)**: Telephoto, up to 164ft/50m — captures distant plates, signs, objects

Both lenses rotate 180°, so either can be aimed forward or backward. The R telephoto
can be physically aimed rearward to record behind the vehicle without a separate
rear camera.

The **B channel** is an optional add-on rear camera (**UltraDash R1**), connected via
cable. It is not part of the main Z3+ unit. The R1 is a separate IP67 waterproof camera
with a 160° FOV, also recording at 2K QHD.

### Standard vs Commercial Editions

| Edition | Left lens | Right lens |
|---|---|---|
| Standard | Wide angle (140°) | Telephoto |
| Commercial | Wide angle (traffic) | IR cabin (interior recording) |

These are different products with distinct use cases. This profile covers the Standard
Edition only.

## Filename Pattern

Pattern: `YYYYMMDD_HHMMSS_CHANNEL.MP4`

| Field | Format | Example |
|---|---|---|
| Date | `YYYYMMDD` | `YYYYMMDD` |
| Separator | `_` | |
| Time | `HHMMSS` | `HHMMSS` |
| Separator | `_` | |
| Channel | Single letter: `L`, `R`, or `B` | `L` |
| Extension | `.MP4` (uppercase) | |

**No sequence number.** L, R, and B files with identical timestamps are synchronized
clips recorded simultaneously.

### Channel Letters

| Letter | Role | Description |
|---|---|---|
| `L` | Wide front | 140° wide-angle lens |
| `R` | Telephoto front | 164ft telephoto, 180° rotatable |
| `B` | Rear (optional) | UltraDash R1 add-on camera |

### Comparison with VIOFO A139 Pro

The A139 Pro also has no sequence number but uses a split date format:

| Camera | Pattern |
|---|---|
| Cansonic Z3+ | `YYYYMMDD_HHMMSS_CHANNEL.MP4` (8-digit date) |
| VIOFO A139 Pro | `YYYY_MMDD_HHMMSS_CHANNEL.MP4` (split date, 4+4) |

The 8-digit vs split date is the key differentiator, along with L/R/B channel letters
vs VIOFO's F/I/R.

## Channel Configuration

Footage samples include clips with L+R only and clips with L+R+B, confirming:

- L and R are always present (built into the main unit)
- B requires the optional R1 rear camera — its absence does not disqualify the model

## Resolution and Codec

| Channel | Resolution | Codec | Source |
|---|---|---|---|
| L (wide) | 2560×1440 | unknown | Official spec |
| R (telephoto) | 2560×1440 | unknown | Official spec |
| B (rear R1) | 2560×1440 | unknown | Official spec |

Codec not confirmed — ffprobe not yet performed. Official spec lists "MP4" format
without specifying H.264 vs H.265.

## OSD

"Information Stamp: Support" per official specs. The actual OSD content (date/time
format, whether model name is included) is not confirmed — OCR not yet performed.

## Detection Strategy

1. **Filename pattern** (primary): `^(\d{8})_(\d{6})_([LRB])\.MP4$` — 8-digit contiguous
   date + L/R/B channel letters is distinct from all other profiled cameras
2. **Synchronized L+R pairs**: Same timestamp across both channels confirms dual-lens recording
3. **Resolution** 2560×1440 across all channels (supporting, not unique)

## Open Questions

- On-card folder structure (no card scan)
- Locked/event file naming or folder — how are G-sensor-triggered clips stored?
- Parking mode file naming (time-lapse, vibration)
- OSD content — does it include model name?
- Codec (H.264 vs H.265)
- Whether the Commercial Edition uses the same filename pattern with different channel letters
  (Commercial has an IR interior lens instead of telephoto)
