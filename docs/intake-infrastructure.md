# Card Intake Infrastructure

Documentation for the server-side infrastructure that receives sanitized card intake packages submitted by the Dashcam Offloader Mac app.

## Overview

When a user encounters a camera model that is not yet in the profile library, the app guides them through a sanitized card scan and packages the results into an intake submission. The submission is sent to a Cloudflare Worker that validates, sanitizes, and stores it in an R2 bucket for maintainer review.

The maintainer (or an AI assistant with Cloudflare MCP access) can then review submissions and generate new YAML profiles, card-profile docs, and research docs.

## Components

### Cloudflare Worker — `dashcam-offloader-intake`

- **Endpoint**: `https://dashcam-offloader-intake.<account>.workers.dev`
- **Routes**:
  - `POST /submit` — accepts a new intake package. Requires `X-Intake-Token` header.
  - `GET /list` — lists recent submissions with metadata. Requires `X-Intake-Token` header.
  - `GET /submission/:id` — retrieves a single submission by UUID. Requires `X-Intake-Token` header.
- **Validation**: server-side second-pass strips payloads that match private-field patterns (passwords, SSIDs, GPS coordinates, serial numbers).
- **Rate limit**: 20 submissions per IP per hour.
- **Size limit**: 512 KB per submission.

### R2 Bucket — `dashcam-offloader-submissions`

- Stores intake packages as JSON blobs.
- Key format: `YYYY-MM-DD/<submission-uuid>.json`
- Custom metadata per object: `manufacturer`, `model`, `app_version`, `channels`.
- Private bucket — not publicly accessible. Only accessible via the Worker (with valid token) or the Cloudflare dashboard.

### Secrets

- `INTAKE_TOKEN` — set as a Cloudflare Worker Secret (encrypted, never in source code). The Mac app includes this token as a build-time constant (not in the open-source repo). Users who self-host create their own Worker with their own token.

## Submission Schema

The Mac app sends a JSON body structured as:

```json
{
  "app_version": "0.1.0",
  "submission_id": "<client-generated-uuid>",
  "user_provided": {
    "manufacturer": "Escort",
    "model": "M3"
  },
  "card_scan": {
    "volume_label": "ESCORT M3",
    "folder_tree": ["Normal/", "Event/", "Photo/", "DATA/"],
    "filename_samples": [
      "20260601_0001_CAM.MP4",
      "20260601_0001_CAM.map"
    ],
    "file_extensions": [".MP4", ".map", ".JPG"],
    "sidecar_metadata": {},
    "video_streams": [
      {
        "codec": "h264",
        "width": 1920,
        "height": 1080,
        "fps": 30,
        "bitrate_kbps": 16000,
        "container": "mp4"
      }
    ],
    "channels": "1"
  }
}
```

Recent app builds also send sanitized aggregate learning fields:

- `displayModeCounts`, `outputCategoryCounts`, and `channelCounts` for quick mode/channel review.
- `filenamePatternSummaries` for redacted filename-shape learning.
- `filenameSequenceSummaries` for preserving ordered runs such as GoPro `GXAB9555` through `GXAB9560` without sending every private filename context.
- `clipGroupSummaries` for folder/mode/channel/category size and count ranges.
- `folderSummaries` with file counts and size ranges.

For GoPro support, `filenameSequenceSummaries` are the key field for validating whether all loop chunks were captured. They should retain folder, extension, prefix, first/last sequence, count, total size, and a few representative sanitized paths.

### What the App Must Strip Before Sending

The app is responsible for sanitizing the intake package before transmission. The Worker performs a second-pass validation but the app should not send:

- GPS coordinates or location data from any file
- WiFi SSIDs or passwords (e.g., from `config.ini`)
- Bluetooth credentials or pairing data
- Product serial numbers
- Any binary file contents
- Video or photo file contents
- User-identifiable filenames (e.g., actual datestamped paths) — send anonymized pattern examples only
- Device UUIDs or system identifiers
- Temperature sensor readings

## Open Source Considerations

The Worker source code is safe to publish. The `INTAKE_TOKEN` is stored exclusively in Cloudflare's encrypted Worker Secrets and is never in the repository. Anyone who forks the project to self-host creates their own Worker, R2 bucket, and token via:

```bash
wrangler secret put INTAKE_TOKEN
```

The Mac app ships with the token as a build-time constant injected from a `.env` file that is listed in `.gitignore`.

## Reviewing Submissions

Use the Cloudflare MCP (connected to the same Cloudflare account) to list and review submissions:

```
GET /list                     # all recent submissions (metadata only)
GET /list?date=2026-06        # filter by date prefix
GET /submission/<uuid>        # full JSON for one submission
```

Or browse directly in the Cloudflare dashboard under R2 → `dashcam-offloader-submissions`.

## Deployment

The Worker and bucket were created and deployed via Cloudflare MCP. To redeploy after changes, update the Worker source in this repo and redeploy via MCP or:

```bash
wrangler deploy
```

Worker source is in `workers/dashcam-offloader-intake.js` (to be added when the Mac app intake feature is built).
