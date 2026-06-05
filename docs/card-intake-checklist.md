# Card Intake Checklist

Use this checklist when a new dashcam SD card is mounted.

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

## Manual Research

- Save official manuals locally.
- Extract relevant text.
- Record exact folder names and manufacturer terminology.
- Mark unsupported or unobserved modes as manual-confirmed but sample-unvalidated.

