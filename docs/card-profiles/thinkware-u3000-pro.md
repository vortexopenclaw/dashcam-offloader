# Thinkware U3000 Pro

## Status

Seed profile, based on one mounted sample card at `/Volumes/U3000PRO` and Thinkware documentation.

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
- `incabin_rec` - cabin recording, manual-confirmed but empty on the sample card.

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

Observed special variants:

- `F_SS`
- `R_SS`

The meaning of `SS` still needs validation.

## Channels

- `F` - front
- `R` - rear

## Exclude By Default

- `SETTING`
- `THUMBNAIL`
- `driveinfo`
- `device.uid`
- `.TWSYS`
- `.Spotlight-V100`
- `.fseventsd`
- `._*`

## Open Questions

- Meaning of `F_SS` and `R_SS`.
- Filename pattern for manual recordings.
- Filename pattern for SOS recordings.
- Filename pattern for cabin recordings.
- Whether any protected status is represented by filesystem flags.

