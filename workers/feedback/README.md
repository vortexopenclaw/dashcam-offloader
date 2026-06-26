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

Setting summaries are limited to useful camera options such as resolution, bitrate, recording quality, codec, FPS, HDR/WDR, loop length, parking mode, motion/impact settings, audio, GPS on/off, timezone, exposure, and channel settings. The app and Worker both filter out passwords, SSIDs, Wi-Fi/cloud/account fields, tokens, serials, device IDs, MAC/Bluetooth IDs, coordinates, license plates, and raw full config files.

Security notes:

- Keep the endpoint write-only. Do not expose an unauthenticated listing route.
- Prefer R2 for durable records; KV is acceptable for simple testing.
- Set `ALLOWED_ORIGINS` if browser clients are added later. The Mac app is not browser-CORS constrained.
- Keep payloads small. The Worker rejects bodies over 1 MB.
- Rate limiting allows 20 feedback or learning submissions per client per hour. Client addresses are hashed before rate-limit counters are stored in KV.
- Treat stored submissions as private user data and avoid public buckets.
- Do not put Cloudflare credentials or bucket names in the Mac app.

Storage:

- Bind `FEEDBACK_BUCKET` to an R2 bucket for durable JSON records.
- Or bind `FEEDBACK_KV` to a KV namespace for simpler storage. The deployed Worker also uses `FEEDBACK_KV` for privacy-preserving rate-limit counters.
- If neither binding exists, the Worker logs the JSON record for local development.

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
