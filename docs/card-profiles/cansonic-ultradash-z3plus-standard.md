# Cansonic UltraDash Z3+ Standard Edition Card Profile

**Make:** Cansonic  
**Model:** UltraDash Z3+ Standard Edition  
**Channels:** 2 built-in (L + R); 3 with optional R1 rear camera (B)  
**Resolution:** 2K QHD (2560×1440) per channel  
**Source:** Official product page + private archive sample

---

## Filename Format

```
YYYYMMDD_HHMMSS_CHANNEL.MP4
```

| Field | Description | Example |
|---|---|---|
| `YYYYMMDD` | Recording date (8 digits, no separator) | `20240101` |
| `_` | Separator | |
| `HHMMSS` | Recording time (24h) | `120000` |
| `_` | Separator | |
| `CHANNEL` | Single letter: `L`, `R`, or `B` | `L` |
| `.MP4` | Uppercase extension | |

**Examples:**
- `20240101_120000_L.MP4` — wide-angle front
- `20240101_120000_R.MP4` — telephoto front (same timestamp, synchronized)
- `20240101_120000_B.MP4` — rear camera (R1 installed)

**No sequence number.** Synchronized channel files always share the same timestamp.

## Channel Roles

| Letter | Role | Description |
|---|---|---|
| `L` | Wide-angle front | 140° FOV, standard road scene capture |
| `R` | Telephoto front | 164ft (50m) range, reads distant plates. 180° rotatable — can face rearward. |
| `B` | Rear (optional) | UltraDash R1 add-on camera, 160° FOV, IP67 waterproof. Only present if R1 is installed. |

## Folder Structure

> **Note:** Folder structure not confirmed from a direct card scan. Based on product documentation.

Standard Cansonic layout is likely a flat DCIM directory with all clips in one place.
Locked/event clips may use a different subfolder or prefix — not confirmed.

## Detection

The filename pattern `^(\d{8})_(\d{6})_([LRB])\.MP4$` is the primary signal.

**Key distinguisher from VIOFO A139 Pro** (also no sequence number):

| | Cansonic Z3+ | VIOFO A139 Pro |
|---|---|---|
| Date format | `YYYYMMDD` (8 digits) | `YYYY_MMDD` (split) |
| Channel letters | `L`, `R`, `B` | `F`, `I`, `R` |

The synchronized L+R pair at identical timestamps also confirms the dual-lens design.

## Specs (from official product page)

| Spec | Value |
|---|---|
| Resolution | 2560×1440 (2K QHD) per channel |
| Wide lens FOV | 140° |
| Telephoto range | 164 ft (50 m) |
| Sensor | Sony Starvis, F1.8 aperture |
| Display | 2.7" LCD |
| Storage | microSD up to 256GB, U3+ |
| Capacitor | Super capacitor (no battery) |
| Parking mode | Optional (requires hardwire kit) |
| Rear camera | Optional (UltraDash R1, IP67, 2K, 160°) |
| GPS | Optional (GPS magnetic mount) |
