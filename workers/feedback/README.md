# Dashcam Offloader Feedback Worker

Cloudflare Worker endpoint for Mac app feedback submissions.

Endpoint:

```text
POST /feedback
Content-Type: application/json
```

Payloads include:

- Feedback type: `bug`, `feature`, `training`, or `other`
- User message
- Optional contact
- App version
- Optional card learning fields for `training`
- Optional sanitized scan summary

The scan summary intentionally excludes video bytes, GPS traces, unique device IDs, and full settings dumps. It contains counts, profile candidates, mode/category totals, extensions, media-extension totals, unrecognized-extension totals, timestamp-source totals, suspect camera-clock counts, inferred parking-pattern counts, root folders, folder samples, folder summaries, filename samples, safe support-file names, ignored safe support-file names, representative video specs, a capped list of relative sample paths, and optional redacted setting summaries.

Structural evidence now preserves camera-relative directory and folder summaries, including empty directories. Recognized camera folder names retain their exact case. Other segments become consistent per-snapshot `folder-N` labels; host/source paths never leave the app. Up to 120 round-robin media samples link a bounded camera basename to its folder, mode, output category, channel, file size and OS-reported permission bits, immutable flags and read-only volume status. Camera basenames may contain recording times and are disclosed in the opt-in review. Unfamiliar media basenames are accepted unchanged after bounded structural checks (180 ASCII bytes, supported media extension, no separators, traversal, controls, coordinate-like values or credential/GPS tokens). This is private evidence, not an anonymous public export. `filesystemReadOnly` is derived from absence of POSIX write bits, not effective access or a universal DOS read-only-attribute guarantee. Unknown attributes remain null; read-only volume status is separate, and no flags imply an emergency event on their own. Neither scanning nor submission writes source files or changes permissions.

Setting summaries are limited to useful camera options such as resolution, bitrate, recording quality, codec, FPS, HDR/WDR, loop length, parking mode, motion/impact settings, audio, GPS on/off, timezone, exposure, and channel settings. The app and Worker both filter out passwords, SSIDs, Wi-Fi/cloud/account fields, tokens, serials, device IDs, MAC/Bluetooth IDs, coordinates, license plates, and raw full config files.

Security notes:

- Keep the endpoint write-only. Do not expose an unauthenticated listing route.
- Prefer R2 for durable records; KV is acceptable for simple testing.
- Set `ALLOWED_ORIGINS` if browser clients are added later. The Mac app is not browser-CORS constrained.
- Keep payloads small. The Worker rejects bodies over 1 MB.
- Rate limiting allows 20 feedback or learning submissions per client per hour. Client addresses are salted and hashed before rate-limit counters are stored in KV.
- Set a `RATE_LIMIT_SALT` secret (`wrangler secret put RATE_LIMIT_SALT`) so stored rate-limit fingerprints cannot be reversed by brute-forcing the address space. Without the secret the Worker still runs but falls back to unsalted hashing.
- Treat stored submissions as private user data and avoid public buckets.
- Do not put Cloudflare credentials or bucket names in the Mac app.

Storage:

- Bind `FEEDBACK_BUCKET` to an R2 bucket for durable JSON records.
- Or bind `FEEDBACK_KV` to a KV namespace for simpler storage. The deployed Worker also uses `FEEDBACK_KV` for privacy-preserving rate-limit counters.
- If neither binding exists, the Worker logs the JSON record for local development.

Linked measurement contract:

- Each retained nested `storageRateSamples` entry may carry `sourceIdentifier`, `filename`, and `folder` beside its original numeric fields. All three must be safe to retain the link. Invalid identity fields never discard otherwise valid legacy measurements.
- Source keys are payload-local `source-N` values assigned by sorted relative (folder, basename) identity, not host paths or hashes. Identical basenames in different folders have distinct keys. HTTP validation rejects conflicting links.
- Camera-relative vocabulary includes `inside`, `200video`, and `201photo`; unknown components use consistent `folder-N` aliases. Parent summary channel/mode remains attached to each pair; owner labels and playback fps remain distinct from inferred mode and capture cadence.
- Native scans attempt metadata probing for every video on cards of at most 64 eligible videos, retaining every valid pair that fits the payload budget. Larger cards retain at most 64 measured representatives globally, prioritizing existing mode/channel/cohort/short/outlier/late coverage, then filling the budget. Media protection samples remain capped at 120 and distinct filename samples at 100. Receiver limits remain 120 summaries and 64 pairs per summary for legacy compatibility.
- Native scan JSON is reduced to at most 180,000 bytes, dropping structural previews before numeric groups. `evidenceCounts` reports inventoried media/videos, successfully measured videos, retained/omitted linked identities and retained/omitted measurements (including unmeasured videos). Receiver recomputes retained/omitted totals after its filters/caps. The request cap remains 1 MiB, checked against both declared and streamed bytes.
- Both app submission routes require a frozen, explicitly reviewed scan and matching scan revision. Original video/photo filenames can include recording dates. Completed structural-only scans are allowed, with an insufficient-measurement warning; no fake bitrate is supplied.
- Stored records and historical receipts are unchanged. Client-omitted identities cannot be recovered by a receiver update. Private derived ingest retains exact links; `scan-storage-rates.py` emits only anonymous numeric candidates and hashes the anonymous projection, not private input bytes. Offloader has no accepted-only publication/proposal pipeline or schema-shaped public card-scan exporter; those are separate maintainer/Scanner contracts. The native anonymous projection is not a claim of conformance to the public card-scan schema.

Tests:

```bash
node --test workers/feedback/worker.test.mjs
```

The Verify workflow runs the sanitizer tests on every feature-branch push.

Review:

```bash
scripts/review-feedback-submissions.py list --date 2026-06-09
scripts/review-feedback-submissions.py search Botslab --date 2026-06-09
scripts/review-feedback-submissions.py get feedback/2026-06-09/<submission-id>.json
```

The review helper loads Cloudflare credentials from the OpenClaw workspace environment and redacts contact fields.

Local run:

```bash
cd workers/feedback
cp wrangler.toml.example wrangler.toml
wrangler dev
```

Deploy:

```bash
wrangler deploy
```
