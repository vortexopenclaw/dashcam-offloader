# BlackVue Elite 10

## Status

Supported 2-channel seed profile based on a remote Learn Card submission from
an Elite 10 card. The submission contained exact model metadata, 1,290 MP4
file records, and sanitized card structure, but no media payload or sampled
codec, resolution, bitrate, or duration data.

## Model Detection

The card's `BlackVue/Config/version.bin` identified `ELITE 10`. The profile
also accepts matching model text in `micom_version.bin` or
`smart_gsensor_version.bin`; those files are only read for the model field and
are excluded from downloads.

## Observed Layout And Filenames

- `BlackVue/Record` holds footage.
- `BlackVue/Config` holds settings and model metadata and is not imported.
- Observed filenames follow `YYYYMMDD_HHMMSS_MODECHANNEL.mp4`.
- `NF`/`NR` are normal Front/Rear pairs.
- `EF`/`ER` are impact-event Front/Rear pairs.

The remote scan did not retain video technical summaries and did not prove
parking filename tokens. A future real card or newer Learn Card submission is
needed before adding codec, resolution, bitrate, or parking-specific claims.

## Evidence

- Remote Learn Card submission received 2026-06-09, identified from the card
  metadata as BlackVue Elite 10.
