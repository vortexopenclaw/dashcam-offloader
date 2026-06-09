# VIOFO A229 Pro - Research Notes

## Sources

- Official manual: <https://viofotech.com/download/manual/A229P/A229ProEnglishManual.pdf> (V26.01.09, Copyright 2025 VIOFO Ltd.)
- VIOFO firmware blog (V1.3 release notes): <https://www.viofo.com/blogs/viofo-car-dash-camera-guide-faq-and-news/firmware-updates-viofo-a229-pro-a229-plus-version-v13>
- VIOFO firmware update guide: <https://www.viofo.com/blogs/viofo-car-dash-camera-guide-faq-and-news/viofo-firmware-update-guide-step-by-step>
- Third-party settings guide (confirms parking channel suffixes): <https://www.blackboxmycar.com/pages/best-settings-for-viofo-a229-series-dash-cam>

## Video File Storage Location (from official manual, p.30)

The manual provides this table:

| Recording Mode | Folder |
|---|---|
| Loop Recording (including Time-lapse Recording) | `DCIM\Movie` |
| Emergency Recording (Locked Video) | `DCIM\Movie\RO` |
| Parking Recording (Auto Event Detection / Time-lapse Recording / Low Bitrate Recording) | `DCIM\Movie\Parking` |
| Snapshot | `DCIM\Photo` |

## File Format Definition (from official manual, p.30)

The manual shows these example filenames:

```
2024_0827_112625_00001PF.MP4
2024_0827_112625_00002PI.MP4
2024_0827_112625_00003PR.MP4
2024_0827_112625_00004PT.MP4
```

Fields: `Year _ Date _ Time _ SequenceNumber + Channel`

Channel tokens documented in the manual:

- `F` - front camera
- `I` - interior camera
- `R` - rear camera
- `T` - telephoto camera (optional accessory)
- Parking prefix `P` combined with channel: `PF`, `PI`, `PR`, `PT`

The manual example shows 5-digit sequence numbers (`00001`-`00004`). Real-card samples show
6-digit numbers (`000511`-`006759`), confirming the counter grows beyond 5 digits. The counter is
monotonically global across all channels and recording modes on the card.

## Firmware File

The manual's firmware section (p.46) defers to the VIOFO website for upgrade instructions and
does not describe any firmware file permanently stored on the card.

The VIOFO firmware update guide confirms: place `FWA229P.bin` (and any rear-camera `.bin`) at the
**root of the card** (not in any subfolder) before the upgrade. VIOFO recommends reformatting the
card after a successful update, which removes the firmware files.

No firmware `.bin` is expected to be permanently present on a normally operating A229 Pro card.
This is a key difference from the VIOFO A329S, which permanently stores `DCIM/FWA329S.bin`.

## Recording Modes

- **Loop Recording** - continuous driving recording, configurable loop length.
- **Emergency Recording** - locked by G-sensor or manual button press; stored in `DCIM/Movie/RO`.
- **Parking Auto Event Detection** - records approximately 1 minute per motion or impact event.
- **Parking Time-Lapse** - continuous at reduced frame rate (1/2/3/5/10/15 fps), no audio.
- **Parking Low Bitrate** - continuous at approximately 4 Mb/s, audio recorded.
- **Snapshot** - still images stored in `DCIM/Photo`.

## Camera Variants

The A229 Pro supports up to four channels:

- Front (main unit): up to 4K
- Rear: 2K or optional 1080P accessory
- Interior: optional
- Telephoto: optional

Typical sold configurations are 2CH (front + rear) or 3CH (front + rear + interior). A telephoto
camera adds a `T` channel suffix. Only F, I, and R were observed on the real-card samples.

## Real-Card Measurements

Temporary 3CH card scanned read-only at `/Volumes/Untitled` on 2026-06-08:

- Card layout: `DCIM/Movie`, `DCIM/Movie/Parking`, `DCIM/Movie/RO`, `DCIM/Photo`, `DCIM/.diskdb`, and root `format.txt`.
- Media count: 6225 MP4 files and 3 JPG files.
- Normal loop recordings: 210 complete F/I/R triplets in `DCIM/Movie`.
- Parking recordings: 1866 complete PF/PI/PR triplets in `DCIM/Movie/Parking`.
  Ariel confirmed these are auto event detection clips triggered by motion/impact,
  not time-lapse or low-bitrate samples.
- Locked recordings: 1 complete F/I/R triplet in `DCIM/Movie/RO`.
- Photos: 1 complete F/I/R triplet in `DCIM/Photo`.
- Sequence range: `000511` through `006759`.

Measured video streams from representative files:

- F driving: H.264, 3840x2160, 30 fps, about 36.0 Mbps stream bitrate.
- I driving: H.264, 1920x1080, 30 fps, about 15.6 Mbps stream bitrate.
- R driving: H.264, 2560x1440, 30 fps, about 24.0 Mbps stream bitrate.
- PF parking auto event: H.264, 3840x2160, 30 fps, about 4.1 Mbps stream bitrate.
- PI parking auto event: H.264, 1920x1080, 30 fps, about 3.9 Mbps stream bitrate.
- PR parking auto event: H.264, 2560x1440, 30 fps, about 4.1 Mbps stream bitrate.

The PF/PI/PR ~4 Mbps measurements are low-bitrate parking-mode evidence, not normal
driving bitrate. Use the F/I/R driving rows above as the normal footage reference.

Additional direct-camera NAS examples from the A229 Pro folder measured:

- F driving: H.264, 3840x2160, 30 fps, about 36.0 Mbps stream bitrate.
- I driving: H.264, 1920x1080, 30 fps, about 15.6 Mbps stream bitrate.
- R driving: H.264, 2560x1440, 30 fps, about 23.8 Mbps stream bitrate.
- PF parking motion/auto event: H.264, 2560x1440, 30 fps, about 12.3 Mbps stream bitrate.
- PI parking motion/auto event: H.264, 1920x1080, 30 fps, about 6.6 Mbps stream bitrate.
- PR parking motion/auto event: H.264, 2560x1440, 30 fps, about 14.8 Mbps stream bitrate.

The temporary card was likely configured for High/Max bitrate rather than the standard/default
bitrate. Separate parking time-lapse and parking low-bitrate samples are still needed to measure
their frame rate, audio, and bitrate behavior.

## Settings / Config Access

The temporary card at `/Volumes/Untitled` was no longer mounted during the 2026-06-08 follow-up.
The NAS A229 Pro archive did not contain copied settings/config files (`*.ini`, `*.cfg`,
`*setting*`, `*config*`, or logs). Need another mounted card pass to confirm whether A229 Pro
stores readable current settings on-card.
