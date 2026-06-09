# Thinkware U3000 Pro

## Status

Seed profile, based on mounted U3000 Pro cards at `/Volumes/U3000PRO` and Thinkware documentation, including a 3CH card with the Interior IR cabin camera enabled.

## Source References

- Official support/download page: <https://thinkware.com/global/support/download/u3000-pro>
- Official English manual PDF: <https://download2.inavi.com/dashcam/U3000PRO/manual/u3000pro_manual_english_20250924.pdf>

## Model Detection

Highest-confidence evidence:

- `SETTING/lang/ver.dat` contains `Device Name:U3000PRO`.
- `SETTING/setup.cfg` references `U3000PRO` and `SETTING\U3000PRO_Setting.exe`.
- `SETTING/default.cfg` references `U3000PRO` and `SETTING\U3000PRO_Setting.exe`.
- `SETTING/U3000PRO_Setting.exe` exists.

Weak evidence:

- Volume label was `U3000PRO`, but volume labels are user-renamable.

Do not use:

- `device.uid` for model identification.

## Recording Folders

- `cont_rec` - continuous driving recording.
- `evt_rec` - driving event or impact recording.
- `motion_timelapse_rec` - parking motion or time-lapse recording.
- `parking_rec` - parking incident recording.
- `.parking_rec_sec` - secondary parking recording bucket listed by manual.
- `manual_rec` - manual recording, manual-confirmed but empty on the sample card.
- `sos_rec` - SOS recording, manual-confirmed but empty on the sample card.
- `incabin_rec` - in-cabin recording. A real 3CH card confirms Interior IR cabin clips here.

## Filename Patterns

Observed public MP4 examples use:

- `REC_YYYYMMDD_HHMMSS_F.MP4`
- `REC_YYYYMMDD_HHMMSS_R.MP4`
- `EVT_YYYYMMDD_HHMMSS_F.MP4`
- `EVT_YYYYMMDD_HHMMSS_R.MP4`
- `MOT_YYYYMMDD_HHMMSS_F.MP4`
- `MOT_YYYYMMDD_HHMMSS_R.MP4`
- `PAK_YYYYMMDD_HHMMSS_F.MP4`
- `PAK_YYYYMMDD_HHMMSS_R.MP4`
- `PAS_YYYYMMDD_HHMMSS_F.MP4`
- `PAS_YYYYMMDD_HHMMSS_R.MP4`
- `EXT_YYYYMMDD_HHMMSS_I.MP4`

Observed special variants:

- `F_SS`
- `R_SS`

The meaning of `SS` still needs validation.

## In-Cabin Behavior

The official U3000 Pro manual confirms the in-cabin feature requires the Interior IR camera and stores in-cabin video in the `incabin_rec` folder. It also says in-cabin videos are recorded during continuous recording mode.

A real 3CH card provided by Ariel on 2026-06-08 confirms in-cabin files use the `EXT` prefix and `I` channel suffix:

- `incabin_rec/EXT_YYYYMMDD_HHMMSS_I.MP4`

## Channels

- `F` - front
- `R` - rear
- `I` - interior / in-cabin

## Exclude By Default

- `SETTING`
- `THUMBNAIL`
- `driveinfo`
- `device.uid`
- `.TWSYS`
- `.Spotlight-V100`
- `.fseventsd`
- `._*`

## Media And Config Notes

Mounted-card pass on 2026-06-08 measured the current `/Volumes/U3000Pro` card:

- `cont_rec`: F is HEVC 3840x2160 30 fps at about 30 Mbps; R is HEVC 2560x1440 30 fps at about 10 Mbps.
- `incabin_rec`: I is H.264 1920x1080 30 fps at about 8 Mbps stream bitrate on the sampled 3CH card. The measured container bitrate was about 12.3 Mbps.
- `evt_rec`: F/R use the same 4K/2K 30 fps pattern.
- `parking_rec`: parking incident samples measured 15 fps, with F at 3840x2160 about 11.9 Mbps and R at 2560x1440 about 5.0 Mbps.
- `motion_timelapse_rec`: F/R measured 2560x1440 15 fps at about 5.0 Mbps.
- `.parking_rec_sec` `PAS` files measured 1280x720 15 fps at about 0.6 Mbps and should be treated as secondary/internal parking evidence rather than normal user footage.
- Safe config strings in `SETTING/default.cfg`, `SETTING/setup.cfg`, and `SETTING/lang/ver.dat` provide model, firmware/config version, language pack, and timezone evidence. Do not use `device.uid` for model detection.

## Open Questions

- Meaning of `F_SS` and `R_SS`.
- Filename pattern for manual recordings.
- Filename pattern for SOS recordings.
- Whether any protected status is represented by filesystem flags.
