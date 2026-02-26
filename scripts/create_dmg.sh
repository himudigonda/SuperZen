#!/bin/bash
set -e

APP_NAME="SuperZen"
VERSION=$1
DMG_NAME="${APP_NAME}-${VERSION}"
BUILD_DIR="build"
STAGING_DIR="${BUILD_DIR}/dmg-staging"

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

# Check if 'create-dmg' is installed and working, otherwise fallback to basic hdiutil
if command -v create-dmg &> /dev/null && create-dmg \
    --volname "${APP_NAME}" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 175 190 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 425 190 \
    "${BUILD_DIR}/${DMG_NAME}.dmg" \
    "$STAGING_DIR"; then
    echo "✅ DMG Created with create-dmg: ${BUILD_DIR}/${DMG_NAME}.dmg"
else
    echo "⚠️ 'create-dmg' failed or not found. Falling back to simple hdiutil..."
    rm -f "${BUILD_DIR}/${DMG_NAME}.dmg"
    hdiutil create -volname "${APP_NAME}" -srcfolder "$STAGING_DIR" -ov -format UDZO "${BUILD_DIR}/${DMG_NAME}.dmg"
    echo "✅ DMG Created with hdiutil fallback: ${BUILD_DIR}/${DMG_NAME}.dmg"
fi
