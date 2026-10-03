# Dashcam Offloader 0.1.24

- Overlap verification of a completed clip with copying the next clip, reducing idle time during large offloads without removing SHA-256 or size verification.
- Keep at most one completed clip awaiting verification. Preserve successfully verified files if a later clip is cancelled, and remove partial or failed files.

Speed depends on the card, destination, and clip sizes. No speed increase is guaranteed on every setup.
