#!/bin/bash
set -euo pipefail

APP_NAME="SuperZen"
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "❌ Error: Provide a version (e.g. 1.1.0)"
  exit 1
fi
DMG_NAME="${APP_NAME}-${VERSION}"
BUILD_DIR="build"
STAGING_DIR="${BUILD_DIR}/dmg-staging"
ASSETS_DIR="scripts/dmg_assets"
DMG_BACKGROUND="${ASSETS_DIR}/background.png"
BACKGROUND_GENERATOR="scripts/generate_dmg_background.swift"

echo "🚀 Packaging SuperZen v${VERSION}..."

# 1. Archive the App
xcodebuild -project "SuperZen.xcodeproj" \
    -scheme "SuperZen" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}/DerivedData" \
    -archivePath "${BUILD_DIR}/${APP_NAME}.xcarchive" \
    MARKETING_VERSION="${VERSION}" \
    archive \
    CODE_SIGN_IDENTITY="-" \
    AD_HOC_CODE_SIGNING_ALLOWED=YES

# 2. Extract App from Archive
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "${BUILD_DIR}/${APP_NAME}.xcarchive/Products/Applications/${APP_NAME}.app" "$STAGING_DIR/"

# 3. Create DMG
rm -f "${BUILD_DIR}/${DMG_NAME}.dmg"
mkdir -p "$ASSETS_DIR"
swift "$BACKGROUND_GENERATOR" "$DMG_BACKGROUND"

APP_ICON_PATH="${STAGING_DIR}/${APP_NAME}.app/Contents/Resources/AppIcon.icns"

CREATE_DMG_ARGS=(
  --volname "${APP_NAME}"
  --filesystem APFS
  --no-internet-enable
  --hdiutil-retries 10
  --background "${DMG_BACKGROUND}"
  --window-pos 200 120
  --window-size 760 420
  --text-size 14
  --icon-size 128
  --icon "${APP_NAME}.app" 190 225
  --hide-extension "${APP_NAME}.app"
  --app-drop-link 570 225
)

if [ -f "$APP_ICON_PATH" ]; then
  CREATE_DMG_ARGS+=(--volicon "$APP_ICON_PATH")
fi

# Check if 'create-dmg' is installed and working, otherwise fallback to basic hdiutil
if command -v create-dmg &> /dev/null && create-dmg \
  "${CREATE_DMG_ARGS[@]}" \
  "${BUILD_DIR}/${DMG_NAME}.dmg" \
  "$STAGING_DIR"; then
    echo "✅ DMG Created with create-dmg: ${BUILD_DIR}/${DMG_NAME}.dmg"
else
    echo "⚠️ 'create-dmg' failed or not found. Falling back to simple hdiutil (no custom layout)..."
    rm -f "${BUILD_DIR}/${DMG_NAME}.dmg"
    hdiutil create -volname "${APP_NAME}" -srcfolder "$STAGING_DIR" -ov -format UDZO \
      "${BUILD_DIR}/${DMG_NAME}.dmg"
    echo "✅ DMG Created with hdiutil fallback: ${BUILD_DIR}/${DMG_NAME}.dmg"
fi
