#!/usr/bin/env python3
"""Review stored Dashcam Offloader feedback submissions from Cloudflare KV."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
WORKSPACE_ROOT = REPO_ROOT.parents[1]
ENV_HELPER = WORKSPACE_ROOT / "scripts"
FEEDBACK_CONFIG = REPO_ROOT / "workers" / "feedback" / "wrangler.toml"
DEFAULT_NAMESPACE_ID = "39129dc4017b48c6bd8b8f4848b25c76"


def load_env() -> dict[str, str]:
    sys.path.insert(0, str(ENV_HELPER))
    from openclaw_env import load_openclaw_env  # type: ignore

    load_openclaw_env()
    token = os.environ.get("CLOUDFLARE_DASHCAM_OFFLOADER_TOKEN", "")
    account_id = os.environ.get("CLOUDFLARE_DASHCAM_OFFLOADER_ACCOUNT_ID") or os.environ.get("CLOUDFLARE_ACCOUNT_ID", "")
    if not token:
        raise SystemExit("CLOUDFLARE_DASHCAM_OFFLOADER_TOKEN is missing")
    if not account_id:
        raise SystemExit("CLOUDFLARE_ACCOUNT_ID is missing")
    env = os.environ.copy()
    env["CLOUDFLARE_API_TOKEN"] = token
    env["CLOUDFLARE_ACCOUNT_ID"] = account_id
    return env


def wrangler(args: list[str]) -> str:
    result = subprocess.run(
        ["npx", "wrangler", *args],
        cwd=REPO_ROOT,
        env=load_env(),
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def list_keys(namespace_id: str, prefix: str, limit: int) -> list[dict[str, Any]]:
    output = wrangler(
        [
            "kv",
            "key",
            "list",
            "--namespace-id",
            namespace_id,
            "--prefix",
            prefix,
            "--remote",
            "--config",
            str(FEEDBACK_CONFIG),
        ]
    )
    keys = json.loads(output)
    if not isinstance(keys, list):
        raise SystemExit("Unexpected Wrangler key list output")
    return keys[:limit]


def get_record(namespace_id: str, key: str) -> dict[str, Any]:
    output = wrangler(
        [
            "kv",
            "key",
            "get",
            key,
            "--namespace-id",
            namespace_id,
            "--remote",
            "--text",
            "--config",
            str(FEEDBACK_CONFIG),
        ]
    )
    record = json.loads(output)
    if not isinstance(record, dict):
        raise SystemExit(f"Unexpected record payload for {key}")
    return record


def record_summary(key: str, record: dict[str, Any]) -> dict[str, Any]:
    scan = record.get("scan") if isinstance(record.get("scan"), dict) else {}
    training = record.get("training") if isinstance(record.get("training"), dict) else {}
    sample_paths = scan.get("samplePaths")
    if not isinstance(sample_paths, list):
        sample_paths = scan.get("sampleRelativePaths")
    if not isinstance(sample_paths, list):
        sample_paths = []
    return {
        "key": key,
        "id": record.get("id"),
        "receivedAt": record.get("receivedAt"),
        "kind": record.get("kind"),
        "manufacturer": training.get("manufacturer"),
        "model": training.get("model"),
        "channelSetup": training.get("channelSetup"),
        "selectedProfile": scan.get("selectedProfileName"),
        "selectedProfileID": scan.get("selectedProfileID"),
        "copyableItems": scan.get("copyableItems"),
        "rootFolders": scan.get("rootFolders", []),
        "samplePaths": sample_paths[:12],
    }


def find_key(namespace_id: str, prefix: str, key_or_id: str) -> str:
    if key_or_id.startswith("feedback/"):
        return key_or_id
    for key_info in list_keys(namespace_id, prefix, 1000):
        key = str(key_info.get("name", ""))
        if key.endswith(f"/{key_or_id}.json") or key == key_or_id:
            return key
    raise SystemExit(f"No feedback key found for {key_or_id}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--namespace-id", default=DEFAULT_NAMESPACE_ID)
    parser.add_argument("--prefix", default="feedback/")
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help="List stored submissions")
    list_parser.add_argument("--limit", type=int, default=25)
    list_parser.add_argument("--kind", choices=["bug", "feature", "training", "other"])
    list_parser.add_argument("--json", action="store_true")

    get_parser = subparsers.add_parser("get", help="Fetch one submission by KV key or id")
    get_parser.add_argument("key_or_id")
    get_parser.add_argument("--json", action="store_true", help="Print full sanitized stored JSON")

    args = parser.parse_args()

    if args.command == "list":
        summaries: list[dict[str, Any]] = []
        for key_info in list_keys(args.namespace_id, args.prefix, args.limit):
            key = str(key_info.get("name", ""))
            if not key:
                continue
            record = get_record(args.namespace_id, key)
            if args.kind and record.get("kind") != args.kind:
                continue
            summaries.append(record_summary(key, record))
        summaries.sort(key=lambda item: str(item.get("receivedAt") or ""), reverse=True)
        if args.json:
            print(json.dumps(summaries, indent=2, sort_keys=True))
            return 0
        for item in summaries:
            title = " ".join(
                part
                for part in [str(item.get("manufacturer") or ""), str(item.get("model") or "")]
                if part
            ).strip() or str(item.get("kind") or "feedback")
            print(f"{item['receivedAt']}  {item['id']}  {title}")
            print(f"  key: {item['key']}")
            print(f"  profile: {item.get('selectedProfile')} ({item.get('selectedProfileID')})")
            print(f"  copyable: {item.get('copyableItems')}  roots: {', '.join(item.get('rootFolders') or [])}")
        return 0

    key = find_key(args.namespace_id, args.prefix, args.key_or_id)
    record = get_record(args.namespace_id, key)
    if args.json:
        print(json.dumps(record, indent=2, sort_keys=True))
    else:
        print(json.dumps(record_summary(key, record), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
