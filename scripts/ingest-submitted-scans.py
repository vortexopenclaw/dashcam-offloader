#!/usr/bin/env python3
"""Pull opt-in sanitized feedback scans into private, derived local records.

No card is read or uploaded. No feedback message, contact, path, or raw submission
is persisted. Run repeatedly: each KV submission key produces at most one record.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path.home() / ".openclaw/workspace/scripts"))
from openclaw_env import load_openclaw_env  # noqa: E402

NAMESPACE = "39129dc4017b48c6bd8b8f4848b25c76"
KEY = re.compile(r"^feedback/\d{4}-\d{2}-\d{2}/([0-9a-fA-F-]{36})\.json$")
SAFE_LABEL = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 ._+/-]{0,79}$")
SAFE_MEDIA = re.compile(r"^(?:\d{4}_\d{4}_\d{6}_\d{1,9}(?:PF|PR|PI|PT|F|R|I|T)|[A-Z]{1,4}\d{6,12}[A-Z0-9]{0,3})\.(?:MP4|MOV|JPG|JPEG)$", re.I)
DEFAULT_OUTPUT = Path.home() / ".hermes/profiles/dashcam-offloader/submitted-scans"


def safe_label(value):
    return value if isinstance(value, str) and SAFE_LABEL.fullmatch(value) else None


def counts(value):
    if not isinstance(value, dict):
        return {}
    return {k: v for k, v in value.items() if safe_label(k) and isinstance(v, int) and not isinstance(v, bool) and 0 <= v <= 1_000_000}


def measurement(value):
    return value if isinstance(value, (float, int)) and not isinstance(value, bool) and 0 <= value <= 1e11 else None


def derive(key, record):
    """Allowlist-only projection. Unknown fields are discarded, not copied."""
    match = KEY.fullmatch(key)
    if not match or not isinstance(record, dict):
        return None
    payload = record.get("payload", record)
    if not isinstance(payload, dict) or not isinstance(payload.get("scan"), dict):
        return None
    scan = payload["scan"]
    training = payload.get("training") if isinstance(payload.get("training"), dict) else {}
    camera = scan.get("identifiedCamera") if isinstance(scan.get("identifiedCamera"), dict) else {}
    specs = []
    for item in (scan.get("videoSpecSummaries") or [])[:64]:
        if not isinstance(item, dict):
            continue
        specs.append({
            "mode": safe_label(item.get("mode")), "channel": safe_label(item.get("channel")),
            "fileCount": measurement(item.get("fileCount")),
            "resolutions": [v for v in (item.get("sampleResolutions") or [])[:6] if isinstance(v, str) and re.fullmatch(r"\d{2,5}x\d{2,5}", v)],
            "frameRates": [measurement(v) for v in (item.get("sampleFrameRates") or [])[:6] if measurement(v) is not None],
            "bitrateMin": measurement(item.get("sampleBitrateMin")),
            "bitrateMax": measurement(item.get("sampleBitrateMax")),
            "codecs": [v for v in (item.get("sampleCodecs") or [])[:6] if safe_label(v)],
        })
    names = [name for name in (scan.get("filenameSamples") or [])[:100] if isinstance(name, str) and SAFE_MEDIA.fullmatch(name)]
    patterns = []
    for item in (scan.get("filenamePatternSummaries") or [])[:32]:
        if not isinstance(item, dict):
            continue
        pattern = item.get("redactedPattern")
        if isinstance(pattern, str) and re.fullmatch(r"YYYY_MMDD_HHMMSS_SEQUENCE_(?:PF|PR|PI|PT|F|R|I|T)\.(?:MP4|MOV|JPG|JPEG)", pattern):
            patterns.append({"redactedPattern": pattern, "sampledCount": measurement(item.get("sampledCount"))})
    flags = []
    if not names:
        flags.append("filename evidence absent or filtered; channel suffix mapping unverified by submission")
    if counts(scan.get("channelCounts")).get("unknown", 0):
        flags.append("unknown channel includes photos; do not assign it to telephoto without filename evidence")
    if any("parking" in (s["mode"] or "") for s in specs):
        flags.append("parking subtype is app-inferred; bitrate does not confirm camera setting")
    if not safe_label(training.get("model")):
        flags.append("model not owner-confirmed in training fields")
    return {
        "schemaVersion": 1, "source": "submitted sanitized feedback KV", "submissionKey": key,
        "receivedAt": record.get("receivedAt") if isinstance(record.get("receivedAt"), str) and re.fullmatch(r"\d{4}-\d\d-\d\dT[0-9:.]+Z", record["receivedAt"]) else None,
        "ownerTraining": {"manufacturer": safe_label(training.get("manufacturer")), "model": safe_label(training.get("model")), "channelSetup": safe_label(training.get("channelSetup"))},
        "appIdentification": {"manufacturer": safe_label(camera.get("manufacturer")), "model": safe_label(camera.get("model")), "selectedProfileID": safe_label(scan.get("selectedProfileID"))},
        "counts": {k: counts(scan.get(k)) for k in ("channelCounts", "mediaExtensionCounts", "displayModeCounts", "modeCounts")},
        "scannedFiles": measurement(scan.get("scannedFiles")), "videoSpecSummaries": specs,
        "filenameSamples": names, "filenamePatternSummaries": patterns, "reviewFlags": flags,
    }


def credentials():
    load_openclaw_env()
    account = os.environ.get("CLOUDFLARE_ACCOUNT_ID", "")
    token = next((os.environ.get(k) for k in ("CLOUDFLARE_WORKERS_API_TOKEN", "CLOUDFLARE_DASHCAM_OFFLOADER_TOKEN") if os.environ.get(k)), None)
    if not account or not token:
        raise RuntimeError("Cloudflare account/token unavailable")
    return account, token


def request(account, token, suffix):
    url = f"https://api.cloudflare.com/client/v4/accounts/{account}/storage/kv/namespaces/{NAMESPACE}{suffix}"
    with urllib.request.urlopen(urllib.request.Request(url, headers={"Authorization": f"Bearer {token}", "Accept": "application/json"}), timeout=45) as response:
        data = json.load(response)
    if "/values/" in suffix:
        return data
    if not data.get("success"):
        raise RuntimeError("Cloudflare KV request failed")
    return data


def run(output, fetch):
    output.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(output, 0o700)
    cursor = ""
    seen = set()
    created = 0
    while True:
        query = urllib.parse.urlencode({"prefix": "feedback/", "limit": 1000, **({"cursor": cursor} if cursor else {})})
        page = fetch(f"/keys?{query}")
        for entry in page.get("result") or []:
            key = entry.get("name", "")
            match = KEY.fullmatch(key)
            if not match:
                continue
            destination = output / f"{key[9:19]}-{match.group(1).lower()}.json"
            if destination.exists():
                continue
            record = derive(key, fetch("/values/" + urllib.parse.quote(key, safe="")))
            if record is None:
                continue
            # Write completely before linking to the final key; overlapping runs
            # cannot leave a partial record or overwrite an existing one.
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=output, prefix=".ingest-", delete=False) as stream:
                temporary = Path(stream.name)
                os.chmod(temporary, 0o600)
                try:
                    json.dump(record, stream, indent=2, sort_keys=True)
                    stream.write("\n")
                except BaseException:
                    temporary.unlink(missing_ok=True)
                    raise
            try:
                os.link(temporary, destination)
                created += 1
            except FileExistsError:
                pass
            finally:
                temporary.unlink(missing_ok=True)
        next_cursor = (page.get("result_info") or {}).get("cursor")
        if not next_cursor:
            break
        if next_cursor in seen:
            raise RuntimeError("Cloudflare KV pagination cursor repeated")
        seen.add(next_cursor)
        cursor = next_cursor
    return created


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    account, token = credentials()
    print(f"Created {run(args.output, lambda suffix: request(account, token, suffix))} derived scan records")


if __name__ == "__main__":
    main()
