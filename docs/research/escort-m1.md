# Escort M1 — Research Notes

## Sources

- **Real card scan**: Physical Escort M1 card. Folder structure, filename pattern, and sequence behavior confirmed directly.
- **User manual**: Escort M1 User Manual (REV 08/13/20). Covers specifications, folder naming, firmware update behavior, OSD settings, and app-configurable options.

---

## Card Layout

All footage is stored under `Escort_M1/` at the card root, not under `DCIM/` or any other generic structure. This is a distinctive, camera-specific layout choice that makes detection unambiguous.

Normal loop clips go into `Escort_M1/MOVIE/`. Locked clips (G-sensor and manual emergency lock) go into `Escort_M1/LockedVideo/`.

---

## Filename Format Analysis

Pattern: `YYYY_MMDD_HHMMSS_SEQ.MOV`

The timestamp structure is identical to VIOFO cameras (`YYYY_MMDD_HHMMSS`), but three differences prevent false positives:

1. **Container**: `.MOV` (uppercase) vs VIOFO's `.MP4`
2. **Channel suffix**: absent — M1 is single-channel with no `_F`, `_R`, etc.
3. **Folder structure**: `Escort_M1/` root subfolder vs VIOFO's `DCIM/`

Any one of these three is sufficient to distinguish. The combination is unambiguous.

---

## Sequence Number Behavior

The sequence counter is monotonic and global across both `MOVIE/` and `LockedVideo/`. This was confirmed by observing a clip in MOVIE, the following two clips in LockedVideo (sequential numbers), and the clip after them back in MOVIE — with no gaps in the sequence.

This means sequence numbers can be used for chronological ordering and completeness checking across both folders without needing to fall back to file timestamps.

---

## Locked Clip Logic

From the manual: when a G-sensor event is detected, the current clip is locked. If the event occurs within 30 seconds of a file boundary, the adjacent clip is also locked. The manual does not clarify whether "adjacent" means only the following clip or also the preceding one — both should be treated as protected in practice.

---

## Codec and Resolution

The manual specifies 1080P (1920×1080) as the default resolution, with 720P 60fps and 720P 30fps as configurable alternatives. The hardware platform (Novatek NT96658) and release era (2020) make H.264 highly likely, but codec was not confirmed via ffprobe during the card scan (bash environment unavailable).

Container is MOV. This is consistent with the NT96658 platform used in other dashcams of this era.

---

## OSD (Video Stamp)

The manual documents a "Video Stamp" setting that burns date/time into the bottom of the frame. It is enabled by default. Three date format options are available: `YYYY/MM/DD`, `MM/DD/YYYY`, or `DD/MM/YYYY`.

The manual does not mention the model name being burned in alongside the timestamp. OSD model-name burn-in is not confirmed.

Because this is a 1CH-only camera with a very distinctive folder layout, OSD-based disambiguation is not needed for detection. The `Escort_M1/` folder name alone provides high confidence.

---

## Parking Mode

Not supported. The M1 is ignition-powered only. No hardwire kit or parking recording mode is documented in the manual.

---

## Firmware Updates

The manual instructs users to copy `FW96658A.bin` to the card root for a firmware update. The file is deleted automatically after the update completes. A firmware file at the card root would be a supporting signal during an unusual scan, but should not be weighted heavily since it is transient.

---

## Open Questions

| Question | Status |
|----------|--------|
| Exact codec (H.264 or H.265?) | Unconfirmed — H.264 assumed from platform |
| OSD model name burn-in | Not observed in manual |
| Sequence rollover behavior (does it wrap at 999?) | Unknown |
| Whether clip length affects anything scannable | Unknown |
