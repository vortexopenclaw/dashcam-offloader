#!/usr/bin/env bash
# Upload Dashcam Offloader debug symbols (dSYM) to Sentry so crash stacks symbolicate.
#
# Usage: scripts/upload-sentry-dsyms.sh [path/to/DashcamOffloader.dSYM]
#        DASHCAM_UPLOAD_DSYMS=1 scripts/build-macos-app.sh   (build, then upload)
#
# Auth: SENTRY_AUTH_TOKEN from the environment, otherwise the Sentry organization
# token is read from 1Password at upload time (never written to disk or the repo):
#   op://${SENTRY_OP_VAULT:-Openclaw}/${SENTRY_OP_ITEM:-Sentry}/Organization Token
# 1Password service-account auth is taken from OP_SERVICE_ACCOUNT_TOKEN, or from
# $OPENCLAW_ENV_FILE (default ~/.openclaw/.env) when that variable is unset.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DSYM_PATH="${1:-$ROOT_DIR/build/DashcamOffloader.dSYM}"
SENTRY_ORG="${SENTRY_ORG:-vortex-openclaw}"
SENTRY_PROJECT="${SENTRY_PROJECT:-dashcam-offloader}"

if [[ ! -d "$DSYM_PATH" ]]; then
  echo "dSYM not found: $DSYM_PATH (run scripts/build-macos-app.sh first)" >&2
  exit 1
fi

if ! command -v sentry-cli >/dev/null 2>&1; then
  echo "sentry-cli missing; install with: brew install getsentry/tools/sentry-cli" >&2
  exit 1
fi

if [[ -z "${SENTRY_AUTH_TOKEN:-}" ]]; then
  op_ref="op://${SENTRY_OP_VAULT:-Openclaw}/${SENTRY_OP_ITEM:-Sentry}/Organization Token"
  env_file="${OPENCLAW_ENV_FILE:-$HOME/.openclaw/.env}"
  # Load 1Password service-account auth in a subshell so nothing else from the
  # env file leaks into this script or sentry-cli.
  SENTRY_AUTH_TOKEN="$(
    if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" && -f "$env_file" ]]; then
      set -a; . "$env_file" >/dev/null 2>&1 || true; set +a
    fi
    op read "$op_ref"
  )"
fi
export SENTRY_AUTH_TOKEN

dwarfdump --uuid "$DSYM_PATH"
sentry-cli debug-files upload --org "$SENTRY_ORG" --project "$SENTRY_PROJECT" --wait "$DSYM_PATH"
