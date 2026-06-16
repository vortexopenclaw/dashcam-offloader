#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <zip-path> <zip-name> <repository>" >&2
  exit 64
fi

ZIP_PATH="$1"
ZIP_NAME="$2"
REPOSITORY="$3"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
SHORT_SHA="$(git rev-parse --short HEAD)"
FULL_SHA="$(git rev-parse HEAD)"
RELEASE_NOTES_FILE="${RELEASE_NOTES_FILE:-docs/releases/latest.md}"
if [[ -f "$RELEASE_NOTES_FILE" ]]; then
  NOTES="$(cat "$RELEASE_NOTES_FILE")

Build: [$SHORT_SHA](https://github.com/$REPOSITORY/commit/$FULL_SHA) on main."
else
  NOTES="Auto-built from [$SHORT_SHA](https://github.com/$REPOSITORY/commit/$FULL_SHA) on main."
fi

run_with_retries() {
  local attempt
  for attempt in 1 2 3; do
    if "$@"; then
      return 0
    fi
    if [[ "$attempt" == "3" ]]; then
      return 1
    fi
    sleep $((attempt * 5))
  done
}

if [[ -z "${GH_TOKEN:-}" && -f "$WORKSPACE_DIR/scripts/openclaw_env_value.py" ]]; then
  GH_TOKEN="$(python3 "$WORKSPACE_DIR/scripts/openclaw_env_value.py" GITHUB_PAT 2>/dev/null || true)"
  export GH_TOKEN
fi

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "GH_TOKEN is required to publish the GitHub latest release." >&2
  exit 65
fi

test -f "$ZIP_PATH"

# Move the lightweight latest tag first, then recreate the mutable latest
# release. GitHub keeps the original published_at timestamp when a release is
# edited, and Ariel relies on the release-page age as a quick freshness signal.
git tag -f latest "$FULL_SHA"
run_with_retries git push --force origin latest

if gh release view latest --repo "$REPOSITORY" >/dev/null 2>&1; then
  run_with_retries gh release delete latest --repo "$REPOSITORY" --yes
fi

run_with_retries gh release create latest \
  --repo "$REPOSITORY" \
  --title "Latest Build" \
  --notes "$NOTES" \
  --latest \
  --target "$FULL_SHA" \
  "$ZIP_PATH#$ZIP_NAME"
