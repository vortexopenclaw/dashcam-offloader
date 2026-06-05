# Vantrue E1 Pro Card Profile

**Camera Model:** Vantrue E1 Pro  
**Hardware Capability:** 1-channel front recording  
**Profile Date:** 2026-06-05  
**Evidence Source:** Real SD card at `/Volumes/Untitled` and official Vantrue E1 Pro manual  
**Confidence Level:** HIGH - model-specific settings filename plus matching Vantrue folder and filename structure

## Model Detection

**Highest-confidence evidence observed on this card:**
- `GPS/E1PRO_Settings.ini` exists. This filename is model-specific and was present on the sampled card.
- Folder structure matches Vantrue Element/Nexus style: `Normal/`, `Parking/`, `Event/`, `Photo/`, `GPS/`.
- Filename pattern matches Vantrue sequence format: `YYYYMMDD_HHMMSS_SEQ_MODE_CH.EXT`.

**Supporting evidence:**
- Official E1 Pro manual names the product as Vantrue E1 Pro / Element 1 Pro.
- Official manual shows the same filename examples for normal, event, parking, and time-lapse recordings.
- The card was single-channel only with channel token `A`, consistent with E1 Pro front-only hardware.

**Do not use for model identification:**
- Resolution, bitrate, file size, and loop duration are user-configurable settings.
- GPS speed/location data is private and should not be stored in public docs.
- Volume label `Untitled` is not useful evidence.

## Folder Structure

| Folder | Mode | Description |
|---|---|---|
| `Normal/` | normal | Driving loop recordings and possible time-lapse clips depending on mode token. |
| `Parking/` | parking/event | Parking monitoring clips. Observed motion-detection parking clips and parking emergency clips on this card. |
| `Event/` | event | Event folder exists on the sampled card, but was empty. Do not require event files here. |
| `Photo/` | photo | Photo snapshots. Observed parking and event snapshots on this card. |
| `GPS/` | settings | Contains `E1PRO_Settings.ini`; may support app/GPS workflow. Do not publish real GPS trail data. |

Event-mode clips were observed in `Parking/` on this card, and event snapshots were observed in `Photo/`. The empty `Event/` folder may be used only for some event workflows or firmware/settings combinations.

## Filename Pattern

**Format:** `YYYYMMDD_HHMMSS_SEQ_MODE_CH.EXT`

**Dummy examples:**
- `20300128_140633_00008_N_A.MP4` - normal driving video
- `20300128_140633_00007_P_A.MP4` - parking video
- `20300128_140633_00008_E_A.MP4` - event/emergency video
- `20300128_140633_00006_T_A.MP4` - time-lapse video from manual example
- `20300128_140633_00001_P_A.JPG` - parking photo snapshot

**Breakdown:**
- `YYYYMMDD` - recording date
- `HHMMSS` - recording time
- `SEQ` - 5-digit sequence number
- `MODE` - recording mode token
- `CH` - channel token
- `EXT` - `.MP4` for videos, `.JPG` for photos

## Recording Modes

| Token | Meaning | Validation |
|---|---|---|
| `N` | Normal driving loop recording | Observed on real card and manual-confirmed |
| `P` | Parking monitoring video/photo | Observed on real card and manual-confirmed |
| `E` | Event/emergency clip or snapshot | Observed in `Parking/` and `Photo/` on real card, manual-confirmed |
| `T` | Time-lapse recording | Manual-confirmed only; not observed on this card |

## Channel Mapping

| Token | Channel | Validation |
|---|---|---|
| `A` | Front | Observed on all sampled videos and photos |

No `B` or `C` channels were observed, and E1 Pro is a front-only model.

## Sampled Recording Settings

The inspected card recorded H.264 3840x2160 at 30 fps on sampled normal and parking clips.

This is only a sampled setting. Do not use resolution, codec, bitrate, or duration as model-identification evidence.

## GPS and Privacy Notes

The card contains `GPS/E1PRO_Settings.ini`. The file path is useful model evidence, but public docs must not include private GPS coordinates, speed traces, routes, or unique device identifiers.

Use dummy GPS values only if an example is needed.

## Exclusions

- macOS sidecars: `._*`
- macOS system folders: `.Spotlight-V100/`, `.fseventsd/`
- Root firmware files: `*.bin` should be treated as optional bonus evidence only if already present, not expected by default.
- Unique device IDs, serial numbers, real GPS coordinates, and real route traces.

## Detection Rules

**High confidence:**
- `GPS/E1PRO_Settings.ini` exists, and
- folder structure includes Vantrue-style recording folders such as `Normal/`, `Parking/`, `Photo/`, and `GPS/`, and
- filenames match `^\d{8}_\d{6}_\d{5}_[NPET]_A\.(MP4|JPG)$`.

**Medium confidence:**
- Vantrue folder and filename structure match, but `GPS/E1PRO_Settings.ini` is missing.
- In this case, present E1 Pro alongside related Vantrue single-channel Element/Nexus candidates for user confirmation.

## Open Questions

- Whether the empty physical `Event/` folder is used only for some event workflows or firmware/settings combinations.
- Whether `T` time-lapse files are stored under `Normal/` as shown in the manual examples, or under another folder depending on firmware/settings.
- Whether E1 Pro firmware files use a stable model-coded filename on official download pages.

## References

- Vantrue E1 Pro Japanese/multilingual user manual: https://vantrue-app.vantruecam.com/files/manuals/Vantrue-E1Pro-User-Manual-Japanese.pdf
