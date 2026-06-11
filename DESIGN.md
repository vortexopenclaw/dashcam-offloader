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
- Keep Windows possible later, but do not optimize for it now.

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

## Profile Confidence

Profiles should expose confidence levels:

- **High:** explicit model string or model-specific executable/config plus matching folder structure.
- **Medium:** strong folder and filename structure with no conflicting evidence.
- **Low:** generic structure or user-renamed volume label only.

## Initial Profiles

The first profile database entries are:

- Thinkware U3000 Pro, based on `/Volumes/U3000PRO` and Thinkware documentation.
- Vueroid S1 4K Infinite, based on official manual research and pending real-card validation.
