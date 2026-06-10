#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <zip-path> <zip-name> <repository>" >&2
  exit 64
fi

ZIP_PATH="$1"
ZIP_NAME="$2"
REPOSITORY="$3"
SHORT_SHA="$(git rev-parse --short HEAD)"
FULL_SHA="$(git rev-parse HEAD)"
NOTES="Auto-built from [$SHORT_SHA](https://github.com/$REPOSITORY/commit/$FULL_SHA) on main."

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

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "GH_TOKEN is required to publish the GitHub latest release." >&2
  exit 65
fi

test -f "$ZIP_PATH"

# Move the lightweight latest tag first, but do not delete the release. If the
# GitHub API has a transient auth/server failure, the previous release survives.
git tag -f latest "$FULL_SHA"
run_with_retries git push --force origin latest

if gh release view latest --repo "$REPOSITORY" >/dev/null 2>&1; then
  run_with_retries gh release edit latest \
    --repo "$REPOSITORY" \
    --title "Latest Build" \
    --notes "$NOTES" \
    --latest \
    --target "$FULL_SHA"
  run_with_retries gh release upload latest \
    --repo "$REPOSITORY" \
    --clobber \
    "$ZIP_PATH#$ZIP_NAME"
else
  run_with_retries gh release create latest \
    --repo "$REPOSITORY" \
    --title "Latest Build" \
    --notes "$NOTES" \
    --latest \
    --target "$FULL_SHA" \
    "$ZIP_PATH#$ZIP_NAME"
fi

while IFS= read -r asset_name; do
  if [[ "$asset_name" == Dashcam-Offloader-*.zip && "$asset_name" != "$ZIP_NAME" ]]; then
    gh release delete-asset latest "$asset_name" --repo "$REPOSITORY" --yes >/dev/null
  fi
done < <(gh release view latest --repo "$REPOSITORY" --json assets --jq '.assets[].name')
