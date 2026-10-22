# Vueroid H1 QHD Infinite

Historical seed evidence recovered from the reviewed H1 profile and research
before commit `fbb9e3b`. Private card identifiers, host paths, and original
capture filenames are deliberately omitted. The stable profile ID is
`vueroid-h1`; the official public product name is **H1 QHD Infinite**.

Official product reference: <https://vueroid.com/product/h1-qhd-infinite/>.
The shared public camera profile uses the same stable ID and display name.

## Historical identification and channels

- `CONFIG/config.bin` contained the exact marker `H1-QHD-INFINITE` and firmware
  string `H1-QHD-INFINITE V0.5.9`.
- `CONFIG/.boot.log` repeatedly reported `1CH`, supporting front-only recording.
  `1CH` is not a unique model identifier and cannot independently select H1.
- H1 filenames omit the S1 physical channel token (`F`, `I`, or `R`). The
  historical filename pattern maps the observed final `N` token to front;
  the token's independent flag meaning remains unknown.
- The exact config marker provides high-confidence model identification. Shared
  Vueroid folders alone do not distinguish H1 from S1. S1 markers disqualify
  the H1 profile, and the S1 profiles retain their H1 exclusions.

## Historical folder mapping

- `INF/`: continuous driving
- `EVENT/`: protected driving event
- `PARK/`: parking
- `PEVENT/`: parking event
- `USER/`: manual
- `BOOKMARK/`: non-video bookmark area, not imported by default
- `CONFIG/`: configuration and logs, excluded from normal video import

## Evidence limits

The historical boot log included `DRIVE TO PARK` and the card contained parking
and parking-event footage. This confirms parking recording, but neither the
readable config nor the log named the exact parking subtype. Do not infer
motion, time-lapse, impact-trigger settings, or low-power behavior from these
folders alone, and do not transfer S1 parking heuristics to H1.

The archived research reported driving and parking MP4 samples as H.264,
2560x1440, 30 fps, approximately 22 Mbps. This is a historical summary only:
no per-file numeric measurement records were retained in the archived profile.
No synthetic fixture establishes codec, resolution, frame rate, duration, or
bitrate. These observations do not guarantee current retail firmware,
advertised features, recording settings, or additional channel capabilities.

The original learning scan selected S1 4K Infinite because of shared folders and
the then-missing H1 profile. Current safe metadata recognition resolves the
exact H1 marker to the H1 QHD Infinite catalog entry instead. Verification uses
clearly labeled synthetic card fixtures, not private capture names or media.
