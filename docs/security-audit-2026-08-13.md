# Privacy And Security Audit, 2026-08-13

## Scope

This review covers the native macOS app, cross-platform Electron beta, feedback
and update Workers, GitHub repository and history, CI workflows, dependencies,
and the downloadable Apple Silicon beta.

## Result

The current public Apple Silicon beta should not be used or redistributed. Its
Electron runtime has known high-severity advisories, its outer app bundle does
not pass strict signature verification, and its updater runtime dependency was
not packaged correctly. Automatic updates are disabled in the hardened local
code until signed artifacts and the full update chain pass verification.

No API keys, private keys, access tokens, private network addresses, personal
home-directory paths, or private source files were found in the current remote
source archives or packaged application archive. Secret scanning and push
protection are enabled on GitHub, with no open secret-scanning alerts at the
time of review.

One personal-looking commit-author email address remains in public Git history.
Removing it requires rewriting public history and force-pushing changed commit
identifiers, so that remediation requires explicit owner approval. Future
commits should use a repository-scoped GitHub no-reply address.

## Findings And Local Remediation

- **Critical release trust gap:** The unsigned beta failed strict signature
  verification and could not establish a trustworthy automatic update path.
  Automatic desktop updates are now disabled locally.
- **High dependency risk:** The beta used an Electron version with known
  high-severity advisories. Dependencies are updated and pinned locally, and CI
  now fails on high-severity npm audit findings.
- **High file-access risk:** The renderer could submit arbitrary source paths,
  destination paths, and copy plans over IPC. Main-process-owned opaque folder
  capabilities and single-use copy-plan tokens now constrain file access to
  folders selected through the native picker, and every IPC call validates the
  exact bundled renderer URL.
- **High privacy mismatch:** Feedback sanitization retained user-controlled
  evidence, diagnostic details, paths, filenames, and media timestamps despite
  the privacy promise. Both client and server now remove these fields, with
  regression fixtures proving that deliberately private values do not survive.
- **Medium renderer hardening:** The Electron window lacked explicit sandbox,
  navigation, popup, permission, and Content Security Policy controls. These
  controls are now explicit locally.
- **Medium availability risk:** File hashing loaded complete videos into memory
  and scanning used unbounded recursion. Hashing now streams data and scanning
  is iterative with an entry limit.
- **Medium supply-chain risk:** CI Actions and Wrangler used mutable version
  tags. Actions are pinned to reviewed commit SHAs and Wrangler to an exact
  version locally.
- **Repository hardening gaps:** GitHub code scanning, branch protection,
  Dependabot security updates, automated security fixes, and required SHA
  pinning are not enabled. Changing these public repository settings requires
  owner approval.
- **Regression prevention:** CI now rejects personal home paths, private IPs,
  private network hostnames, private keys, Bitcoin addresses, unapproved email
  addresses, and commits that do not use a GitHub no-reply author address.

## Release Gate

A replacement desktop release must not be published until all of these pass:

1. Dependency audit and static analysis report no unresolved high-severity
   findings.
2. Privacy fixtures prove private paths, filenames, timestamps, evidence, and
   diagnostic strings are removed on both client and server.
3. IPC tests reject forged folder and copy-plan capabilities.
4. Packaged artifacts contain all runtime dependencies and pass strict
   signature checks.
5. Each public artifact matches the reviewed local checksum.
6. Automatic installation remains disabled until production code signing and
   update-chain verification are complete for that platform.
