#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"

cd "$ROOT_DIR"
rm -rf "$DIST_DIR"
npx electron-builder --mac dir --x64 --arm64

for architecture in x64 arm64; do
  if [[ "$architecture" == "x64" ]]; then
    app_dir="$DIST_DIR/mac/Dashcam Offloader.app"
    zip_path="$DIST_DIR/Dashcam Offloader-0.2.0-mac.zip"
  else
    app_dir="$DIST_DIR/mac-arm64/Dashcam Offloader.app"
    zip_path="$DIST_DIR/Dashcam Offloader-0.2.0-arm64-mac.zip"
  fi

  codesign --force --deep --sign - "$app_dir"
  codesign --verify --deep --strict "$app_dir"
  /usr/bin/ditto -c -k --keepParent "$app_dir" "$zip_path"
  unzip -t "$zip_path" >/dev/null
done
