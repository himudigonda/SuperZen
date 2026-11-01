#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/lib/release.sh

VERSION="$(release_project_value MARKETING_VERSION)"
BUILD_NUMBER="$(release_project_value CURRENT_PROJECT_VERSION)"
if [ -n "${1:-}" ] && [ "$1" != "$VERSION" ]; then
  release_die "asked for $1 but the project is at $VERSION. Run 'just bump $1' first"
  exit 1
fi

SIGNING="$(release_signing_mode)"
NOTARIZATION="$(release_notarization_mode)"

BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/$RELEASE_APP_NAME.xcarchive"
STAGING="$BUILD_DIR/dmg-staging"
DMG="$(release_dmg_path "$VERSION")"
BACKGROUND="scripts/dmg_assets/background.png"

release_log "packaging $RELEASE_APP_NAME $VERSION ($BUILD_NUMBER), signing: $SIGNING, notarization: $NOTARIZATION"

if [ "$SIGNING" = "developer-id" ]; then
  if ! security find-identity -v -p codesigning | grep -qF "$DEVELOPER_ID_APPLICATION"; then
    release_die "signing identity '$DEVELOPER_ID_APPLICATION' is not in the keychain"
    exit 1
  fi
  SIGN_SETTINGS=(
    CODE_SIGN_STYLE=Manual
    "CODE_SIGN_IDENTITY=$DEVELOPER_ID_APPLICATION"
    "DEVELOPMENT_TEAM=$APPLE_TEAM_ID"
    "OTHER_CODE_SIGN_FLAGS=--timestamp"
  )
else
  SIGN_SETTINGS=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY=-
    DEVELOPMENT_TEAM=
  )
fi

rm -rf "$ARCHIVE" "$STAGING" "$DMG" "$DMG.sha256"
mkdir -p "$BUILD_DIR"

release_log "archiving"
xcodebuild archive \
  -quiet \
  -project "$RELEASE_APP_NAME.xcodeproj" \
  -scheme "$RELEASE_APP_NAME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  -archivePath "$ARCHIVE" \
  ENABLE_HARDENED_RUNTIME=YES \
  "${SIGN_SETTINGS[@]}"

APP="$ARCHIVE/Products/Applications/$RELEASE_APP_NAME.app"
[ -d "$APP" ] || { release_die "archive has no app at $APP"; exit 1; }
codesign --verify --deep --strict --verbose=2 "$APP"

mkdir -p "$STAGING"
ditto "$APP" "$STAGING/$RELEASE_APP_NAME.app"

if [ ! -f "$BACKGROUND" ]; then
  release_log "generating DMG background"
  swift scripts/generate_dmg_background.swift "$BACKGROUND"
fi

release_log "creating $DMG"
CREATE_DMG_ARGS=(
  --volname "$RELEASE_APP_NAME"
  --filesystem APFS
  --no-internet-enable
  --hdiutil-retries 10
  --background "$BACKGROUND"
  --window-pos 200 120
  --window-size 760 420
  --text-size 14
  --icon-size 128
  --icon "$RELEASE_APP_NAME.app" 190 225
  --hide-extension "$RELEASE_APP_NAME.app"
  --app-drop-link 570 225
)
VOLICON="$STAGING/$RELEASE_APP_NAME.app/Contents/Resources/AppIcon.icns"
if [ -f "$VOLICON" ]; then
  CREATE_DMG_ARGS+=(--volicon "$VOLICON")
fi

if command -v create-dmg >/dev/null 2>&1 && create-dmg "${CREATE_DMG_ARGS[@]}" "$DMG" "$STAGING"; then
  release_log "created styled DMG with create-dmg"
else
  release_log "create-dmg unavailable or failed, using plain hdiutil"
  rm -f "$DMG"
  hdiutil create -volname "$RELEASE_APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
fi

if [ "$SIGNING" = "developer-id" ]; then
  release_log "signing DMG"
  codesign --sign "$DEVELOPER_ID_APPLICATION" --timestamp "$DMG"
fi

if [ "$NOTARIZATION" = "notarize" ]; then
  release_log "submitting to Apple notary service"
  SUBMISSION="$(xcrun notarytool submit "$DMG" \
    --apple-id "$NOTARY_APPLE_ID" \
    --password "$NOTARY_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait \
    --output-format json)"
  STATUS="$(plutil -extract status raw -o - - <<<"$SUBMISSION")"
  if [ "$STATUS" != "Accepted" ]; then
    SUBMISSION_ID="$(plutil -extract id raw -o - - <<<"$SUBMISSION" || true)"
    if [ -n "$SUBMISSION_ID" ]; then
      xcrun notarytool log "$SUBMISSION_ID" \
        --apple-id "$NOTARY_APPLE_ID" \
        --password "$NOTARY_PASSWORD" \
        --team-id "$APPLE_TEAM_ID" >&2 || true
    fi
    release_die "notarization finished with status '$STATUS'"
    exit 1
  fi
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
fi

release_write_checksum "$DMG"
release_verify_checksum "$DMG"
release_log "done: $DMG"
