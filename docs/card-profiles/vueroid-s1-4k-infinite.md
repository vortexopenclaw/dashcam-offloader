# Vueroid S1 4K Infinite

## Status

Seed profile, based on official Vueroid S1 4K Infinite manual research. Real-card filename and channel validation is still pending.

## Recording Folders

Manual-confirmed:

- `INF` - driving recording.
- `EVENT` - driving impact event recording.
- `PARK` - parking motion or time-lapse recording.
- `PEVENT` - parking impact event recording.
- `USER` - manual recording.
- `BOOKMARK` - screenshot or bookmark images.
- `CONFIG` - system/config data, exclude by default.

## Variants

The S1 4K family can be configured as:

- 1CH - front only.
- 2CH - front and rear.
- 3CH - front, rear, and interior.

## Exclude By Default

- `CONFIG`
- macOS sidecars and hidden OS folders.

## Open Questions

- Filename timestamp format.
- Front, rear, and interior channel tokens.
- Whether parking time-lapse uses the same folder and prefix as motion clips.
- Whether manual or event clips are also marked read-only by the filesystem.
- Related-file grouping across 1CH, 2CH, and 3CH setups.

