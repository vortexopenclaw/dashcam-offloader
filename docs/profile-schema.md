# Profile Schema

Profiles are stored as YAML files in `profiles/`.

This schema is intentionally small while the project is still in research mode.

## Required Fields

```yaml
id: thinkware-u3000-pro
manufacturer: Thinkware
model: U3000 Pro
status: seed
detection:
  high_confidence:
    - path: SETTING/lang/ver.dat
      contains: "Device Name:U3000PRO"
folders:
  - path: cont_rec
    mode: continuous
    prefix: REC
filename_patterns:
  - pattern: "^REC_(\\d{8})_(\\d{6})_([A-Z]+(?:_[A-Z]+)?)\\.MP4$"
channels:
  F: front
  R: rear
exclude:
  - SETTING/**
```

## Status Values

- `seed` - based on manual research or one sample card, not ready for broad release.
- `validated` - confirmed with multiple cards or complete file-mode samples.
- `experimental` - partial support, expected to need manual override.

## Detection Evidence

Detection evidence should be separated by strength:

- `high_confidence` - explicit model strings or model-specific files.
- `supporting` - folder/filename structures, manuals, volume label.
- `negative` - signals that should reject this profile.

## Privacy

Profiles must not include serial numbers, unique device IDs, license plates, GPS trails, or private video filenames that reveal personal locations.

