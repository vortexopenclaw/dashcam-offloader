# Vueroid S1 4K Infinite

## Status

Seed profile, based on official Vueroid S1 4K Infinite manual research and one real 3CH sample card read-only scanned at `/Volumes/S1-4K`.

Use `Vueroid S1 4K Infinite` as the public app model name. Treat 1CH, 2CH, and 3CH as channel variants behind the scenes.

## Recording Folders

Real-card observed:

- `INF` - driving recording. Observed prefix `INF`, 584 visible MP4 files.
- `PARK` - parking motion or time-lapse recording. Observed prefix `PRK`, 390 visible MP4 files.
- `PEVENT` - parking impact event recording. Observed prefix `PVT`, 87 visible MP4 files.
- `USER` - manual recording. Observed prefix `USR`, 21 visible MP4 files.
- `EVENT` - driving impact event recording. Manual-confirmed, no visible MP4 files on this sample card.
- `BOOKMARK` - screenshot or bookmark images. Manual-confirmed, no visible files on this sample card.
- `CONFIG` - system/config data, exclude by default.

## Filename Pattern

Visible MP4 files on the sample card use:

`YYYYMMDD_HHMMSS_PREFIX_CHANNEL_FLAG.mp4`

Examples:

- `INF/20260602_103315_INF_F_N.mp4`
- `INF/20260602_103315_INF_I_N.mp4`
- `INF/20260602_103315_INF_R_N.mp4`
- `PARK/20260603_175950_PRK_F_N.mp4`
- `PEVENT/20260602_165438_PVT_I_N.mp4`
- `USER/20260509_110719_USR_R_N.mp4`

Observed channel tokens:

- `F` - front
- `I` - interior
- `R` - rear

The final flag token was always `N` in visible MP4 samples. Its meaning is still unknown.

## Related-File Grouping

Group related files by date, time, and prefix. Most groups are front, interior, and rear triplets.

Observed exceptions:

- `INF` had 193 complete `F/I/R` groups and 5 `F`-only groups near the end of the sample.
- `PARK`, `PEVENT`, and `USER` groups were complete `F/I/R` triplets on this sample.

## Channel Variants

The S1 4K family can be configured as:

- 1CH - front only.
- 2CH - front and rear.
- 3CH - front, rear, and interior.

## Exclude By Default

- `CONFIG/**`
- `.TFF_REC_RESERVE*`
- `*.SYS`
- `*.NFF`
- `.Spotlight-V100/**`
- `.fseventsd/**`
- `._*`
- macOS sidecars and hidden OS folders

## Open Questions

- Whether `EVENT` uses prefix `EVT`, another token, or a different storage behavior when visible event MP4 files exist.
- Whether parking time-lapse uses the same folder and prefix as motion clips.
- Whether manual or event clips are also marked read-only by the filesystem.
- Related-file grouping across 1CH, 2CH, and 3CH setups.
- Meaning of the final `N` filename flag.
