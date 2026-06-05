# Profile Schema

Profiles are stored as YAML files in `profiles/`.

This schema is intentionally small while the project is still in research mode.

## Required Fields

```yaml
id: thinkware-u3000-pro
manufacturer: Thinkware
model: U3000 Pro
status: seed
channel_variants:
  - channels: 2
    roles:
      - front
      - rear
    validation: real_card_sampled
sampled_variant:
  channels: 2
  roles:
    - front
    - rear
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

## Model Names and Channel Variants

Use the base product model for the public profile name and YAML `model` field. Do not create separate public profiles just because a camera is sold in 1CH, 2CH, or 3CH configurations.

Put channel-count differences in `channel_variants` and record the actually inspected setup in `sampled_variant`. A variant should only be marked `real_card_sampled` after a real card for that channel count has been inspected.

Useful `validation` values:

- `real_card_sampled` - verified from a real card.
- `official_reference` - confirmed by official manufacturer docs or product pages, but not yet card-sampled.
- `manual_confirmed` - confirmed by an official manual, but not necessarily observed on a card.
- `user_provided_example` - based on a user-provided representative filename or screenshot.
- `inferred_from_related_profile` - copied from a related profile as a hypothesis and still needs card validation.

## Detection Evidence

Detection evidence should be separated by strength:

- `high_confidence` - explicit model strings or model-specific files.
- `supporting` - folder/filename structures, manuals, volume label.
- `negative` - signals that should reject this profile.

## Privacy

Profiles must not include serial numbers, unique device IDs, license plates, GPS trails, or private video filenames that reveal personal locations.
