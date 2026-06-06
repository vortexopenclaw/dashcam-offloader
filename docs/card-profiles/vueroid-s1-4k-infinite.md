# Vueroid S1 4K Infinite

## Status

Seed profile, based on official Vueroid S1 4K Infinite manual research and real card scans of both a 3CH and a 2CH variant.

Use `Vueroid S1 4K Infinite` as the public app model name. Treat 1CH, 2CH, and 3CH as channel variants behind the same profile.

## Recording Folders

Both sampled cards (2CH and 3CH) had identical folder structure:

- `INF` — continuous driving recording. Prefix `INF`.
- `PARK` — parking motion or time-lapse recording. Prefix `PRK`.
- `PEVENT` — parking impact event recording. Prefix `PVT`.
- `USER` — manual recording. Prefix `USR`.
- `EVENT` — driving impact event recording. No visible MP4 files on either sampled card.
- `BOOKMARK` — screenshot or bookmark images. No visible files on either sampled card.
- `CONFIG` — system/config data, exclude by default.

## Filename Pattern

`YYYYMMDD_HHMMSS_PREFIX_CHANNEL_FLAG.mp4`

Examples:

- `INF/YYYYMMDD_HHMMSS_INF_F_N.mp4`
- `INF/YYYYMMDD_HHMMSS_INF_I_N.mp4` (3CH only)
- `INF/YYYYMMDD_HHMMSS_INF_R_N.mp4`
- `PARK/YYYYMMDD_HHMMSS_PRK_F_N.mp4`
- `PEVENT/YYYYMMDD_HHMMSS_PVT_R_N.mp4`
- `USER/YYYYMMDD_HHMMSS_USR_F_N.mp4`

Observed channel tokens:

- `F` — front
- `I` — interior (3CH only)
- `R` — rear (2CH and 3CH)

The final flag token was always `N` on all visible MP4 samples across both cards. Meaning unknown.

## Channel Variants

| Variant | Channels | Validation |
|---|---|---|
| 1CH | F only | Manual confirmed |
| 2CH | F + R | Real card sampled |
| 3CH | F + I + R | Real card sampled |

The 2CH card produced F+R synchronized pairs at identical timestamps across all recording modes (INF, PARK, PEVENT, USER). No `I` channel files were present.

The 3CH card produced F+I+R triplets.

## Related-File Grouping

Group related files by date, time, and prefix (the `YYYYMMDD_HHMMSS_PREFIX` portion of the filename).

**2CH grouping** (confirmed from real card scan):
- Standard group: F + R at the same timestamp
- F-only clips observed in some folders when the rear camera was not active for that interval — normal behavior, not a data error

**3CH grouping** (confirmed from real card scan):
- Standard group: F + I + R at the same timestamp
- A small number of F-only clips observed in INF near the end of the sampled card

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

- Whether `EVENT` uses prefix `EVT` or a different token when visible MP4 files exist.
- Whether parking time-lapse uses the same folder and prefix as motion clips.
- Whether manual or event clips are also marked read-only by the filesystem.
- Meaning of the final `N` filename flag.
- Whether 1CH cards omit the `R` channel entirely or still produce the folder structure.
