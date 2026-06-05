# Card Intake Checklist

Use this checklist when a new dashcam SD card is mounted.

## User-Provided Setup

- Selected model from supported/known/unsupported list, or `Other`.
- User-entered brand and model when `Other` is selected.
- Number of camera channels in use.
- Channel roles, such as front, rear, interior, telephoto, left, or right.
- Whether the card may contain GPS/audio/private location data.
- Whether the user is willing to share sample video files separately. Default is no.

## Mount

- Record volume path.
- Record volume label as weak evidence only.
- Confirm the card is treated as read-only by the workflow.

## Folder Tree

- Capture top-level folders.
- Capture hidden top-level folders.
- Capture recording folders.
- Capture system/config folders separately.
- Ignore macOS sidecars such as `.Spotlight-V100`, `.fseventsd`, and `._*`.

## File Samples

For each recording folder:

- Count video files.
- Capture 10 to 20 representative filenames.
- Capture extensions.
- Capture file size ranges.
- Capture oldest and newest file modified times.
- Note whether matching front/rear/interior files share timestamps.

Default public intake should capture filenames and structural metadata only, not video content.

## Classification

For each folder and filename pattern:

- Recording mode: continuous, driving event, parking motion, parking event, manual, SOS, screenshot, unknown.
- Camera channel: front, rear, interior, telephoto, unknown.
- Timestamp format.
- Extra suffixes or variants.
- Whether files appear protected by folder, filename, filesystem flags, or unknown.

## Model Detection

Look for:

- Explicit model strings in settings/version files.
- Model-specific executables or config references.
- Folder structure unique to the model family.
- Filename prefixes unique to the model family.

Do not use:

- User-renamable volume label as primary proof.
- Unique device IDs unless explicitly approved.

## Submission Package

The default intake package should include:

- Redacted folder tree.
- Representative filenames by folder.
- Counts by extension and folder.
- File size ranges by folder.
- Oldest/newest modified times by folder.
- Non-unique model strings when available.
- User-provided model and channel mapping.
- Scanner version and profile-schema version.

The default intake package should exclude:

- Video files.
- Unique device IDs.
- GPS traces and route data.
- Full settings dumps.
- Thumbnails.
- Hidden OS metadata and macOS sidecars.

## Manual Research

- Save manual/source-link notes under `docs/research/`.
- Extract relevant text.
- Record exact folder names and manufacturer terminology.
- Mark unsupported or unobserved modes as manual-confirmed but sample-unvalidated.
