# Mac Prototype Build Brief

## Purpose

Build a local Mac prototype that offloads dashcam footage from mounted microSD cards into a user-selected destination. The prototype should prove the main workflow before the public app is polished: detect the dashcam profile, show available clip types and channels, let the user filter what to copy, then copy selected files with visible progress.

This brief is planning scope only. Do not start implementation until the project owner explicitly approves the build and selects the model/think level for the coding pass.

## Target Platform

- macOS on Apple Silicon, tested for an M4 Mac.
- Native Mac behavior is preferred for file access, folder picking, progress display, and removable-volume handling.
- Recommended prototype stack: SwiftUI plus Foundation file APIs.
- Keep the profile data in repo-owned YAML files so detection and classification stay data-driven.
- Distribution is internal/free for now. Do not assume a paid Apple Developer ID, Developer ID certificate, notarization, TestFlight, or App Store release path during prototype work.

## Prototype Goals

- Show mounted dashcam cards, especially removable volumes under `/Volumes/`.
- Let the user manually choose a source folder if automatic volume discovery misses a card.
- Detect the camera model from existing seeded profiles after the user selects a source.
- Do not expose internal detection candidate scoring in the main transfer UI.
- Let the user override the detected model from a brand-grouped catalog/profile list.
- Let the user choose an output directory.
- Let the user choose recording types to copy.
- Let the user choose channels to copy.
- Let the user choose date filters.
- Show planned file counts and total size before copying.
- Copy selected files without modifying the source card.
- Show progress from 0 to 100 percent during copy.
- Report completion, skipped duplicates, failures, and destination path.

## Non-Goals For First Prototype

- No delete, move, format, cleanup, or card modification.
- No automatic firmware downloads.
- No upload or cloud submission flow.
- No public intake package submission.
- No video OCR by default.
- No private GPS, OSD, or unique-device data stored in public repo docs.
- No Windows or Linux UI.
- No fully polished packaging, notarization, TestFlight, or App Store distribution.

## Safety And Privacy Rules

- Treat source cards as read-only.
- Never delete, move, rename, or modify files under `/Volumes/`.
- Do not read or store unique device identifiers such as `device.uid`.
- Exclude OS/system files, sidecars, settings dumps, thumbnails, private metadata, and firmware packages from copy plans unless a later explicit option says otherwise.
- Do not publish private filenames, GPS coordinates, recording dates, recording timestamps, location strings, or private archive counts in public docs.
- Public examples must use dummy filenames and dummy/null GPS data.
- Firmware filenames are bonus evidence only when they already exist on the card.
- The Mac app must not download firmware files.
- Public firmware downloads, ZIP inspection, and firmware filename research are maintainer-only knowledge gathering outside the app.
- OCR is an explicit learning/review workflow only, not part of the default fast copy path.

## Expected First Screen

The first screen should be the actual transfer tool, not a landing page.

Recommended layout:

- Left column: sources/cards.
- Main panel: detected camera, filters, and copy plan.
- Bottom or right rail: destination, progress, and action buttons.

Core controls:

- Source selector: mounted cards plus manual folder picker. Selecting a source should scan it automatically.
- Camera selector: detected profile with brand submenus for profile override.
- Destination selector: native folder picker.
- Recording type checkboxes: normal, event, parking, manual, photo, GPS if profile supports it.
- Channel checkboxes: front, rear, interior, telephoto, or profile-specific labels. Default all detected channels checked.
- Date range: start date plus optional end date. Default start unset and end set to present.
- Dry run or preview button.
- Copy button.
- Progress indicator: overall percent, copied bytes, copied files, current file.

## Detection Flow

Use the existing documented model identification algorithm:

1. Fast scan the source card.
2. Match folder structure and filename patterns from `profiles/*.yaml`.
3. Check safe model metadata files where profiles define them.
4. Check root firmware filenames only as bonus/tie-breaker evidence.
5. Rank profile candidates by confidence.
6. Preselect the best match and keep the internal ranking available for diagnostics.
7. Lock selected profile for the copy plan, while letting the user override it from the profile menu.

Confidence behavior:

- High confidence: preselect the detected profile and allow override.
- Medium confidence: preselect the best family/model match and allow override.
- Low confidence: require the user to select from the grouped profile picker.
- None: require manual selection or unsupported-model path.

The prototype should not show detection candidate internals in the normal transfer screen.

