# Design

## Product Goal

Build a Mac-first open-source tool that safely offloads dashcam footage from one or more memory cards into a predictable destination folder. The app should understand each dashcam's folder structure and filename conventions well enough to classify clips by camera model, recording mode, channel, and date/time.

## Design Principles

- Never modify the source card.
- Prefer deterministic profile rules over guessing.
- Treat official manuals as useful but incomplete.
- Treat real card samples as the highest-value evidence.
- Preserve enough metadata to audit every copy later.
- Start with a CLI/profile engine, then add a Mac GUI.
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
   - Computes destination paths.
   - Produces a dry-run manifest before copying.

5. **Copy executor**
   - Copies files without deleting or changing source files.
   - Verifies size and, where enabled, checksum.
   - Supports resume and duplicate detection.

6. **Mac UI**
   - Shows mounted cards, detected profiles, selected filters, job progress, and completed manifests.
   - Allows multiple cards/jobs at once.

## Safety Rules

- Source cards are read-only from the app's perspective.
- Do not read, store, or publish unique device IDs unless explicitly needed and approved.
- Do not copy dashcam system/config folders by default.
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

