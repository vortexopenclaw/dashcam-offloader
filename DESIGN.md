# Design

## Product Goal

Build a Mac-first open-source tool that automates and simplifies offloading dashcam footage from one or more microSD cards into a user-selected destination. The app should understand each dashcam's folder structure and filename conventions well enough to classify clips by camera model, recording mode, channel, and date/time before planning and verifying the copy.

The main workflow is offload first: insert card or cards, choose the destination, review what will be downloaded, then run a verified transfer. The app should also make it practical to learn unsupported dashcams and expand existing profiles, but learning is secondary to helping the user get their footage. If a card is unrecognized, the app should still offer a simple generic dashcam download path first, then optionally ask the user to teach the card.

## Design Principles

- Never modify the source card.
- Let the user choose the destination for every offload job.
- Optimize the first-run UX for the simplest path: pick card, choose download folder, download footage.
- Keep advanced filters, settings/log copying, filename options, and learning flows out of the user's way until needed.
- For unsupported cameras, generic downloading must still work; learning the card is optional and should not block transfer.
- For supported cameras, learning submissions must still be available because users may have different channel layouts, parking modes, resolution settings, bitrate settings, firmware, or recording options than the original profile evidence.
- Treat app-submitted card data as the start of intake, not the whole intake. Verify new camera names, spelling, channel counts, channel layouts, recording modes, resolution options, codec/bitrate options, and parking behavior against manufacturer documentation, real samples, and reliable references before calling a profile complete.
- Treat multiple mounted dashcam cards as a normal workflow, not an edge case.
- Prefer deterministic profile rules over guessing.
- Treat official manuals as useful but incomplete.
- Treat real card samples as the highest-value evidence.
- Preserve enough metadata to audit every copy later.
- Start with a CLI/profile engine, then add a Mac GUI.
- Make new-camera intake a first-class workflow, not a private developer-only process.
- Ship the same safe offload workflow on Apple Silicon Macs, Intel Macs,
  Linux, and Windows. Platform packaging may differ, but behavior and the
  source-card safety contract must not.

## 2026-08-13 Lightweight Cross-Platform Replacement

**Decision:** Electron is retired as the release architecture. It proved the
generic cross-platform workflow, but bundling Chromium and Node makes the
114 MB compressed / approximately 277 MB installed macOS application
disproportionate to a utility whose application code is only about 2.2 MB.
The Electron prototype in `desktop/` remains historical reference until its
tested behavior is ported, but it must not produce another public release.

**Replacement:** Build the shared desktop application with Tauri 2 and a Rust
offload engine. Tauri uses the webview already supplied and patched by macOS,
Windows, or Linux rather than packaging a browser engine. The installed app
therefore contains the product's compiled Rust code and local interface assets,
not Chromium or a Node runtime. The existing HTML/CSS presentation can be
ported without giving it direct filesystem access.

All source discovery, profile detection, classification, planning, hashing,
copying, and update decisions live in Rust. The interface receives only
display-safe records and opaque capability identifiers. It cannot submit file
paths or arbitrary copy plans. Remote navigation, popups, remote scripts, and
unneeded Tauri/plugin permissions remain disabled. Updates stay disabled until
each platform artifact is OS-signed and the mandatory Tauri update signature
and complete release channel have passed verification.

The native SwiftUI app remains the macOS reference until the Tauri application
reaches feature parity. The eventual release target is one shared Tauri/Rust
implementation for macOS arm64, macOS x86_64, Windows x86_64, and Linux
x86_64, avoiding two permanent product implementations.

**Alternatives rejected:** A fully native Rust renderer such as egui removes
the webview boundary entirely, but currently trades away native appearance,
API stability, and complete cross-platform accessibility. Slint provides a
compiled native UI but does not currently list Intel macOS among its tested
desktop targets. Tauri is the strongest balance of size, migration effort,
accessibility through native web controls, signed updates, and maintenance
burden for this application.

**Acceptance gates:** Measure actual artifacts rather than relying on framework
marketing. Target a macOS ZIP below 20 MB and reject any package containing an
Electron/Chromium or Node runtime. The Rust engine must pass the existing
source-read-only, destination containment, verified-copy, duplicate, conflict,
privacy-redaction, and scan-race fixtures on all four target combinations.
Platform packages must pass dependency audit, malware/static analysis,
signature/notarization checks, clean-machine launch, and signed-update
verification before publication.

**Sources:** Tauri documents that it uses the operating system webview instead
of bundling one, exposes capability-scoped frontend/backend boundaries, and
requires cryptographic signatures for updater artifacts:
`https://v2.tauri.app/start/`, `https://v2.tauri.app/security/`, and
`https://v2.tauri.app/plugin/updater/`.

