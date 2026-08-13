#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

python3 "$ROOT_DIR/scripts/build-camera-reference.py" --output "$TEMP_DIR/cameras.json"
if ! cmp -s "$ROOT_DIR/reference/cameras.json" "$TEMP_DIR/cameras.json"; then
  echo "Camera reference is stale. Run python3 scripts/build-camera-reference.py and commit reference/cameras.json." >&2
  exit 1
fi

echo "Camera reference is current."
