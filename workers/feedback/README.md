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

The scan summary intentionally excludes video bytes, GPS traces, unique device IDs, and full settings dumps. It contains counts, profile candidates, mode/category totals, extensions, root folders, folder samples, filename samples, support-file names, a capped list of relative sample paths, and optional redacted setting summaries.

Setting summaries are limited to useful camera options such as resolution, bitrate, recording quality, codec, FPS, HDR/WDR, loop length, parking mode, motion/impact settings, audio, GPS on/off, timezone, exposure, and channel settings. The app and Worker both filter out passwords, SSIDs, Wi-Fi/cloud/account fields, tokens, serials, device IDs, MAC/Bluetooth IDs, coordinates, license plates, and raw full config files.

Security notes:

- Keep the endpoint write-only. Do not expose an unauthenticated listing route.
- Prefer R2 for durable records; KV is acceptable for simple testing.
- Set `ALLOWED_ORIGINS` if browser clients are added later. The Mac app is not browser-CORS constrained.
- Keep payloads small. The Worker rejects bodies over 256 KB.
- Treat stored submissions as private user data and avoid public buckets.
- Do not put Cloudflare credentials or bucket names in the Mac app.

Storage:

- Bind `FEEDBACK_BUCKET` to an R2 bucket for durable JSON records.
- Or bind `FEEDBACK_KV` to a KV namespace for simpler storage.
- If neither binding exists, the Worker logs the JSON record for local development.

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
