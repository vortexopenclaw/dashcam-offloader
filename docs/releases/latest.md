# Dashcam Offloader 0.1.45

Security and reliability hardening from an independent review:

- A card that fails or is removed mid-copy no longer crashes the app or leaves a truncated clip under its final name.
- Copies never follow links planted on a card or in the download folder, never write onto the source card, and refuse a download folder inside the card.
- "Preserve camera settings" copies regular files only; small camera metadata files are read with size limits and without following links.
- Merged GoPro exports appear under their final name only when complete.
- Copies are flushed to disk before they are verified.
- Very large or malformed cards can no longer exhaust memory or crash the app.
- 70mai filename timestamps are now recognized.
- Feedback uploads use no cookies and refuse redirects; private evidence no longer keeps coordinate-like file names.

Existing signed in-app updates are unchanged. This macOS build is ad-hoc signed, not notarized; a first installation may require normal macOS Open Anyway approval.
