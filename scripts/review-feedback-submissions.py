#!/usr/bin/env python3
"""Review private Dashcam Offloader feedback submissions from Cloudflare KV."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = Path(os.path.expanduser("~/.openclaw/workspace"))
sys.path.insert(0, str(WORKSPACE / "scripts"))

from openclaw_env import load_openclaw_env  # noqa: E402


DEFAULT_NAMESPACE_ID = "39129dc4017b48c6bd8b8f4848b25c76"
TOKEN_ENV_NAMES = (
    "CLOUDFLARE_DASHCAM_OFFLOADER_TOKEN",
    "CLOUDFLARE_WORKERS_API_TOKEN",
)
REDACTED_KEYS = {"contact", "email", "name", "phone"}


def cloudflare_credentials() -> tuple[str, str]:
    load_openclaw_env()
    account_id = os.environ.get("CLOUDFLARE_ACCOUNT_ID", "").strip()
    token = ""
    for name in TOKEN_ENV_NAMES:
        token = os.environ.get(name, "").strip()
        if token:
            break
    if not account_id:
        raise SystemExit("Missing CLOUDFLARE_ACCOUNT_ID")
    if not token:
        raise SystemExit(
            "Missing Cloudflare API token. Checked: " + ", ".join(TOKEN_ENV_NAMES)
        )
    return account_id, token


def api_request(path: str) -> Any:
    account_id, token = cloudflare_credentials()
    url = f"https://api.cloudflare.com/client/v4/accounts/{account_id}{path}"
    request = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")[:500]
        raise SystemExit(f"Cloudflare API failed: HTTP {error.code}: {detail}") from error
    if path.endswith("/value") or "/values/" in path:
        return json.loads(body)
    data = json.loads(body)
    if not data.get("success"):
        raise SystemExit(f"Cloudflare API returned errors: {data.get('errors')}")
    return data.get("result")


def kv_path(namespace_id: str, suffix: str) -> str:
    return f"/storage/kv/namespaces/{namespace_id}{suffix}"


def list_keys(namespace_id: str, prefix: str, limit: int) -> list[dict[str, Any]]:
    limit = max(limit, 10)
    query = urllib.parse.urlencode({"prefix": prefix, "limit": str(limit)})
    result = api_request(kv_path(namespace_id, f"/keys?{query}"))
    return list(result or [])


def get_value(namespace_id: str, key: str) -> dict[str, Any]:
    encoded_key = urllib.parse.quote(key, safe="")
    return dict(api_request(kv_path(namespace_id, f"/values/{encoded_key}")) or {})


def redact(value: Any) -> Any:
    if isinstance(value, dict):
        redacted: dict[str, Any] = {}
        for key, child in value.items():
            if key.lower() in REDACTED_KEYS:
                redacted[key] = "[redacted]"
            else:
                redacted[key] = redact(child)
        return redacted
    if isinstance(value, list):
        return [redact(child) for child in value]
    return value


def submission_text(record: dict[str, Any]) -> str:
    return json.dumps(record, ensure_ascii=False, sort_keys=True)


def summary_for(record: dict[str, Any], key: str) -> dict[str, Any]:
    payload = record.get("payload") if isinstance(record.get("payload"), dict) else record
    learning = payload.get("cardLearning") or payload.get("learning") or payload.get("training") or {}
    scan = payload.get("scan") or payload.get("scanSummary") or {}
    if not scan and isinstance(learning.get("scanSummary"), dict):
        scan = learning["scanSummary"]
    identified = scan.get("identifiedCamera") or {}
    return {
        "key": key,
        "receivedAt": record.get("receivedAt"),
        "type": payload.get("type") or payload.get("kind"),
        "appVersion": payload.get("appVersion"),
        "manufacturer": learning.get("manufacturer"),
        "model": learning.get("model"),
        "message": payload.get("message"),
        "identifiedCamera": identified.get("displayName") or identified.get("model"),
        "scanResult": scan.get("detectedProfileName") or scan.get("selectedProfileName"),
        "confidence": scan.get("confidence"),
        "videoSpecSamples": len(scan.get("videoSpecSamples") or []),
        "videoSpecSummaries": len(scan.get("videoSpecSummaries") or []),
        "directorySummaries": len(scan.get("directorySummaries") or []),
        "folderSummaries": len(scan.get("folderSummaries") or []),
        "settingSnapshots": len(scan.get("settingSnapshots") or []),
    }


def command_list(args: argparse.Namespace) -> int:
    prefix = args.prefix or f"feedback/{args.date}/"
    keys = list_keys(args.namespace_id, prefix, args.limit)
    for item in keys:
        print(item.get("name", ""))
    return 0


def command_search(args: argparse.Namespace) -> int:
    prefix = args.prefix or f"feedback/{args.date}/"
    terms = [term.lower() for term in args.query]
    matches: list[dict[str, Any]] = []
    for item in list_keys(args.namespace_id, prefix, args.limit):
        key = item.get("name", "")
        if not key:
            continue
        record = get_value(args.namespace_id, key)
        haystack = submission_text(record).lower()
        if all(term in haystack for term in terms):
            matches.append(summary_for(record, key))
    print(json.dumps(matches, indent=2, sort_keys=True))
    return 0


def command_get(args: argparse.Namespace) -> int:
    key = args.key
    if not key.startswith("feedback/"):
        key = f"feedback/{args.date}/{key}"
        if not key.endswith(".json"):
            key += ".json"
    record = get_value(args.namespace_id, key)
    print(json.dumps(redact(record), indent=2, sort_keys=True))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--namespace-id", default=DEFAULT_NAMESPACE_ID)
    parser.add_argument("--date", default="2026-06-09")
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list")
    list_parser.add_argument("--prefix")
    list_parser.add_argument("--limit", type=int, default=100)
    list_parser.set_defaults(func=command_list)

    search_parser = subparsers.add_parser("search")
    search_parser.add_argument("query", nargs="+")
    search_parser.add_argument("--prefix")
    search_parser.add_argument("--limit", type=int, default=100)
    search_parser.set_defaults(func=command_search)

    get_parser = subparsers.add_parser("get")
    get_parser.add_argument("key")
    get_parser.set_defaults(func=command_get)

    args = parser.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
