#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Dashcam Offloader"
PRODUCT_NAME="DashcamOffloader"
CONFIGURATION="${1:-release}"
OUTPUT_DIR="${2:-$ROOT_DIR/build-latest}"
REMOTE_REF="${3:-origin/main}"
WORKTREE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dashcam-offloader-latest.XXXXXX")"

cleanup() {
  git -C "$ROOT_DIR" worktree remove --force "$WORKTREE_DIR" >/dev/null 2>&1 || true
  rm -rf "$WORKTREE_DIR"
}

trap cleanup EXIT

cd "$ROOT_DIR"
git fetch origin main
git worktree add --detach "$WORKTREE_DIR" "$REMOTE_REF" >/dev/null
"$WORKTREE_DIR/scripts/build-macos-app.sh" "$CONFIGURATION"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp -R "$WORKTREE_DIR/build/$APP_NAME.app" "$OUTPUT_DIR/"

echo "$OUTPUT_DIR/$APP_NAME.app"
