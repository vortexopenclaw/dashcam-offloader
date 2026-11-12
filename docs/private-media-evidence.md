# Private card-scan identity regression

This contract covers voluntarily reviewed private Offloader submissions, not a public camera profile or media upload. Never use owner clips, mounted cards or production intake for this regression.

Run from an external-scratch worktree on the configured Mac:

```sh
/usr/bin/python3 "${DASHCAM_SCRATCH_GUARD:?Set to the configured profile scratch guard}" --reserve-gib 8 --run /usr/bin/python3 scripts/test-private-evidence-roundtrip.py
```

The gate serializes with other heavy jobs. If it reports another job, wait and retry; do not bypass it. The runner uses the host Swift defaults, with optional `DASHCAM_SWIFT_BUILD_SYSTEM` and `DASHCAM_SWIFT_SDK` overrides for a configured development toolchain, and generates tiny synthetic H.264 recordings and a photo with developer-only ffmpeg. It exercises the actual CardScanner inventory, AVFoundation metadata probe, TransferViewModel snapshot, Codable payload, Worker HTTP validator/sanitizer and mock KV storage. The receipt ID selects the exact stored KV key for readback. No requests are made to production.

Cases cover four videos plus one photo with duplicate basenames in front/inside folders; a 140-video card with bounded sampling and explicit omissions; and a positive structural scan without playable video metadata. Assertions preserve each basename, folder, source key, channel, mode and numeric pair together. Safety negatives, conflicting identities, legacy numeric-only pairs, native byte-budget truncation, request-body caps, missing/stale preview rejection and anonymous export stripping are separate checks. The private ingest projection and anonymous numeric extractor consume the actual stored records. Source SHA-256 and mtimes are unchanged. All fixture/output files are temporary and removed after completion; no original recording names enter Git.

Additional regressions:

```sh
node --test workers/feedback/worker.test.mjs workers/feedback/private-evidence.test.mjs
python3 -m unittest discover -s scripts -p test_ingest_submitted_scans.py
python3 -m unittest discover -s scripts -p test_scan_storage_rates.py
```

Without the runner-provided native output, the standalone Node suite deliberately skips its native roundtrip case; that standalone pass is not native acceptance. Run the guarded app `--verify` suite separately for broader scanner/UI-model/copy regressions.

These tests establish offline source integration, not deployment, packaged UI interaction, live-card classification, a public schema-shaped export, or an accepted-only publication proposal. Old stripped identities cannot be reconstructed from anonymous numbers; leave existing receipts immutable.