## 2026-08-13 Superseded Electron Cross-Platform Foundation

**Status:** Superseded by the Tauri/Rust decision above. This section records
the prototype contract and is not authorization to publish another Electron
artifact.

**Objective:** Replace the macOS-only product constraint with a shared desktop
application that can be packaged for Apple Silicon Macs, Intel Macs, Linux,
and Windows, without weakening the established copy-only source-card contract.

**Design:** Keep the current SwiftUI app as the verified macOS reference while
the cross-platform application is built in `desktop/`. It uses Electron's
native file-picker and desktop shell APIs, plus a small Node-based offload
engine. The renderer can request a source folder and destination folder, scan
only eligible media, present a review queue, and copy only after the user
confirms. The engine rejects a destination inside the selected source, never
writes to the source, sanitizes output names to basenames, skips an identical
existing file, and treats a size/checksum conflict as a non-destructive error.

The first cross-platform slice deliberately provides the generic safe-import
path. The existing profile detector, classifier, learning workflow, updater,
and macOS-specific eject behavior remain in the Swift reference app until they
are ported behind shared platform-neutral interfaces. This avoids claiming
profile parity before it exists.

Electron Builder produces distinct artifacts: macOS arm64, macOS x64, Linux
AppImage and Debian packages, and Windows NSIS/portable packages. CI runs the
engine's deterministic verification on macOS, Ubuntu, and Windows. A public
release is gated on profile-parity verification and signed/notarized platform
artifacts, so the current macOS distribution path remains authoritative during
the foundation phase.

Packaged desktop builds check the platform-specific update feed at launch.
When an update exists, the app asks before downloading it and asks again before
restarting to install it. Development builds do not query the update service.
The public Worker reserves Electron's platform metadata and assets below the
separate `dashcam-offloader/desktop/` object prefix. Unsigned desktop builds do
not query or install from that feed. The feed can be enabled only after signed
artifacts and the complete release chain pass verification.

**Risks and rollback:** The new desktop shell adds an npm/Electron toolchain
and has generic-only classification initially. It is isolated under `desktop/`
and does not change the Swift build, published update manifest, or existing
macOS app. Removing that directory and its workflow cleanly rolls back the
foundation without affecting current releases.

**Success checks:** The desktop verification suite must pass on the local
platform and in a three-OS CI matrix. It must prove source media discovery,
destination-within-source rejection, verified copy, identical-file skip, and
same-size-different-content conflict handling. Packaging configuration must
declare macOS arm64/x64, Linux, and Windows targets.

## 2026-08-13 Privacy And Security Audit

**Objective:** Verify that the app, public repository, update/feedback Workers,
CI, and downloadable artifacts do not expose private user data or create an
unnecessary path to arbitrary file access, code execution, or unsafe updates.

**Design:** Treat the renderer as untrusted even though it loads only bundled
HTML. The main process owns user-approved source/destination capabilities,
retains full scan/copy paths, and gives the renderer only display-safe media
metadata and opaque plan identifiers. Explicitly sandbox the renderer, deny
navigation, popup windows, and runtime permissions, and enforce a restrictive
Content Security Policy. Hash large media with streaming I/O instead of loading
whole videos into memory.

Feedback remains opt-in. Server-side sanitization is the final privacy boundary
and must discard volume names, folder paths, filenames, timestamps, raw model
evidence, diagnostics details, and other user-controlled card strings, even if
an older client submits them. Technical aggregates may retain bounded counts,
codec, resolution, frame-rate, bitrate, and duration ranges. Rate limiting must
fail closed without a strong salt.

Desktop in-app installation remains disabled until release artifacts are
platform-signed and the update channel has a verified release process. An
unsigned test build may offer a manual release check later, but must not silently
trust or install a mutable feed. Dependencies and CI actions are pinned to
reviewed versions/commits, and public history is scanned separately from the
working tree because deleting a file does not remove it from Git history.

**Risks and rollback:** Capability-scoped IPC can reject workflows that bypass
the app's folder pickers; those paths are intentionally unsupported. Stricter
feedback redaction reduces diagnostic detail but preserves the technical data
needed for profile development. Disabling unsigned in-app updates temporarily
removes convenience from beta builds while avoiding an unverifiable installer.

