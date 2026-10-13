# Dashcam Offloader 0.1.30

- Create editable five-angle Final Cut multicams from four-channel VIOFO footage: front, interior, rear, telephoto, and a 2×2 grid.
- Match F/I/R/T and PF/PI/PR/PT filenames by recording timestamp, without audio analysis. Keep source frame rate, recording gaps, and original downloaded media.
- Grid layout: front upper left, interior upper right, telephoto lower left, rear lower right. Retain front-camera audio and mute the other grid tracks.
- Create multicams automatically after download or choose an existing footage folder. Open the saved FCPXML in Final Cut to import the editable clips.
- Preserve appended filename descriptions as recording-start markers, with camera labels on the multicam. Keep folder names in multicam names and markers, and retain per-camera clip annotations.
- Report missing channels, duplicate recordings, overlapping timestamps, and unsupported mixed frame rates instead of guessing. Existing downloads and XML files are never overwritten by multicam creation.
