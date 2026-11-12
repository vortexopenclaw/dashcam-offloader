# DDPAI Z100 Master main-unit card

## Selection and identity boundary

Choose **DDPAI → Z100 Master (Main Unit)** only after confirming both the
camera model and that this is its main recording unit's card. This profile is
manual-only: the numbered DDPAI DCIM layout is a family hint, not an exact-model
fingerprint. Volume labels do not activate it. No safe, unique model/unit
metadata was retained in the reviewed submission, so unattended exact-model
recognition is not claimed. Do not select it for a separately recording accessory.

## Owner-confirmed semantics

- The main unit has built-in front and telephoto views. On the reviewed setup,
  telephoto recordings are stored in `DCIM/200video/inside`; `inside` does not
  mean a physical interior view on this particular model/unit.
- Main-unit `DCIM/201photo/inside` photos use the same telephoto view.
- `S_`-prefixed **front videos in `DCIM/200video/front`** are parking time lapse,
  according to the owner's selected parking setting. This rule does not apply
  to inside, rear, unrelated folders, photos, sibling models or accessory cards.
- The profile does not estimate capture cadence from playback FPS or bitrate.
- Empty rear directories do not establish an installed third camera. UI channel
  suggestions use observed eligible video roles, not directory names or the
  profile's two-channel capability. Incomplete front-only coverage remains 1CH
  observed, without implying that the built-in telephoto lens is disabled.
- `DCIM/202thumb` contains thumbnails, not additional full-size photos to import.

The reviewed private submission completed inventory and retained paired video
measurements, but removed original media names and anonymized some directory
names. Folder-to-view and prefix corrections above come from the owner's
explicit clarification, not reconstructed filenames. Raw scan, dates, receipts,
contacts and original media stay outside Git.

## Verification and release gates

`DDPAIZ100Verification` is collected by the app's `--verify` suite. It uses
synthetic one-byte files to cover the real manual selection/reclassification
path, front-only parking, photos, excluded thumbnails, generic and sibling
negatives, accessory non-selection, empty rear, incomplete coverage, learning
channel suggestions and feedback output. This is classification/UI-model
regression coverage, not physical-card, decoder or packaged-app acceptance.

Before release, run the complete guarded build and `--verify` suite, inspect
manual selection in the packaged app, verify bundled `Profiles` contains this
profile, and complete normal signing/updater checks. Keep unsafe native OCR
disabled; this implementation adds no OCR or arbitrary config-file reads.
Automatic exact-model/unit selection requires independently verified bounded
identity evidence or a separately approved confined recognition replacement.