**Success checks:** Dependency audit has no known vulnerabilities; secret and
static-analysis scans return no confirmed findings; privacy fixtures prove that
paths, filenames, timestamps, evidence, diagnostic details, contact-like values,
and coordinates are removed; IPC tests reject unapproved and renderer-forged
paths; packaged apps contain required runtime dependencies, include the CSP and
updater-disabled metadata, and launch from a clean location. Public GitHub and
Cloudflare artifacts must match reviewed local bytes before release.

## 2026-08-13 Camera Selector And Scan Inventory Refresh

**Objective:** Keep brand/model selection responsive during scanning and after
the app resumes from idle, while incorporating every previously sampled camera
whose evidence supports either a trained profile or an explicit manual choice.

**Design:** An explicit brand choice takes precedence over the last detected
profile in the selector presentation. Each scan carries a generation and the
manual-profile revision present when it started. A stale scan cannot update a
newer source, and a scan that finishes after a manual camera choice preserves
that choice while classifying the completed file list with it. Previously
submitted but not uniquely auto-detectable Miofive S1 Ultra and Wolfbox G900
Pro scans become visible manual catalog choices. The real sampled BlackVue
DR970X LTE Plus profile is restored from the earlier profile branch using only
exact safe model metadata and excluding network/modem settings.

**Risks and rollback:** Manual selection can intentionally override automatic
detection, which is the expected user action. Stale-scan rejection changes only
results from scans that are no longer current. Removing the added profile and
sampled-choice list restores the prior catalog without changing generic import.

**Success checks:** A selector fixture proves a new brand wins over a detected
brand. A scan-resolution fixture proves a manual model selected after scan
start wins over the detected result. A real-card-shaped LTE Plus fixture must
select only the LTE Plus profile and classify F/R footage. The full verifier,
privacy gate, build, and packaged-app verification must pass.

## Architecture Sketch

The eventual implementation should split into these layers:

1. **Card scanner**
   - Reads directory names, selected text/config files, filenames, sizes, timestamps, and media metadata.
   - Excludes private identifiers and OS/system files.

2. **Profile detector**
   - Scores camera profiles against observed card evidence.
   - Uses strong signals such as model strings in settings files where available.
   - Uses folder and filename patterns as supporting evidence.

3. **Clip classifier**
   - Maps files to recording mode, channel, timestamp, and special flags.
   - Groups related channels from the same recording moment.

4. **Copy planner**
   - Applies user filters such as date range, recording mode, and channel.
   - Computes destination paths under the user-selected location.
   - Produces a reviewable transfer preview before copying.

5. **Copy executor**
   - Copies files without deleting or changing source files.
   - Verifies size and, where enabled, checksum.
   - Supports resume, duplicate detection, and per-card job progress.

6. **Mac UI**
   - Shows mounted cards, selected destination, detected profiles, selected filters, job progress, and completed transfer results.
   - Allows multiple cards and copy jobs at once.

7. **Profile intake assistant**
   - Works for new cameras and known cameras with unobserved settings.
   - Captures user-provided model name, firmware if visible, camera count, and flexible channel labels.
   - Scans card structure without uploading videos by default.
   - Builds a redacted submission bundle for review and test-fixture creation.
   - Requires follow-up research against manufacturer docs and reliable references before adding a complete public profile.

## Safety Rules

- Source cards are read-only from the app's perspective.
- Do not read, store, or publish unique device IDs unless explicitly needed and approved.
- Do not copy dashcam system/config folders by default.
- Do not upload video files, GPS traces, device identifiers, or full settings dumps as part of the default public intake flow.
- Do not rely on volume label alone for model detection.
- Always support dry run before copy.

## 2026-08-13 Thinkware Catalog Recognition

**Objective:** Identify a broader set of Thinkware cards when they provide
exact model metadata, without pretending that every identified model has a
trained folder/filename profile.

**Design:** The internal catalog stores canonical Thinkware model names,
common no-space aliases, documented channel expectations, and high-level
resolution hints. The scanner accepts exact model values from existing
Thinkware settings metadata first, then optional model-coded firmware/support
filenames at the card root or in `SETTING/`. A catalog match supplies a
known-model hint only. Unless a bundled profile independently matches, the
card remains on the generic, read-only import path.

**Risk and rollback:** A user can leave a firmware package for another model
on a card, so filename evidence is deliberately weaker than settings metadata
and cannot select a profile by itself. Removing the filename fallback retains
the catalog and existing settings-based recognition.

**Success checks:** All documented aliases resolve to the canonical catalog
model; exact settings and model-coded support filenames identify an untrained
model; an untrained Thinkware card still uses generic import rather than an
unrelated bundled profile.

## 2026-07-23 Preliminary regular-video importer

