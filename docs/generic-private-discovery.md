# Generic private support-file discovery v1

`GenericCardDiscovery` is a separate, bounded declaration extractor. It does not
recognize retail models, select profiles, bind accessory roles, or change owner
firmware/settings. Existing DDPAI extraction and identity semantics remain separate.

- Descriptor-relative inventory includes hidden files, unfamiliar extensions,
  extensionless names, and `tmp`/`.git` files. It does not follow directory or file
  symlinks. All inventoried non-directories count as candidates; this conservative
  inventory may include media, which is not decoded by this extractor.
- Deterministic lexical candidate selection is capped at 256 attempts, 64 KiB per
  eligible regular file and 4 MiB total bytes. Before/after descriptor stat plus a
  no-follow pathname identity recheck discard changed/replaced sources. Cancellation,
  unreadable directories, and the depth-64 traversal guard make coverage limited;
  inventory counts are only the candidates actually inventoried, not a claim about
  unknown descendants of an unreadable/cancelled traversal.
- Only strict UTF-8 (optional BOM) and BOM-marked UTF-16LE/BE are decoded. Duplicate
  JSON keys, including escaped aliases, reject that JSON record before Foundation's
  last-wins conversion. JSON depth is bounded to 32. Lexical scalar traversal retains
  exact key line and nested object record indices; repeated INI keys/sections are
  observations, not dictionary overwrites.
- Supported text shapes are structured JSON, line JSON, sectioned INI/key-value,
  and bounded JSON objects in line framing. Known ANSI SGR may occur outside the
  object only; payload bytes are never cleaned. Unknown framing can be rejected.
- TAR/JPEG/ISOBMFF signatures are format hints only. No archive extraction, media
  decoding, metadata payload decoding, subprocess, network or parser download occurs
  in this extractor. XML is detected but **unsupported**, including DTD/entity input.
- The fixed technical vocabulary and field-specific value rules intentionally omit
  values they cannot safely validate. Coverage is not a claim that every format or
  every technical field was found. Model declarations are `scope: unbound`, including
  unknown models and bare version/hardware declarations (`field: build`).
- Only `support-N` aliases, bounded format/encoding/size evidence, typed declarations,
  and fixed coverage reasons are serialized. Original names/paths, arbitrary keys,
  raw lines, unknown subtrees, secrets, URLs and source hashes are not included.
- 128 sources and 128 observations are retained. Facts omitted by either cap count
  as observation omissions. Distinct model declarations are tracked **before** both
  caps, so a late conflicting model cannot disappear from the conflict flag.
- Both model assignment paths, reset, the CLI snapshot, consented private review,
  and the feedback Worker preserve optional discovery. The old private settings
  compatibility array projects validated setting observations only; it no longer
  rereads files or authorizes arbitrary printable/redaction fragments. Legacy payloads may omit discovery.
  Public snapshot export removes the entire discovery subtree. The native UI's exact
  disclosure-line producer is tested with declarations and with coverage only.

## Regressions

Run from the external worktree, under the shared scratch gate (never bypass its lock):

```sh
/usr/bin/python3 /Users/openclaw/.hermes/profiles/dashcam-offloader/projects/tools/check-scratch-budget.py --reserve-gib 8 --run /usr/bin/env DASHCAM_SWIFT_BUILD_SYSTEM=native DASHCAM_SWIFT_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk /usr/bin/python3 scripts/test-private-evidence-roundtrip.py
```

The runner builds the actual app in `.build-private`, exercises synthetic native
files and the actual scan/snapshot/review producers, then submits native JSON bytes
through the Worker's HTTP handler with an in-memory KV binding and reads the exact
receipt-key record back. No production HTTP/KV service is used. New native fixtures
are invented, stylized technical records, **not** verified formats from those brands
or proof of a physical camera. Existing sanitized DDPAI evidence tests stay separate.

If Swift's `swiftbuild` backend reports an unknown property-list parsing error, use
the established `native` backend and SDK 26.5 above; do not delete shared build output
or bypass the gate. Broader app regression/visual QA remains a separate parent check.
