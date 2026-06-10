#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$SCRIPT_DIR/Dashcam Offloader.app"

if [[ ! -d "$APP_PATH" ]]; then
  osascript -e 'display alert "Dashcam Offloader not found" message "Put this launcher in the same folder as Dashcam Offloader.app, then run it again." as warning'
  exit 1
fi

/usr/bin/xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true
/usr/bin/open "$APP_PATH"