Never use bitrate, resolution, file size, or channel count as model identity proof. Those can be user-configurable.

Firmware handling boundary:

- The app may read filenames that are already on the selected card.
- The app may compare those filenames against a bundled reference list.
- The app must not fetch firmware pages, download firmware files, unzip firmware archives, or show firmware-download UI.
- Firmware filename matches are weak bonus evidence unless paired with stronger card metadata.

## Classification Requirements

After a profile is selected, classify candidate files by:

- Camera model/profile.
- Recording mode.
- Channel.
- Timestamp parsed from filename when available.
- Source relative path.
- Destination relative path.
- File size.
- Copy eligibility.
- Skip reason, if excluded.

GPS handling:

- If a camera writes separate GPS sidecar files or folders, expose them as optional `GPS Logs` copy items.
- If GPS data is embedded inside the video file, copying the video preserves that GPS metadata with the clip.
- The prototype does not extract embedded GPS data or publish private GPS content.

The prototype should support current seeded profile patterns, including Viofo, Vantrue, Blackvue, Thinkware, Vueroid, 70mai, and Cansonic examples already represented in `profiles/`.

## Filtering Requirements

The copy plan should filter by:

- Recording modes, default checked for detected media modes.
- Channels, default checked for all detected media channels.
- Start date.
- Optional end date.
- Include photos, default off unless the user checks it.
- Include GPS logs, default off for privacy.

If a selected profile has only one channel, show one checked channel rather than hiding the channel filter.

## Copy Behavior

The first prototype should copy files into an organized destination folder.

Recommended destination shape:

```text
<destination>/
  <camera-model>/
    <YYYY-MM-DD>/
      <mode>/
        <channel>/
          <original-filename>
```

Copy rules:

- Preserve original source files.
- Preserve original filenames.
- Create destination directories as needed.
- Skip duplicates by default when destination file exists with matching size.
- Surface conflicts when destination file exists with different size.
- Track bytes copied and files copied.
- Show errors but keep copying unaffected files where safe.
- Write a local manifest after the job completes.

Manifest fields:

- Job start and end time.
- Source path.
- Destination path.
- Selected camera profile.
- Selected filters.
- Per-file source relative path.
- Per-file destination relative path.
- Size.
- Status: copied, skipped, failed.
- Error message when present.

Keep the manifest local to the user-selected destination. Do not commit manifests to the repo.

## Internal Packaging

For free/internal testing without a paid Apple Developer ID:

- Build an Apple Silicon arm64 `.app`.
- Ad-hoc sign the app so the bundle is internally consistent.
- Package the app as a ZIP attachment for testers.
- Expect macOS Gatekeeper to show a warning on downloaded builds because the app is not Developer ID signed or notarized.
- Provide a short tester note for right-click Open or quarantine removal when needed.

Avoid calling these public releases. Public distribution should wait for Developer ID signing and notarization, or another deliberate release channel.

## Minimum Viable Prototype

The first working pass is complete when it can:

1. Launch as a Mac app on Apple Silicon.
2. Let the user pick `/Volumes/Untitled` or another mounted card as source.
3. Detect or manually select Vantrue E1 Pro.
4. Show normal and parking clips from that card.
5. Show front channel selected by default.
6. Let the user choose a destination folder.
7. Let the user set a date range.
8. Preview selected files and total size.
9. Copy selected files.
10. Show 0 to 100 percent copy progress.
11. Finish with a clear completed status and manifest.

## Suggested Implementation Order

1. Create a small profile loader for `profiles/*.yaml`.
2. Build a source scanner that produces a file inventory without copying.
3. Build profile matching and confidence output.
4. Build clip classification for the selected profile.
5. Build filter state and copy-plan preview.
6. Build the copy executor with progress callbacks.
7. Build the SwiftUI shell around those pieces.
8. Add fixture-style tests using sanitized dummy paths and filenames.

## Open Questions Before Build

- Should the prototype be native SwiftUI only, or is a webview wrapper acceptable for faster iteration?
- Should copy verification start with file-size verification only, or include checksums from the beginning?
- Should GPS logs be available as an explicit checkbox in the prototype, or hidden until a later privacy review?
- Should the first destination folder structure be organized by camera/date/mode/channel, or mirror the source card layout?
- Should multiple-card copying be visible in the first prototype, or deferred until single-card copy works cleanly?
