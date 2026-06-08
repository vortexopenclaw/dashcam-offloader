# Vueroid S1 4K Infinite

## Status

Seed profile, based on official Vueroid S1 4K Infinite manual research and real card scans of both a 3CH and a 2CH variant. The 2CH card also contains 1CH driving clips (rear camera unplugged for part of the session), confirming all three channel configurations from real footage. Both parking modes (motion detection and time-lapse) confirmed from real card data.

Use `Vueroid S1 4K Infinite` as the public app model name. Treat 1CH, 2CH, and 3CH as channel variants behind the same profile.

## Recording Folders

Both sampled cards (2CH and 3CH) had identical folder structure:

- `INF` — continuous driving recording. Prefix `INF`.
- `PARK` — parking recording (motion detection or time-lapse). Prefix `PRK`. Both parking modes share this folder and prefix — distinguished by video frame rate only.
- `PEVENT` — parking impact event recording. Prefix `PVT`. Saved regardless of which PARK mode is active.
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
| 1CH | F only | Real card sampled |
| 2CH | F + R | Real card sampled |
| 3CH | F + I + R | Real card sampled |

All three variants confirmed from real card data. The 2CH card contains both 2CH clips (F+R pairs) and 1CH clips (F-only) from periods when the rear camera was unplugged. 1CH and 2CH clips coexist on the same card with no change to folder structure or filename format.

## Parking Mode Detection

Both parking modes use the `PARK/` folder and `PRK_` prefix. They are **indistinguishable by filename alone**. The reliable signal is the video track frame rate, confirmed from real card samples of both modes:

| Mode | Frame rate | Audio | Clip duration |
|---|---|---|---|
| Motion detection | 30 fps | ✅ AAC | 30 s |
| Time-lapse | 5 fps | ❌ none | up to 20 s |

File size is **not** a reliable signal — the camera pre-allocates fixed-size containers (197 MB) for both modes.

The app should probe one PARK clip per card using `AVURLAsset.tracks(withMediaType: .video).first?.nominalFrameRate`:
- `≈ 30` → `parking_motion`
- `≈ 5` → `parking_timelapse`

Impact events during parking (PEVENT/PVT) are saved separately regardless of which PARK mode is active.

## Related-File Grouping

Group related files by date, time, and prefix (the `YYYYMMDD_HHMMSS_PREFIX` portion of the filename).

**1CH** — F-only groups. Normal behavior when rear camera is not installed.

**2CH** — F+R pairs at the same timestamp across all recording modes (INF, PARK, PEVENT, USER). A single card may contain a mix of 1CH and 2CH groups from different recording sessions.

**3CH** — F+I+R triplets across all recording modes. A small number of F-only groups observed in INF near the end of the sampled card.

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
- Whether manual or event clips are also marked read-only by the filesystem.
- Meaning of the final `N` filename flag.