**Objective:** Let the existing Dashcam Offloader act as a safe first-stage
importer for ordinary camera footage while keeping the dashcam card workflow
intact. This is the bridge to the future media-organizer flow, not an attempt
to infer projects, label media, rename files, or build edit timelines yet.

**Design:** Add an explicit import-mode selector with `Dashcam Footage` as the
default and `Regular Video` as a separate route. Regular Video asks the user
to select a camera-media folder, scans it through the existing generic-media
fallback, and uses the existing review and verified-copy plan. The mode only
changes source language and selection behavior; it never changes a source
file. Dashcam-specific learning and ejection remain existing app controls and
will be scoped out of the regular-video route in a later UX pass.

**Risks and rollback:** Generic scanning can include a mix of ordinary clips
and photos, so the existing file-type review remains the acceptance boundary.
This first slice intentionally does not claim topic, speaker, A-roll, B-roll,
or project classification. Switching back to Dashcam Footage restores the
current card-focused flow without modifying any media.

**Success checks:** The app compiles and its verification suite passes. The UI
exposes both modes, regular-video selection opens a folder picker, and source
copy safety remains unchanged.

## 2026-08-07 NAS subfolder source selection

**Objective:** Let a user deliberately choose a dashcam-footage subfolder on a
mounted NAS share, rather than silently scanning the entire mounted share.

**Design:** Mounted-volume discovery continues to list each volume root in the
sidebar. A folder selected in the source picker is now retained exactly as the
source URL, whether it is on a local card or a network-mounted volume. An
explicit selection disables nested-card-root recovery, so a scan cannot swap
the chosen NAS subfolder for a different camera tree it finds below it. Eject
and auto-eject still resolve that selected URL to its containing volume, so
the safety behavior for physical cards is unchanged.

**Risk and rollback:** Selecting a narrower folder can intentionally omit
footage outside it. The selected path is displayed in the UI and scanning stays
read-only. Restoring the previous whole-share behavior is a one-line return to
volume-root normalization.

**Success checks:** A manually selected path such as
`/Volumes/Dashcams/Camera/2026-08-07` stays that exact path through source
creation and scanning, without switching to a nested camera root;
mounted-volume sidebar discovery and ejection resolution still use the volume
root.

## 2026-08-07 Security hardening

**Objective:** Close the update-chain, NAS-ejection, feedback privacy/abuse,
and copy-integrity risks found in the security review without weakening the
copy-only contract.

**Design:** In-app updates accept only a Developer ID-signed bundle whose Team
Identifier matches the Team ID embedded in the running app; checksum-only
validation is not trusted. Release builds must be Developer ID signed, while
ad-hoc local builds intentionally cannot install updates. Eject actions are
limited to local removable volumes, never network shares or a manually chosen
subdirectory. Feedback is size-limited while streaming, rate-limited by a
Durable Object, opt-in for ordinary feedback, and excludes user-controlled
filenames, paths, and volume names. Copying computes SHA-256 for each regular
file after copy and before skipping an existing destination file; a same-size
mismatch is left untouched and reported as a conflict.

**Risks and rollback:** Developer ID credentials must be configured in GitHub
Actions before a release can publish an update-capable build. Until then, users
can still download releases manually, and the app safely refuses in-app update
installation. Hashing adds local disk I/O proportional to copied footage.

**Success checks:** Verification proves the signed-update requirement and
installer behavior, same-size-different-content destinations fail safely,
feedback tests cover redaction and bounded reads, and NAS sources are not
ejectable.

## 2026-08-12 OttoSafe front-channel classification

**Objective:** Classify OttoSafe Cam `norm` and `emr` clips without the `_b`
suffix as Front rather than Unknown, while retaining `_b` clips as Rear.

**Design:** Allow a profile filename pattern to declare `default_channel` for
patterns that have no channel token. Explicit channel-token mappings still
win. The OttoSafe profile assigns Front only to its non-`_b` timestamp pattern.

**Risks and rollback:** The default applies only after that exact pattern
matches, so it cannot relabel arbitrary files. Removing the profile field
restores the prior Unknown behavior.

**Success checks:** A real-card-shaped OttoSafe fixture detects the OttoSafe
profile, classifies normal and emergency non-`_b` clips as Front, and keeps
`_b` clips as Rear.

## 2026-08-12 Thinkware ARC 800 profile

**Objective:** Recognize and classify a real Thinkware ARC 800 card without
mistaking its shared Thinkware folder and filename structure for a U3000-family
camera.

