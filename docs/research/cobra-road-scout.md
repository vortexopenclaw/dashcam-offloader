# Cobra Road Scout — Research Notes

## Sources

- **Real card scan**: Physical Cobra Road Scout SD card. Folder structure, filename pattern, and sequence behavior confirmed directly.
- **Owner's manual**: Cobra Road Scout Owners Manual (Quick Reference, REV 08/13/20). Covers recording modes, G-sensor, loop clip time, GPS, Wi-Fi, and firmware update behavior.

---

## Card Layout

All footage goes to `DCIM/RoadScout/` — a single folder under DCIM with the camera's name as a subfolder. There are no separate subfolders for locked or event clips. The subfolder name "RoadScout" is specific to this device family.

A `rom.bin` file is permanently present at the card root. Most likely it is the DEFENDER red light/speed camera database, which the manual describes as updatable via Wi-Fi. It could also be radar firmware. Unlike transient firmware update files (e.g., Escort M1's `FW96658A.bin`, which auto-deletes after flashing), `rom.bin` persists during normal use.

---

## Filename Pattern Analysis

Pattern: `YYYYMMDD_NNNN_VID.MOV`

The `_VID` suffix is notable. On most dashcams this position is used for a channel letter (`_F`, `_R`, `_I`) or mode code. Cobra uses a fixed literal instead. This makes the pattern unambiguous — no VIOFO, 70mai, BlackVue, or Vantrue camera produces a file ending `_VID.MOV`.

The 8-digit date with no separator (`YYYYMMDD`) is shared with Vantrue and BlackVue cameras, but the `_VID` suffix and `.MOV` extension distinguish Cobra from all of them.

---

## Sequence Number Behavior

The sequence is date-scoped, not global. Every date starts at `0001`. Confirmed from card: multiple distinct dates each have a sequence starting at `0001`.

This means the sequence alone cannot be used to establish global chronological order. The correct sort key is `(date, sequence)`.

---

## Locked Clip Handling

The manual describes two mechanisms for creating protected clips:

1. **G-sensor impact detection**: Automatically locks the clip being recorded when a collision is detected. The G-sensor sensitivity is configurable from 1 to 3 (default level 2). Level 1 is most sensitive and may over-trigger on bumps.

2. **Emergency recording (MARK hold)**: Holding the MARK button triggers emergency recording. A voice prompt confirms: "Emergency Recording On." The clip length follows the Loop Clip Time setting.

No separate locked folder was observed on the card. Based on the manual and card structure, locked clips appear to remain in `DCIM/RoadScout/` but are flagged as protected (not overwritten by loop recording). Distinguishing locked vs. normal clips programmatically from the filename alone is not possible — they share the same pattern.

---

## GPS Storage

The manual shows a GPS satellite icon on the display and the Drive HD app can overlay a route on recorded footage. This strongly implies GPS data is embedded in the video file, not in a separate sidecar. The exact format (NMEA track, MP4 GPS atom, etc.) was not confirmed from ffprobe.

---

## Codec and Resolution

Not confirmed from ffprobe (bash unavailable during card scan). The manual refers to "HD" recording, which is ambiguous between 720P and 1080P. H.264 1080P 30fps is the assumption based on:
- 2019 hardware era (FCC ID BBORDCAM)
- Budget combo device category (radar + dashcam)
- `.MOV` container common with NT96-family chips
- "HD" branding without explicit 4K or 2K claim

Actual confirmation requires ffprobe on a real clip.

---

## Volume Label

The card formatted as "NO NAME" — the generic default for unbranded FAT32 media. Unlike VIOFO cameras (e.g., "A229PRO") and Escort M1 ("ESCORT M1"), Cobra does not write a branded volume label during formatting. The volume label cannot be used for detection.

---

## Wi-Fi

The Road Scout only supports 2.4 GHz Wi-Fi (802.11 b/g/n). It connects to the vehicle's hotspot or to the phone's hotspot for database updates. It also creates its own Wi-Fi access point (SSID: "Road Scout", password: "12345678") for the Drive HD app to connect to for live view and clip download. The default password is a detection signal if scanning via Wi-Fi, but not relevant to card-based detection.

---

## Open Questions

| Question | Status |
|----------|--------|
| Codec (H.264 vs H.265?) | Unconfirmed — H.264 assumed |
| Resolution (1080P vs 720P?) | Unconfirmed — 1080P assumed |
| Frame rate | Unconfirmed — 30fps assumed |
| GPS data format in video | Unknown |
| Are locked clips distinguishable by filename? | Not observed — assumed no |
| What does rom.bin contain exactly? | Unknown — DEFENDER DB or radar firmware |
| Sequence rollover behavior at 9999? | Unknown |
