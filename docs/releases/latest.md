# Dashcam Offloader 0.1.32

- Keep byte copying independent of periodic UI progress updates, so a busy interface cannot pause every copy buffer. Progress is coalesced and refreshed at a bounded rate.
- Preserve SHA256 destination verification, existing-file conflict checks, recording timestamps, and cancellation cleanup.
- Read multicam metadata for up to four clips concurrently. All five angles, including the 2×2 grid, reference the original videos without re-encoding.
- Retain per-drive separation, protected-footage alignment, missing-view gaps, and duplicate guards. Source cards remain unchanged.
- Read-only, uncached four-channel card tests measured about 85 MB/s raw reads and 72–73 MB/s copying with checksum verification. A deliberately delayed UI callback test improved from about 25 to 54 MB/s; actual throughput depends on the card, reader, destination, and host. These tests do not establish the cause of a particular 8 MB/s transfer.
