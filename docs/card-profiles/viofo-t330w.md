# VIOFO T330W (T330-family rear-camera variant)

Status: experimental, owner-submitted card samples and three owner-provided frame observations. Firmware reported by owner: `1.0_260910`.

## Exact model recognition

The owner-provided front, rear, and interior frames show the **`VIOFO T330W`** on-screen model stamp near the bottom center. The model stamp is user-configurable and may be disabled. Probe front `F` footage with bottom-strip OCR; only an exact model-stamp match should disambiguate this camera from VIOFO A229/A329 siblings. A generic VIOFO card layout or filename suffix is **not** proof of T330W.

T330 and T330W share the same main-camera family; the attached rear camera is a variant. The non-W model's exact OSD stamp has not yet been confirmed. Do not assume a W stamp identifies a different main platform or assume identical measured rear bitrate without testing.

## Card evidence

Two sanitized learning submissions from one owner confirmed `DCIM/Movie`, `DCIM/Movie/Parking`, `DCIM/Movie/RO`, and `DCIM/Photo` with three-channel F/I/R and PF/PI/PR suffixes. The first completed scan (84 files) was owner-labeled normal-bitrate driving and low-bitrate parking. The second completed scan (36 files) was owner-labeled high-bitrate driving and 1-fps Night Vision time-lapse parking. These settings can coexist on a card; sample clips by folder/channel and do not extrapolate a setting to all files.

The second submission's `RO` parking clips have 30-fps playback, with two recording starts 30 minutes apart and one 60-second clip per channel; this is consistent with 1-fps capture over 30 minutes. The owner reports no audio on those clips, but the sanitized scan does not include audio-track presence. Do **not** label all RO clips as impact events or all RO clips as time lapse: use model-specific media timing/audio context or a confirmed setting. The profile folder mapping stays protected/neutral pending that classification fix.

No raw user frames or footage are distributed in this repository. App OCR is local and sends neither frames nor OSD text in feedback.
