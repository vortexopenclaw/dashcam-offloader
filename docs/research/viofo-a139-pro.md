# VIOFO A139 Pro — Research Notes

## Camera Overview

The VIOFO A139 Pro is a 3-channel dashcam (front, interior, rear) with 4K front, 1080P interior, and 1080P rear cameras. It uses a different platform generation than the A229/A329 lineup, reflected in a distinct filename convention.

## Filename Convention

**Pattern: `YYYY_MMDD_HHMMSS_CHANNEL.MP4`**

This differs from the A229/A329 series in one key way: **no sequence number**. The filename components are year, month/day, time, and channel letter only. This is an important distinction for any grouping or deduplication logic.

The channel letter is separated by an underscore (e.g., `_F`, `_I`, `_R`), unlike the A229/A329 where the channel letter is appended directly to the sequence number.

## Codec Notes

The A139 Pro uses a mixed-codec scheme:
- Front (F): H.264
- Interior (I): HEVC (H.265)
- Rear (R): H.264

The HEVC interior channel is unusual and not seen on A229/A329 models. Any offloading or transcoding pipeline must handle both codecs.

## OSD Stamp

The A139 Pro OSD displays the model name in all caps:

```
000MPH DUMMYCAM VIOFO A139 PRO HDR+ON 01/01/2000 00:00:00
```

Fields: GPS speed · optional user-set camera name · model ("VIOFO A139 PRO") · HDR status · date/time

The all-caps model suffix ("PRO") differs from newer VIOFO models like the A229 Pro which display "Pro" in title case. OSD detection must use case-insensitive matching.

## Source Validation

This profile was built from a private archive sample, not a direct microSD card scan. Card folder structure, parking modes, and exclusion patterns are inferred. A real card scan would confirm:
- Whether Parking, RO, and Photo subfolders exist and what naming they use
- Whether `format.txt` appears at root
- NOVATEK `©fmt`/`©inf` metadata on real files

## Sources

- Private archive sample; counts and recording dates intentionally omitted
- VIOFO product page: https://www.viofo.com/collections/dash-cam
