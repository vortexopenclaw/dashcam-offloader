# Lessons

## 2026-06-08 Dashcam Operations Research Before Implementation

- When dashcam behavior is uncertain, check manufacturer manuals/docs, real app-submitted card scans, mounted-card samples, NAS archive samples, and reliable references before implementing.
- Do not build functionality from guesses about folders, filename tokens, recording modes, channels, parking behavior, clock behavior, codecs, containers, or support/config files.
- If evidence is incomplete, mark the behavior as provisional in profiles/docs and keep implementation conservative.
- Prefer actual app submissions and real card evidence first; use NAS clips and manufacturer docs as supplemental evidence for media specs, channel mapping, and operational details.

## 2026-06-08 Feedback Worker Endpoint Assumption

- Do not treat a `workers.dev` HTTP response as proof that the project endpoint is activated or owned by the intended account.
- For Cloudflare Worker endpoints, verify repo config plus the actual deploy/account state before changing app production URLs.
- If the user has not activated a Worker subdomain or route, keep endpoint work separate from scanner/copy fallback work.
- Endpoint verification must use the exact Worker service URL and a real storage check. On 2026-06-08, the app-submitted DR770X Box training record proved the active feedback service is `dashcam-offloader-feedback.vortexradar.workers.dev`; the stale `dashcam-offloader-feedback.vortexopenclaw.workers.dev` hostname failed DNS.
