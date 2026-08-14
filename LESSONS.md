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

## 2026-08-13 Privacy Promises Need Outgoing-Payload Tests

- A UI statement that filenames and folder paths are excluded is not proof. Test the complete client payload and the server-side stored record with deliberately private-looking paths, filenames, timestamps, evidence, and diagnostics.
- Treat server-side sanitization as the final privacy boundary because old or modified clients can submit fields that a current client no longer creates.

## 2026-08-13 Packaged Desktop Security Is A Separate Release Gate

- Passing source tests does not prove a distributable Electron app is safe. Verify the packaged runtime version, production dependencies inside `app.asar`, strict bundle signature, updater-disabled metadata, and a clean-location launch.
- Renderer IPC must use main-process-owned folder capabilities and copy-plan tokens. Never accept renderer-supplied absolute file paths or copy plans.
- Do not enable in-app installation for unsigned desktop artifacts. Sign each platform's artifacts and verify the complete update chain first.
- Repository privacy checks must cover current trees, commit metadata, public
  release assets, issues, and comments. Third-party framework strings must be
  compared with the official upstream artifact before classifying them as
  personal data.

## 2026-08-14 Security Documentation Is Not Enforcement

- The native updater documented a security gate that assumed an unavailable
  Apple Developer ID. Verify that the proposed trust model matches the actual
  release credentials before implementing it. For this project, the
  Ed25519-signed manifest authenticates publisher origin, while strict ad-hoc
  signature verification and exact bundle/version/build checks validate the
  extracted package.
- Audit the enforcement call site and add must-reject fixtures, not just a
  helper, configuration field, error case, or design statement.
- Treat mutable manifest display fields as hostile even when the manifest has
  a valid signature. Any field used as a filesystem path must be independently
  constrained, and extracted update entries must remain inside the staging
  root after symbolic links are resolved.
- When backward compatibility prevents expanding an existing signature payload,
  derive mutable display/path fields from signed values or constrain them to
  exact allowlists. Do not show or open an unsigned URL merely because other
  fields in the same manifest are authenticated.
- A signed manifest prevents forgery, not replay. Update eligibility must use a
  signed monotonic version and reject both older and same-version manifests.
- Verify a newly generated release manifest with the public key embedded in the
  packaged app before the first public write. A valid signature from the wrong
  private key otherwise creates a release that every installed client rejects.
- Signature validity alone does not prove that a manifest describes the package
  being released. The packaged app must also compare its identifier, version,
  and commit with the generated manifest before publication.
- Treat the live update manifest as the release activation pointer. Upload it
  only after the unique archive, Worker, and human-facing release are ready.
