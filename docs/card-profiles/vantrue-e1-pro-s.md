# Vantrue E1 Pro S

## Model identification

A read-only inspection of owner-confirmed E1 Pro S and E1 Pro cards found the exact regular support-file basenames `GPS/E1PROS_Settings.ini` and `GPS/E1PRO_Settings.ini`, respectively. Match the complete model token before `_Settings.ini`; do not compact the entire filename and search for a substring. The `S` beginning the word Settings is not part of the model name.

Unknown model suffixes, symbolic links, and conflicting model-coded settings markers must not confirm either camera. The presence of shared folders or an ordinary filename pattern alone does not establish E1 Pro versus E1 Pro S.

## Observed card structure

The inspected card contained `Normal`, `Parking`, `Event`, `Photo`, and `GPS` directories, with 12 MP4 videos and three JPG photos. The Event directory was empty in this sample. Observed media filenames use the same date/time/sequence, recording-token, and front-channel-A grammar seen in older E1 Pro archives. Original capture filenames and source identifiers are omitted.

Folder and filename-token classifications are not proof of an impact trigger or uniform capture cadence within a file. The owner reports that Always On Video with collision detection can mix idle timelapse and ordinary recording within one file. Those transitions remain unverified by the metadata-only comparison.

## Comparison and limits

A bounded comparison of older E1 Pro driving and parking archives found shared filename grammar and container characteristics. Eight representative header probes across the two cameras' driving/parking groups returned H.264/AAC MP4 at 3840x2160. Codec, resolution, bitrate, playback FPS, and archive directory names are not model identity.

Current camera firmware is owner-reported as E1 Pro S `VT-EFI242` and E1 Pro `VT-EFH112`. This does not independently establish every existing clip's capture firmware. No firmware string was independently extracted from the initial bounded support/container-header inspection. Configuration values, GPS trails, device identifiers, and full logs are neither required for this identity correction nor included here.

Short Vantrue names are used in the picker and learning prefill: E1, E1 Pro, E1 Pro S, S1, and S1 Pro. Historical Element and Sonnet names remain compatibility aliases, not additional models.