**Design:** Use the card's safe `.SETTING/dashcam.inf` `ARC800` model value as
the exact profile and catalog signal. Folder names and `REC`/`EVT`/`MOT`/`PAK`/
`MAN` filename tokens classify recording type and `F`/`R` maps the 2CH card to
Front/Rear. The official manual confirms the folder semantics and supported
1CH/2CH configurations; its metadata is not used to guess unseen filenames.

**Risks and rollback:** Shared Thinkware structures alone remain insufficient
for exact model selection. The profile only becomes high confidence with the
observed safe model marker, and deleting the profile restores generic import.

**Success checks:** A representative ARC 800 fixture containing the safe model
marker and observed folders selects exactly Thinkware ARC 800, preserves F/R,
and correctly classifies continuous, event, manual, and parking footage.

## 2026-08-12 Thinkware ARC family seed profiles

**Objective:** Make ARC 700 and ARC 900 available for safe manual selection
from their official manuals, while keeping automatic exact detection limited to
the card evidence that actually proves a model.

**Design:** Each seed profile maps only its manual-confirmed recording folders,
the documented `REC_YYYYMMDD_HHMMSS_F/R.MP4` continuous naming, and F/R
channels. ARC 700 uses `motion_timelapse_rec`; ARC 900 uses `motion_rec` and
adds `sos_rec`. Both models have manual-confirmed resolution options in the
catalog, but no bitrate claims. The ARC 800 catalog now records its documented
QHD60 Front option separately from the observed 4K30 submission.

**Risks and rollback:** The shared Thinkware layout is insufficient for exact
model recognition, so a scan stays generic until model-specific card metadata
or comparable evidence appears. Deleting either profile removes its manual
selection option without affecting generic importing.

**Success checks:** Fixtures load each profile and classify its documented
F/R continuous and folder-based recording behavior. Catalog checks distinguish
ARC 700, ARC 800, and ARC 900 configuration support.

## 2026-08-12 ARC 800 direct-card intake coverage

**Objective:** Ensure an initial Learn Card scan retains evidence for every
video configuration present on a card, including rare resolution or frame-rate
variants in an otherwise uniform recording folder.

**Design:** The direct ARC 800 card scan confirmed the safe `ARC800` marker,
all documented top-level recording folders, and a real QHD30 Front/FHD30 Rear
pair in addition to the previously submitted 4K30 Front/FHD30 Rear footage.
Use the card's actual `Safety_Box` casing. Before applying normal timestamp and
file-size sampling, Learn Card metadata selects one video per
folder/mode/channel/codec/resolution/frame-rate signature. Only technical
metadata is read; videos and user-controlled names remain excluded from the
submission.

**Risks and rollback:** Reading a video track for each clip adds bounded
read-only scan time, especially for a large card, but prevents a configuration
from being silently absent from the learning summary. Removing the technical
representative pass restores prior sampling behavior.

**Success checks:** A real-card-shaped ARC fixture classifies `Safety_Box` as
saved footage. The catalog records observed QHD30 alongside documented QHD60,
and the standard verifier passes.

## 2026-08-12 BlackVue Elite 10 remote-card profile

**Objective:** Convert the existing remote Elite 10 card evidence into an
exactly identified supported profile without inventing media properties the
older submission did not record.

**Design:** The 2026-06-09 submission proves exact `ELITE 10` model text in
`BlackVue/Config/version.bin`, the BlackVue Record/Config layout, and 1,290
MP4 records using normal `NF`/`NR` and impact `IF`/`IR` Front/Rear pairs.
Use only those metadata paths for high-confidence selection and map only the
observed N/I tokens. Keep codec, resolution, bitrate, duration, and parking
filename behavior unclaimed until a newer sanitized submission or real card
provides them.

**Risks and rollback:** Elite family layouts are shared, so exact config
metadata is mandatory. The profile must not inherit Elite 8/9 media claims.
Removing the profile returns Elite 10 cards to safe generic import.

**Success checks:** A real-submission-shaped fixture with `ELITE 10` metadata
selects only the Elite 10 profile, maps NF/NR to Front/Rear normal clips, and
maps IF/IR to Front/Rear impact events.

## Profile Confidence

Profiles should expose confidence levels:

- **High:** explicit model string or model-specific executable/config plus matching folder structure.
- **Medium:** strong folder and filename structure with no conflicting evidence.
- **Low:** generic structure or user-renamed volume label only.

## Initial Profiles

The first profile database entries are:

- Thinkware U3000 Pro, based on `/Volumes/U3000PRO` and Thinkware documentation.
- Vueroid S1 4K Infinite, based on official manual research and pending real-card validation.
