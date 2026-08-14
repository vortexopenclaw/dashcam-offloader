#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Dashcam Offloader"
PRODUCT_NAME="DashcamOffloader"
CONFIGURATION="${1:-release}"
SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BUILD_COMMIT="$(git -C "$ROOT_DIR" rev-parse --short HEAD)"

cd "$ROOT_DIR"

swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME"

BIN_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path)/$PRODUCT_NAME"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$PRODUCT_NAME"
cp -R "$ROOT_DIR/profiles" "$RESOURCES_DIR/Profiles"
cp "$ROOT_DIR/assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>DashcamOffloader</string>
  <key>CFBundleIdentifier</key>
  <string>com.vortexopenclaw.dashcam-offloader</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>Dashcam Offloader</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.3</string>
  <key>CFBundleVersion</key>
  <string>3</string>
  <key>DashcamOffloaderBuildCommit</key>
  <string>$BUILD_COMMIT</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

chmod +x "$MACOS_DIR/$PRODUCT_NAME"
if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --deep --options runtime --sign "$SIGNING_IDENTITY" "$APP_DIR"
else
  # The signed update manifest authenticates origin; ad-hoc signing checks bundle integrity.
  codesign --force --deep --sign - "$APP_DIR"
fi
echo "$APP_DIR"
