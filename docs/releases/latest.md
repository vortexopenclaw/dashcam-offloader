# Dashcam Offloader 0.1.2

- Added every researched camera model to the manual picker. Supported profiles
  and known models that still need a card scan appear in separate sections.
- Known but unverified cameras stay on the generic read-only importer. The app
  does not apply storage rules from a related camera merely because its name is
  similar.
- Added an optional card-verification prompt for known cameras that still need
  evidence. The review shows file, mode, and channel counts plus grouped codec,
  resolution, frame-rate, bitrate, duration, and allowlisted settings data.
- Kept learning submissions privacy-safe. Source paths, folder paths, raw
  filenames, timestamps, media, GPS, serial and network identifiers, and
  credentials are excluded from the transmitted scan.
- Fixed camera brand and model selection while sources are scanning and after
  the app returns from idle. Manual choices now remain authoritative instead
  of being overwritten by an older scan.
- Restored exact BlackVue DR970X LTE Plus recognition from safe model metadata
  and added its validated two-channel card profile.
- Added clearer selected-camera technical details while keeping the larger
  community technical reference separate from the offloader interface.
- Hardened feedback sanitization, privacy checks, dependency pinning, and
  release verification.
