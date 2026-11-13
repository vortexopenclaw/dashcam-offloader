# DDPAI Z100 Master main-unit card

## Selection and identity boundary

The Offloader can automatically select **DDPAI → Z100 Master (Main Unit)**
when its existing in-process OSD probe reads the exact **DDPAI Z100 Master**
stamp from a video directly in `DCIM/200video/front`. Recognition runs even
when the shared-folder candidate score is low or no competing profile exists.
It does not depend on configured or observed channel counts.

Shared numbered DDPAI folders and model-looking volume labels are not exact
identity evidence. The profile retains `manual_only` status to exclude it from
ordinary folder/filename scoring. The exact-front-stamp gate or bounded UI
device-info gate (exact logging identity plus safely opened main-front video)
can activate it. With absent, unreadable, blank or wrong stamps, the
card remains generic unless other independently supported identity evidence
exists. Z100 Pro, MasterX and other DDPAI layouts are not claimed by this gate.

Manual selection remains available after confirming both model and main-unit
card. UI presentation must distinguish this choice from automatic OSD evidence.
Never select this profile for a separately recording cabin/accessory card;
inside-only cards cannot activate the front-stamp gate, even if their video
contains model text. This changes Offloader only, not the standalone Scanner's
disabled native helper or its automatic-support claims.

## Owner-confirmed semantics

- The main unit has built-in front and telephoto views. Telephoto recordings
  are stored in `DCIM/200video/inside`; this folder is not a physical cabin view
  on this verified model/unit. Main-unit `DCIM/201photo/inside` photos use the
  same telephoto view.
- A connected rear camera can add rear recordings to the main card. A separate
  cabin camera records on its own microSD: a system configured as four channels
  does not mean four views are present on the main card. No cabin mapping is
  inferred here. Owner reports forthcoming main-card scans with and without
  that cabin unit; equal resolution/bitrate and changed power remain hypotheses
  until independently measured.
- Empty rear directories do not add observed channels. Front/telephoto files
  remain 2CH observed even for an owner-configured 4CH system with rear failure.
  Actual rear files make this 3CH observed; front-only coverage remains 1CH,
  without implying the built-in telephoto lens is disabled.
- `S_`-prefixed **front videos in `DCIM/200video/front`** and `Q_`-prefixed
  **rear videos in `DCIM/200video/rear`** are owner-confirmed parking time lapse.
  The completed 3CH card probe covered all 72 files: 13 front normal, 15 front
  `S_`, 13 telephoto normal, 13 rear normal `_A`, and 18 rear `Q_`. This adds a
  scoped rear rule, not a reinterpretation of older numeric samples. Neither
  prefix applies in inside, unrelated folders, photos, sibling models or
  accessory cards; front `Q_` and rear `S_` are not covered.
- A later owner-labeled wake/record/sleep collision test uses ordinary names.
  Its configured parking setting does not label every file as parking or prove
  the trigger of each clip. Ordinary-name clips retain their existing mode
  classification; exact per-file parking attribution/cause remains unproven.
- The profile does not estimate capture cadence from playback FPS or bitrate.
- `DCIM/202thumb` contains thumbnails, not additional full-size photos to import.

Owner corrections establish the physical mappings and setting scopes, not
reconstructed names from anonymous older submissions. Raw scans, dates,
receipts, contacts, original media and private reference frames stay outside Git.

## Verification

`DDPAIZ100Verification` retains the synthetic manual picker/reclassification,
front S_/rear Q_ parking, wrong-folder/prefix/inside, photo/thumbnail,
generic/sibling/accessory, observed 3CH and empty-rear,
incomplete-coverage, observed-channel suggestion and feedback regressions.

`DDPAIMetadataVerification` covers two synthetic actual-structure logger lines
with SGR colors around the logger level. Only prefix SGR framing is ignored;
JSON arrays, nested salvage, duplicate keys, non-SGR escapes and literal JSON
controls remain rejected. File-opening and resource limits are unchanged.
The corresponding JSON fixture uses synthetic dates, paths and secret canaries.
Observed device-info reports `DDPAI DZ2602_GLOBAL_Z100 Master` / `8.0.0.23`,
with both `rear` and `inside` reporting `DDPAI DR4004` / `v9.0.0.17`. These
are protocol-component observations, not proof of two physical units, telephoto
identity, or Mini3X identity. Historical firmware/numeric evidence is preserved.

`Z100StampVerification` runs inside ordinary source and packaged `--verify`.
It generates its own seven-second font-marker videos with AVFoundation and
exercises normal `scanWithOSD` → exact identity → physical mapping → feedback.
Positives cover one, two and three actually observed main-card views; negatives
cover blank, Pro, MasterX, spaced Master X, brand-only, wrong-folder and
inside-only/accessory videos. Original profile bytes and fixture bytes/mtime
are checked unchanged. Configured 4CH never inflates observed main-card counts.

Optionally set `DASHCAM_Z100_MASTER_VIDEO_FIXTURE` to a private seven-second
video derived from the authorized owner front frame. This runs the same normal
path at 1/2/3 observed views, with reference-byte/mtime preservation. It is local
reference-frame decoder/OCR acceptance, not a rescan of original owner media,
hardware verification or a measurement of bitrate/resolution/power settings.
No private fixture is bundled, committed or sent to remote OCR.
