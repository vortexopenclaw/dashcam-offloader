# Update Distribution

Dashcam Offloader uses GitHub Releases as the private maintainer record and Cloudflare as the public app update channel.

The Mac app should check a public manifest, not the private GitHub repository. Private GitHub release assets require repository access or a token, and no GitHub token should ever be embedded in the app.

## Public Endpoints

Default public endpoints:

- `https://updates.vortexradar.com/dashcam-offloader/latest.json`
- `https://updates.vortexradar.com/dashcam-offloader/download/latest`

Worker fallback before a custom route is attached:

- `https://dashcam-offloader-updates.vortexradar.workers.dev/dashcam-offloader/latest.json`
- `https://dashcam-offloader-updates.vortexradar.workers.dev/dashcam-offloader/download/latest`

## Cloudflare Resources

- Worker: `dashcam-offloader-updates`
- R2 bucket: `dashcam-offloader-updates`
- R2 manifest key: `dashcam-offloader/latest.json`
- R2 release assets: `dashcam-offloader/releases/<zip-name>`

## Dedicated Token

Use a Dashcam Offloader-specific Cloudflare API token. The token should be scoped to the Cloudflare account that owns `vortexradar.com`, and to the `vortexradar.com` zone if custom-domain automation is enabled.

Minimum account permissions:

- Workers Scripts: Edit
- Workers R2 Storage: Edit
- Account Settings: Read

Optional zone permissions:

- Zone: Read
- Workers Routes: Edit, if routing `updates.vortexradar.com` through the Worker
- DNS: Edit, only if automation should create or change `updates.vortexradar.com`

No User permissions are needed.

## GitHub Actions Secrets

Required for Cloudflare publishing:

- `CLOUDFLARE_DASHCAM_OFFLOADER_API_TOKEN`
- `CLOUDFLARE_DASHCAM_OFFLOADER_ACCOUNT_ID`

Optional:

- `DASHCAM_OFFLOADER_UPDATE_BASE_URL`, defaults to `https://dashcam-offloader-updates.vortexradar.workers.dev`

The workflow maps these dedicated secrets to Wrangler's standard `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` environment variables.

## Manifest

`latest.json` is public and intentionally contains no secrets:

```json
{
  "version": "0.1.0",
  "build": "abcdef1",
  "releaseName": "Dashcam Offloader 0.1.0 (abcdef1)",
  "releaseNotesURL": "https://github.com/vortexopenclaw/dashcam-offloader/releases/tag/latest",
  "assetName": "Dashcam-Offloader-abcdef1.zip",
  "assetKey": "dashcam-offloader/releases/Dashcam-Offloader-abcdef1.zip",
  "downloadURL": "https://updates.vortexradar.com/dashcam-offloader/download/latest",
  "sha256": "...",
  "minimumMacOSVersion": "14.0",
  "publishedAt": "2026-06-08T20:00:00Z",
  "channel": "latest"
}
```
