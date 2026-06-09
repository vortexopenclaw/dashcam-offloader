# Card Intake Infrastructure

Documentation for the server-side infrastructure that receives sanitized card intake packages submitted by the Dashcam Offloader Mac app.

## Overview

When a user encounters a camera model that is not yet in the profile library, the app guides them through a sanitized card scan and packages the results into a Learn Card submission. The user can optionally run a light in-app video-spec probe before submitting so the package includes sampled codec, resolution, frame-rate, bitrate, and duration data from representative clips. The submission is sent to the feedback Cloudflare Worker, which validates, sanitizes, and stores it for maintainer review.

The maintainer can then review remote submissions and generate new YAML profiles, card-profile docs, and research docs without needing the physical card locally.

## Components

### Cloudflare Worker — `dashcam-offloader-feedback`

- **Endpoint**: `https://dashcam-offloader-feedback.vortexradar.workers.dev/feedback`
- **Routes**:
  - `POST /feedback` — accepts feedback and Learn Card submissions.
- **Validation**: server-side second-pass strips payloads that match private-field patterns such as passwords, SSIDs, GPS coordinates, serial numbers, tokens, device IDs, and raw full settings dumps.
- **Size limit**: 256 KB per submission.

### Storage — `FEEDBACK_KV` / `FEEDBACK_BUCKET`

- Stores submission packages as JSON records.
- Current key format: `feedback/YYYY-MM-DD/<submission-uuid>.json`
- Storage is private and not publicly browsable.
- The Worker must have either a `FEEDBACK_KV` namespace binding or a `FEEDBACK_BUCKET` R2 binding. If neither is bound, production submissions fail instead of being silently lost.

## Submission Schema

The Mac app sends a JSON body structured roughly as:

```json
{
  "kind": "training",
  "message": "BlackVue DR770X Box",
  "appVersion": "0.1.0",
  "training": {
    "manufacturer": "Escort",
    "model": "M3",
    "channelSetup": "1CH front"
  },
  "scan": {
    "volumeName": "ESCORT M3",
    "rootFolders": ["Normal", "Event", "Photo", "DATA"],
    "filenameSamples": [
      "20260601_0001_CAM.MP4",
      "20260601_0001_CAM.map"
    ],
    "extensionCounts": { "mp4": 12, "map": 12 },
    "samplePaths": ["Normal/20260601_0001_CAM.MP4"],
    "videoSpecSamples": [
      {
        "relativePath": "Normal/20260601_0001_CAM.MP4",
        "mode": "Driving",
        "channel": "Front",
        "codec": "H.264",
        "width": 3840,
        "height": 2160,
        "frameRate": 30,
        "bitrateMbps": 60,
        "durationSeconds": 60,
        "fileSize": 450000000
      }
    ]
  }
}
```

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

The Worker source code is safe to publish. The Mac app posts sanitized feedback directly to the public Worker endpoint; it does not contain Cloudflare credentials or storage tokens. Anyone who forks the project can self-host by creating their own Worker and binding a private KV namespace or R2 bucket.

## Reviewing Remote Submissions

Use the repository helper to list and review stored feedback records:

```bash
python3 scripts/review-feedback-submissions.py list --kind training
python3 scripts/review-feedback-submissions.py get <feedback-id-or-kv-key>
```

This helper maps `CLOUDFLARE_DASHCAM_OFFLOADER_TOKEN` to Wrangler's `CLOUDFLARE_API_TOKEN` at runtime and does not print credentials. Use `--json` only when a full sanitized payload is needed for profile work.

## Deployment

The Worker and bucket were created and deployed via Cloudflare MCP. To redeploy after changes, update the Worker source in this repo and redeploy via MCP or:

```bash
wrangler deploy
```

Worker source is in `workers/feedback/worker.js`.
